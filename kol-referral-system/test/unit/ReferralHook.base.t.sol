// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/hooks/ReferralHook.sol";
import "../../contracts/interfaces/IReferralRegistry.sol";
import "../../contracts/interfaces/ITVLLeaderboard.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

// Mock contracts for testing
contract MockPoolManager {
    function getSlot0(PoolId) external pure returns (uint160, int24, uint24, uint24) {
        return (0, 0, 0, 0);
    }
}

contract MockReferralRegistry {
    mapping(address => uint256) public userTokenIds;
    mapping(address => address) public userKOLs;
    mapping(address => string) public userCodes;
    mapping(uint256 => uint256) public tokenTVLs;
    mapping(uint256 => address) public tokenOwners;
    mapping(uint256 => ReferralInfo) public referralInfos;
    
    uint256 public nextTokenId = 1;
    
    function setUserReferral(address user, string memory referralCode) external 
        returns (uint256 tokenId, address kol) {
        userCodes[user] = referralCode;
        // Simulate finding KOL for this code
        kol = address(uint160(uint256(keccak256(abi.encode(referralCode)))));
        userKOLs[user] = kol;
        tokenId = nextTokenId++;
        userTokenIds[user] = tokenId;
        tokenOwners[tokenId] = kol;
        
        referralInfos[tokenId] = ReferralInfo({
            referralCode: referralCode,
            kol: kol,
            totalTVL: 0,
            uniqueUsers: 0,
            createdAt: block.timestamp,
            isActive: true,
            socialHandle: "",
            metadata: ""
        });
        
        return (tokenId, kol);
    }
    
    function getUserReferralInfo(address user) external view 
        returns (uint256 tokenId, address kol, string memory referralCode) {
        return (userTokenIds[user], userKOLs[user], userCodes[user]);
    }
    
    function updateTVL(uint256 tokenId, uint256 newTVL) external {
        tokenTVLs[tokenId] = newTVL;
        referralInfos[tokenId].totalTVL = newTVL;
    }
    
    function referralInfo(uint256 tokenId) external view returns (ReferralInfo memory) {
        return referralInfos[tokenId];
    }
    
    function hasRole(bytes32, address) external pure returns (bool) {
        return true;
    }
    
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32) {
        return 0x00;
    }
}

contract MockTVLLeaderboard is ITVLLeaderboard {
    mapping(address => uint256) public kolTotalTVL;
    mapping(address => uint256) public kolUniqueUsers;
    mapping(address => bool) public updateCalled;
    
    bool public shouldRevert = false;
    string public revertReason = "";
    
    function updateKOLMetrics(address kol, uint256 tvlDelta, bool isDeposit, uint256 userCount) external {
        if (shouldRevert) {
            if (bytes(revertReason).length > 0) {
                revert(revertReason);
            } else {
                revert("Mock revert");
            }
        }
        
        updateCalled[kol] = true;
        kolUniqueUsers[kol] = userCount;
        
        if (isDeposit) {
            kolTotalTVL[kol] += tvlDelta;
        } else {
            if (kolTotalTVL[kol] >= tvlDelta) {
                kolTotalTVL[kol] -= tvlDelta;
            } else {
                kolTotalTVL[kol] = 0;
            }
        }
    }
    
    function setRevertBehavior(bool _shouldRevert, string memory _reason) external {
        shouldRevert = _shouldRevert;
        revertReason = _reason;
    }
    
    function getTopKOLs(uint256, uint256) external pure returns (address[] memory, KOLMetrics[] memory) {
        return (new address[](0), new KOLMetrics[](0));
    }
    
    function getKOLRank(address, uint256) external pure returns (uint256, KOLMetrics memory) {
        return (0, KOLMetrics(0,0,0,0,0,0,0,0,0));
    }
    
    function getStickyTVL(address) external pure returns (uint256) {
        return 0;
    }
    
    function currentEpoch() external pure returns (uint256) {
        return 1;
    }
}

abstract contract ReferralHookBase is Test {
    ReferralHook public hook;
    MockPoolManager public poolManager;
    MockReferralRegistry public referralRegistry;
    MockTVLLeaderboard public tvlLeaderboard;
    
    // Test addresses
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    address public kol1 = address(0x2001);
    address public kol2 = address(0x2002);
    
    // Pool setup
    PoolKey public poolKey;
    PoolId public poolId;
    
    function setUp() public virtual {
        // Deploy mocks
        poolManager = new MockPoolManager();
        referralRegistry = new MockReferralRegistry();
        tvlLeaderboard = new MockTVLLeaderboard();
        
        // Deploy hook
        hook = new ReferralHook(
            IPoolManager(address(poolManager)),
            IReferralRegistry(address(referralRegistry)),
            ITVLLeaderboard(address(tvlLeaderboard))
        );
        
        // Setup pool with real hook address from Base Mainnet
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(0x251369069A9c93A7615338c9a7127B9693428500) // Real hook address
        });
        poolId = poolKey.toId();
    }
    
    // Helper functions
    function createBalanceDelta(int256 amount0, int256 amount1) internal pure returns (BalanceDelta) {
        // Pack two int128 values into a single int256
        return BalanceDelta.wrap((amount0 << 128) | (amount1 & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    }
    
    function setUserReferral(address user, string memory code) internal {
        vm.prank(user);
        hook.setReferral(code);
    }
    
    function simulateAddLiquidity(
        address user,
        int128 liquidityDelta,
        int256 amount0,
        int256 amount1
    ) internal returns (bytes4, BalanceDelta) {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: liquidityDelta,
            salt: 0
        });
        
        BalanceDelta delta = createBalanceDelta(amount0, amount1);
        
        vm.prank(user);
        return hook.afterAddLiquidity(user, poolKey, params, delta, BalanceDelta.wrap(0), "");
    }
    
    function simulateRemoveLiquidity(
        address user,
        int128 liquidityDelta,
        int256 amount0,
        int256 amount1
    ) internal returns (bytes4, BalanceDelta) {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: liquidityDelta,
            salt: 0
        });
        
        BalanceDelta delta = createBalanceDelta(amount0, amount1);
        
        vm.prank(user);
        return hook.afterRemoveLiquidity(user, poolKey, params, delta, BalanceDelta.wrap(0), "");
    }
    
    function expectHookExecutionDebug(string memory step, address user, address kol, uint256 tokenId, uint256 tvl) internal {
        vm.expectEmit(true, true, true, true);
        emit ReferralHook.HookExecutionDebug(step, user, kol, tokenId, tvl);
    }
    
    function expectReferralTracked(address user, address kol, PoolId poolIdExpected, uint256 tvl, bool isDeposit) internal {
        vm.expectEmit(true, true, true, true);
        emit ReferralHook.ReferralTracked(user, kol, poolIdExpected, tvl, isDeposit);
    }
    
    function expectHookError(string memory step, address user, string memory reason) internal {
        vm.expectEmit(true, true, false, true);
        emit ReferralHook.HookError(step, user, reason);
    }
} 