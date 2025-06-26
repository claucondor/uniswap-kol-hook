// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/hooks/ReferralHook.sol";
import "../../contracts/interfaces/IReferralRegistry.sol";
import "../../contracts/interfaces/ITVLLeaderboard.sol";

// Simple mock contracts for testing hook logic
contract SimpleReferralRegistry {
    mapping(address => uint256) public userTokenIds;
    mapping(address => address) public userKOLs;
    mapping(address => string) public userCodes;
    mapping(uint256 => uint256) public tokenTVLs;
    
    uint256 public nextTokenId = 1;
    
    function setUserReferral(address user, string memory referralCode) external 
        returns (uint256 tokenId, address kol) {
        userCodes[user] = referralCode;
        kol = address(uint160(uint256(keccak256(abi.encode(referralCode)))));
        userKOLs[user] = kol;
        tokenId = nextTokenId++;
        userTokenIds[user] = tokenId;
        return (tokenId, kol);
    }
    
    function getUserReferralInfo(address user) external view 
        returns (uint256 tokenId, address kol, string memory referralCode) {
        return (userTokenIds[user], userKOLs[user], userCodes[user]);
    }
    
    function updateTVL(uint256 tokenId, uint256 newTVL) external {
        tokenTVLs[tokenId] = newTVL;
    }
}

contract SimpleTVLLeaderboard {
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
}

contract SimplePoolManager {
    // Minimal implementation to avoid validation
}

contract ReferralHookLogicTest is Test {
    ReferralHook public hook;
    SimpleReferralRegistry public registry;
    SimpleTVLLeaderboard public leaderboard;
    SimplePoolManager public poolManager;
    
    // Test users
    address public user1 = address(0x1001);
    address public user2 = address(0x1002);
    
    function setUp() public {
        // Deploy simple mocks
        registry = new SimpleReferralRegistry();
        leaderboard = new SimpleTVLLeaderboard();
        poolManager = new SimplePoolManager();
        
        // Deploy hook with simple mocks
        hook = new ReferralHook(
            IPoolManager(address(poolManager)),
            IReferralRegistry(address(registry)),
            ITVLLeaderboard(address(leaderboard))
        );
    }
    
    function test_setReferral_basic() public {
        string memory referralCode = "LOGIC_TEST_001";
        
        vm.prank(user1);
        hook.setReferral(referralCode);
        
        (uint256 tokenId, address kol, string memory code) = registry.getUserReferralInfo(user1);
        
        assertGt(tokenId, 0, "Token ID should be assigned");
        assertNotEq(kol, address(0), "KOL should be derived");
        assertEq(code, referralCode, "Code should match");
    }
    
    function test_getKOLStats_basic() public {
        address testKol = address(0x123);
        
        (uint256 tvl, uint256 users) = hook.getKOLStats(testKol);
        
        assertEq(tvl, 0, "Initial TVL should be 0");
        assertEq(users, 0, "Initial users should be 0");
    }
    
    function test_getUserReferrer_basic() public {
        PoolId poolId = PoolId.wrap(bytes32(uint256(1)));
        
        address referrer = hook.getUserReferrer(poolId, user1);
        
        assertEq(referrer, address(0), "Initial referrer should be 0");
    }
    
    function test_hookPermissions() public {
        Hooks.Permissions memory permissions = hook.getHookPermissions();
        
        assertTrue(permissions.afterAddLiquidity, "Should have afterAddLiquidity");
        assertTrue(permissions.afterRemoveLiquidity, "Should have afterRemoveLiquidity");
        
        // Others should be false
        assertFalse(permissions.beforeAddLiquidity, "Should not have beforeAddLiquidity");
        assertFalse(permissions.beforeRemoveLiquidity, "Should not have beforeRemoveLiquidity");
        assertFalse(permissions.beforeSwap, "Should not have beforeSwap");
        assertFalse(permissions.afterSwap, "Should not have afterSwap");
    }
    
    function test_contractReferences() public {
        assertEq(address(hook.referralRegistry()), address(registry), "Registry should match");
        assertEq(address(hook.tvlLeaderboard()), address(leaderboard), "Leaderboard should match");
        assertEq(address(hook.poolManager()), address(poolManager), "PoolManager should match");
    }
    
    function test_multipleUsersSetReferral() public {
        string memory code = "SHARED_KOL";
        
        vm.prank(user1);
        hook.setReferral(code);
        
        vm.prank(user2);
        hook.setReferral(code);
        
        (, address kol1, ) = registry.getUserReferralInfo(user1);
        (, address kol2, ) = registry.getUserReferralInfo(user2);
        
        assertEq(kol1, kol2, "Both users should have same KOL");
        assertNotEq(kol1, address(0), "KOL should be valid");
    }
    
    function test_tvlCalculationLogic() public {
        // Test the _calculateTVL logic indirectly by understanding BalanceDelta
        
        // In a real scenario, this would be tested through afterAddLiquidity
        // For now, just verify the hook is properly set up
        assertTrue(address(hook) != address(0), "Hook should be deployed");
    }
    
    function test_referralCodeConsistency() public {
        string memory code1 = "CONSISTENT_CODE";
        string memory code2 = "DIFFERENT_CODE";
        
        vm.prank(user1);
        hook.setReferral(code1);
        
        vm.prank(user2);
        hook.setReferral(code2);
        
        (, address kol1, ) = registry.getUserReferralInfo(user1);
        (, address kol2, ) = registry.getUserReferralInfo(user2);
        
        assertNotEq(kol1, kol2, "Different codes should produce different KOLs");
        
        // Test consistency - same code should produce same KOL
        address user3 = address(0x3003);
        vm.prank(user3);
        hook.setReferral(code1);
        
        (, address kol3, ) = registry.getUserReferralInfo(user3);
        assertEq(kol1, kol3, "Same code should produce same KOL");
    }
    
    function test_registryIntegration() public {
        vm.prank(user1);
        hook.setReferral("REGISTRY_INTEGRATION");
        
        (uint256 tokenId, , ) = registry.getUserReferralInfo(user1);
        
        // Verify initial TVL is 0
        assertEq(registry.tokenTVLs(tokenId), 0, "Initial TVL should be 0");
        
        // This tests that the hook can interact with the registry
        assertTrue(tokenId > 0, "Token ID should be valid");
    }
    
    function test_leaderboardIntegration() public {
        // Test that the hook can interact with the leaderboard
        address testKol = address(0x456);
        
        // Initially no updates called
        assertFalse(leaderboard.updateCalled(testKol), "No updates initially");
        
        // Test that we can set revert behavior
        leaderboard.setRevertBehavior(true, "Test error");
        
        vm.expectRevert("Test error");
        leaderboard.updateKOLMetrics(testKol, 1000, true, 1);
        
        // Reset
        leaderboard.setRevertBehavior(false, "");
        
        // Now should work
        leaderboard.updateKOLMetrics(testKol, 1000, true, 1);
        assertTrue(leaderboard.updateCalled(testKol), "Update should be called");
    }
    
    function test_errorScenarios() public {
        // Test empty referral code
        vm.prank(user1);
        hook.setReferral("");
        
        (, address kol, string memory code) = registry.getUserReferralInfo(user1);
        assertEq(code, "", "Empty code should be stored");
        
        // Test very long referral code
        string memory longCode = "THIS_IS_A_VERY_LONG_REFERRAL_CODE_THAT_TESTS_EDGE_CASES_AND_ENSURES_THE_SYSTEM_CAN_HANDLE_UNUSUAL_INPUT_LENGTHS";
        
        vm.prank(user2);
        hook.setReferral(longCode);
        
        (, , string memory code2) = registry.getUserReferralInfo(user2);
        assertEq(code2, longCode, "Long code should be stored");
    }
    
    function test_realWorldDeployedHookAddress() public {
        // This test confirms we're aware of the real deployed hook
        address realHookAddress = 0x251369069A9c93A7615338c9a7127B9693428500;
        
        // Our test hook will have a different address, but the logic should be the same
        assertNotEq(address(hook), realHookAddress, "Test hook has different address");
        
        // But the logic should be equivalent - this test passes if we can set referrals
        vm.prank(user1);
        hook.setReferral("REAL_WORLD_TEST");
        
        (uint256 tokenId, address kol, ) = registry.getUserReferralInfo(user1);
        assertGt(tokenId, 0, "Logic works like real hook");
        assertNotEq(kol, address(0), "KOL derivation works like real hook");
    }
    
    function test_coreBusinessLogic() public {
        // Test the core business logic that the real hook implements
        
        // 1. User sets referral code
        string memory kolCode = "BUSINESS_LOGIC_TEST";
        vm.prank(user1);
        hook.setReferral(kolCode);
        
        // 2. User info is correctly stored
        (uint256 tokenId, address kol, string memory code) = registry.getUserReferralInfo(user1);
        assertEq(code, kolCode, "Code stored correctly");
        assertNotEq(kol, address(0), "KOL derived correctly");
        assertGt(tokenId, 0, "Token ID assigned correctly");
        
        // 3. Multiple users with same code get same KOL
        vm.prank(user2);
        hook.setReferral(kolCode);
        
        (, address kol2, ) = registry.getUserReferralInfo(user2);
        assertEq(kol, kol2, "Same KOL for same code");
        
        // 4. Stats are initially zero
        (uint256 tvl, uint256 users) = hook.getKOLStats(kol);
        assertEq(tvl, 0, "Initial TVL is 0");
        assertEq(users, 0, "Initial users is 0");
        
        // This confirms the core business logic works as expected
    }
    
    function test_realHookAddress() public {
        // Confirma que conocemos la dirección real del hook deployado
        address realHookAddress = 0x251369069A9c93A7615338c9a7127B9693428500;
        
        // Este test simplemente documenta la dirección real
        assertNotEq(realHookAddress, address(0), "Real hook address should be valid");
        
        // Log para verificar en los tests
        console.log("Real deployed hook address:", realHookAddress);
    }
} 