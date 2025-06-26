// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/interfaces/IReferralRegistry.sol";
import "../../contracts/interfaces/ITVLLeaderboard.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

// Mock del hook logic sin heredar de BaseHook
contract MockReferralHookLogic {
    using PoolIdLibrary for PoolKey;
    
    // Misma lógica que el hook real pero sin validaciones de Uniswap
    IReferralRegistry public immutable referralRegistry;
    ITVLLeaderboard public immutable tvlLeaderboard;
    
    mapping(PoolId => mapping(address => address)) public userReferrer;
    mapping(address => uint256) public kolTotalTVL;
    mapping(address => uint256) public kolUniqueUsers;
    mapping(address => mapping(address => bool)) private kolUserSeen;
    
    event ReferralTracked(address indexed user, address indexed kol, PoolId indexed poolId, uint256 tvl, bool isDeposit);
    
    constructor(IReferralRegistry _referralRegistry, ITVLLeaderboard _tvlLeaderboard) {
        referralRegistry = _referralRegistry;
        tvlLeaderboard = _tvlLeaderboard;
    }
    
    function setReferral(string memory referralCode) external {
        referralRegistry.setUserReferral(msg.sender, referralCode);
    }
    
    function simulateAfterAddLiquidity(
        address sender,
        PoolKey calldata key,
        int128 liquidityDelta,
        BalanceDelta delta
    ) external returns (bool success) {
        if (liquidityDelta <= 0) {
            return false;
        }
        
        PoolId poolId = key.toId();
        (uint256 tokenId, address kol,) = referralRegistry.getUserReferralInfo(sender);
        
        if (kol != address(0) && tokenId != 0) {
            userReferrer[poolId][sender] = kol;
            
            // Track unique user
            if (!kolUserSeen[kol][sender]) {
                kolUserSeen[kol][sender] = true;
                kolUniqueUsers[kol]++;
            }
            
            uint256 tvl = _calculateTVL(delta);
            kolTotalTVL[kol] += tvl;
            
            // Update contracts with error handling
            try referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]) {
                // Success
            } catch {
                // Handle error silently
            }
            
            try tvlLeaderboard.updateKOLMetrics(kol, tvl, true, kolUniqueUsers[kol]) {
                // Success
            } catch {
                // Handle error silently
            }
            
            emit ReferralTracked(sender, kol, poolId, tvl, true);
            return true;
        }
        
        return false;
    }
    
    function simulateAfterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        int128 liquidityDelta,
        BalanceDelta delta
    ) external returns (bool success) {
        if (liquidityDelta >= 0) return false;
        
        PoolId poolId = key.toId();
        address kol = userReferrer[poolId][sender];
        
        if (kol != address(0)) {
            (uint256 tokenId, ,) = referralRegistry.getUserReferralInfo(sender);
            
            uint256 tvl = _calculateTVL(delta);
            if (kolTotalTVL[kol] >= tvl) {
                kolTotalTVL[kol] -= tvl;
            } else {
                kolTotalTVL[kol] = 0;
            }
            
            if (tokenId != 0) {
                try referralRegistry.updateTVL(tokenId, kolTotalTVL[kol]) {} catch {}
            }
            
            try tvlLeaderboard.updateKOLMetrics(kol, tvl, false, kolUniqueUsers[kol]) {} catch {}
            
            emit ReferralTracked(sender, kol, poolId, tvl, false);
            return true;
        }
        
        return false;
    }
    
    function _calculateTVL(BalanceDelta delta) private pure returns (uint256) {
        int256 amount0 = delta.amount0();
        int256 amount1 = delta.amount1();
        
        uint256 tvl = 0;
        if (amount0 > 0) tvl += uint256(amount0);
        else if (amount0 < 0) tvl += uint256(-amount0);
        
        if (amount1 > 0) tvl += uint256(amount1);
        else if (amount1 < 0) tvl += uint256(-amount1);
        
        return tvl;
    }
    
    function getKOLStats(address kol) external view returns (uint256 totalTVL, uint256 uniqueUsers) {
        return (kolTotalTVL[kol], kolUniqueUsers[kol]);
    }
    
    function getUserReferrer(PoolId poolId, address user) external view returns (address) {
        return userReferrer[poolId][user];
    }
}

// Mocks simples para testing
contract SimpleMockRegistry {
    mapping(address => uint256) public userTokenIds;
    mapping(address => address) public userKOLs;
    mapping(address => string) public userCodes;
    mapping(uint256 => uint256) public tokenTVLs;
    mapping(uint256 => ReferralInfo) public referralInfos;
    
    uint256 public nextTokenId = 1;
    
    function setUserReferral(address user, string memory referralCode) external 
        returns (uint256 tokenId, address kol) {
        userCodes[user] = referralCode;
        kol = address(uint160(uint256(keccak256(abi.encode(referralCode)))));
        userKOLs[user] = kol;
        tokenId = nextTokenId++;
        userTokenIds[user] = tokenId;
        
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
    
    function hasRole(bytes32, address) external pure returns (bool) { return true; }
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32) { return 0x00; }
}

contract SimpleMockLeaderboard is ITVLLeaderboard {
    mapping(address => uint256) public kolTotalTVL;
    mapping(address => uint256) public kolUniqueUsers;
    mapping(address => bool) public updateCalled;
    
    bool public shouldRevert = false;
    string public revertReason = "";
    
    function updateKOLMetrics(address kol, uint256 tvlDelta, bool isDeposit, uint256 userCount) external {
        if (shouldRevert) {
            revert(revertReason);
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
    function getStickyTVL(address) external pure returns (uint256) { return 0; }
    function currentEpoch() external pure returns (uint256) { return 1; }
}

contract ReferralHookMockLogicTest is Test {
    MockReferralHookLogic public hook;
    SimpleMockRegistry public registry;
    SimpleMockLeaderboard public leaderboard;
    
    PoolKey public poolKey;
    PoolId public poolId;
    
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    
    function setUp() public {
        registry = new SimpleMockRegistry();
        leaderboard = new SimpleMockLeaderboard();
        hook = new MockReferralHookLogic(registry, leaderboard);
        
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x1111)),
            currency1: Currency.wrap(address(0x2222)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });
        poolId = poolKey.toId();
    }
    
    function createBalanceDelta(int256 amount0, int256 amount1) internal pure returns (BalanceDelta) {
        return BalanceDelta.wrap((amount0 << 128) | (amount1 & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF));
    }
    
    function test_setReferral_works() public {
        string memory referralCode = "MOCK_TEST_001";
        
        vm.prank(user1);
        hook.setReferral(referralCode);
        
        (uint256 tokenId, address kol, string memory code) = registry.getUserReferralInfo(user1);
        
        assertGt(tokenId, 0, "Token ID should be assigned");
        assertNotEq(kol, address(0), "KOL should be derived");
        assertEq(code, referralCode, "Code should match");
    }
    
    function test_afterAddLiquidity_fullFlow() public {
        // 1. Set referral
        string memory referralCode = "ADD_LIQUIDITY_TEST";
        vm.prank(user1);
        hook.setReferral(referralCode);
        
        (, address kol, ) = registry.getUserReferralInfo(user1);
        
        // 2. Simulate add liquidity
        BalanceDelta delta = createBalanceDelta(1000e18, 2000e18);
        
        expectReferralTracked(user1, kol, poolId, 3000e18, true);
        
        bool success = hook.simulateAfterAddLiquidity(user1, poolKey, 1000, delta);
        
        assertTrue(success, "Add liquidity should succeed");
        
        // 3. Verify state updates
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(kol);
        assertEq(totalTVL, 3000e18, "TVL should be updated");
        assertEq(uniqueUsers, 1, "Unique users should be 1");
        
        address referrer = hook.getUserReferrer(poolId, user1);
        assertEq(referrer, kol, "Referrer should be set");
        
        // 4. Verify registry and leaderboard were updated
        assertEq(registry.tokenTVLs(1), 3000e18, "Registry should be updated");
        assertTrue(leaderboard.updateCalled(kol), "Leaderboard should be called");
        assertEq(leaderboard.kolTotalTVL(kol), 3000e18, "Leaderboard TVL should match");
    }
    
    function test_afterRemoveLiquidity_fullFlow() public {
        // Setup: Add liquidity first
        vm.prank(user1);
        hook.setReferral("REMOVE_TEST");
        
        (, address kol, ) = registry.getUserReferralInfo(user1);
        
        BalanceDelta addDelta = createBalanceDelta(2000e18, 4000e18);
        hook.simulateAfterAddLiquidity(user1, poolKey, 2000, addDelta);
        
        // Verify initial state
        (uint256 initialTVL,) = hook.getKOLStats(kol);
        assertEq(initialTVL, 6000e18, "Initial TVL should be 6000");
        
        // Now remove liquidity
        BalanceDelta removeDelta = createBalanceDelta(-1000e18, -500e18);
        
        expectReferralTracked(user1, kol, poolId, 1500e18, false);
        
        bool success = hook.simulateAfterRemoveLiquidity(user1, poolKey, -1000, removeDelta);
        
        assertTrue(success, "Remove liquidity should succeed");
        
        // Verify TVL was reduced
        (uint256 finalTVL,) = hook.getKOLStats(kol);
        assertEq(finalTVL, 4500e18, "TVL should be reduced: 6000 - 1500");
        
        // Verify registry was updated
        assertEq(registry.tokenTVLs(1), 4500e18, "Registry should reflect reduction");
    }
    
    function test_multipleUsersToSameKOL() public {
        string memory sharedCode = "SHARED_KOL_CODE";
        
        // Both users set same referral
        vm.prank(user1);
        hook.setReferral(sharedCode);
        
        vm.prank(user2);
        hook.setReferral(sharedCode);
        
        (, address kol1, ) = registry.getUserReferralInfo(user1);
        (, address kol2, ) = registry.getUserReferralInfo(user2);
        
        assertEq(kol1, kol2, "Same KOL for same code");
        
        // Both add liquidity
        BalanceDelta delta1 = createBalanceDelta(1000e18, 2000e18);
        BalanceDelta delta2 = createBalanceDelta(500e18, 1000e18);
        
        hook.simulateAfterAddLiquidity(user1, poolKey, 1000, delta1);
        hook.simulateAfterAddLiquidity(user2, poolKey, 500, delta2);
        
        // Verify combined stats
        (uint256 totalTVL, uint256 uniqueUsers) = hook.getKOLStats(kol1);
        assertEq(totalTVL, 4500e18, "Combined TVL: 3000 + 1500");
        assertEq(uniqueUsers, 2, "Two unique users");
        
        // Verify both users have referrer set
        assertEq(hook.getUserReferrer(poolId, user1), kol1, "User1 referrer");
        assertEq(hook.getUserReferrer(poolId, user2), kol1, "User2 referrer");
    }
    
    function test_errorHandling_leaderboardFails() public {
        vm.prank(user1);
        hook.setReferral("ERROR_TEST");
        
        // Make leaderboard fail
        leaderboard.setRevertBehavior(true, "Leaderboard down");
        
        BalanceDelta delta = createBalanceDelta(1000e18, 2000e18);
        
        // Should still succeed (errors are handled silently)
        bool success = hook.simulateAfterAddLiquidity(user1, poolKey, 1000, delta);
        assertTrue(success, "Should succeed even with leaderboard error");
        
        // Hook state should still be updated
        (, address kol, ) = registry.getUserReferralInfo(user1);
        (uint256 tvl,) = hook.getKOLStats(kol);
        assertEq(tvl, 3000e18, "Hook TVL should be updated");
        
        // Registry should still be updated
        assertEq(registry.tokenTVLs(1), 3000e18, "Registry should be updated");
    }
    
    function test_edgeCases() public {
        // Test zero liquidity delta
        vm.prank(user1);
        hook.setReferral("EDGE_TEST");
        
        BalanceDelta delta = createBalanceDelta(1000e18, 2000e18);
        
        // Zero delta should fail
        bool success = hook.simulateAfterAddLiquidity(user1, poolKey, 0, delta);
        assertFalse(success, "Zero liquidity delta should fail");
        
        // Negative delta should fail for add liquidity
        success = hook.simulateAfterAddLiquidity(user1, poolKey, -500, delta);
        assertFalse(success, "Negative liquidity delta should fail for add");
        
        // Positive delta should fail for remove liquidity
        success = hook.simulateAfterRemoveLiquidity(user1, poolKey, 500, delta);
        assertFalse(success, "Positive liquidity delta should fail for remove");
    }
    
    function test_tvlCalculation() public {
        vm.prank(user1);
        hook.setReferral("TVL_CALC_TEST");
        
        (, address kol, ) = registry.getUserReferralInfo(user1);
        
        // Test different balance combinations
        BalanceDelta delta1 = createBalanceDelta(1000e18, 2000e18); // Both positive
        hook.simulateAfterAddLiquidity(user1, poolKey, 1000, delta1);
        (uint256 tvl1,) = hook.getKOLStats(kol);
        assertEq(tvl1, 3000e18, "Both positive: 1000 + 2000");
        
        BalanceDelta delta2 = createBalanceDelta(-500e18, 1000e18); // Mixed
        hook.simulateAfterAddLiquidity(user1, poolKey, 500, delta2);
        (uint256 tvl2,) = hook.getKOLStats(kol);
        assertEq(tvl2, 4500e18, "Mixed: 3000 + 500 + 1000");
        
        BalanceDelta delta3 = createBalanceDelta(-300e18, -700e18); // Both negative
        hook.simulateAfterAddLiquidity(user1, poolKey, 200, delta3);
        (uint256 tvl3,) = hook.getKOLStats(kol);
        assertEq(tvl3, 5500e18, "Both negative: 4500 + 300 + 700");
    }
    
    function test_realHookAddressReference() public view {
        // Document the real hook address
        address realHookAddress = 0x251369069A9c93A7615338c9a7127B9693428500;
        
        // This test confirms we know the real address
        assertTrue(realHookAddress != address(0), "Real hook address is valid");
        
        // Our mock has different address but same logic
        assertTrue(address(hook) != realHookAddress, "Mock has different address");
        
        console.log("Real deployed hook:", realHookAddress);
        console.log("Mock hook (for testing):", address(hook));
    }
    
    // Helper function to expect events
    function expectReferralTracked(address user, address kol, PoolId poolIdExpected, uint256 tvl, bool isDeposit) internal {
        vm.expectEmit(true, true, true, true);
        emit MockReferralHookLogic.ReferralTracked(user, kol, poolIdExpected, tvl, isDeposit);
    }
} 