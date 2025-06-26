// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralRegistry.base.t.sol";

contract ReferralRegistryPausableTest is ReferralRegistryBase {
    
    uint256 tokenId1;
    
    function setUp() public override {
        super.setUp();
        tokenId1 = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
    }
    
    function test_pause_shouldPauseByAdmin() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        assertTrue(referralRegistry.paused());
    }
    
    function test_pause_shouldPauseByPauserRole() public {
        // Admin already has PAUSER_ROLE by default, so we can test with admin
        assertTrue(referralRegistry.hasRole(referralRegistry.PAUSER_ROLE(), admin));
        
        vm.prank(admin);
        referralRegistry.pause();
        
        assertTrue(referralRegistry.paused());
    }
    
    function test_unpause_shouldUnpauseByAdmin() public {
        // First pause
        vm.prank(admin);
        referralRegistry.pause();
        
        // Then unpause
        vm.prank(admin);
        referralRegistry.unpause();
        
        assertFalse(referralRegistry.paused());
    }
    
    function test_unpause_shouldUnpauseByPauserRole() public {
        // Admin already has PAUSER_ROLE by default, so we can test with admin
        assertTrue(referralRegistry.hasRole(referralRegistry.PAUSER_ROLE(), admin));
        
        // Pause
        vm.prank(admin);
        referralRegistry.pause();
        
        // Unpause
        vm.prank(admin);
        referralRegistry.unpause();
        
        assertFalse(referralRegistry.paused());
    }
    
    function test_mintReferral_shouldRevertWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        expectPausedError();
        mintReferralAsMinter(kol2, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
    }
    
    function test_transferFrom_shouldRevertWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        expectPausedError();
        
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
    }
    
    function test_safeTransferFrom_shouldRevertWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        expectPausedError();
        
        vm.prank(kol1);
        referralRegistry.safeTransferFrom(kol1, kol2, tokenId1);
    }
    
    function test_setUserReferral_shouldStillWorkWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        // setUserReferral should still work when paused
        (uint256 returnedTokenId, address returnedKol) = setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        assertEq(returnedTokenId, tokenId1);
        assertEq(returnedKol, kol1);
    }
    
    function test_updateTVL_shouldStillWorkWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        // TVL updates should still work when paused
        uint256 newTVL = 1000e18;
        updateTVLAs(updater, tokenId1, newTVL);
        
        (, , uint256 totalTVL, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL, newTVL);
    }
    
    function test_deactivateReferral_shouldStillWorkWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        // Deactivation should still work when paused
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        (, , , , , bool isActive, , ) = referralRegistry.referralInfo(tokenId1);
        assertFalse(isActive);
    }
    
    function test_activateReferral_shouldStillWorkWhenPaused() public {
        // First deactivate
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Then pause
        vm.prank(admin);
        referralRegistry.pause();
        
        // Activation should still work when paused
        vm.prank(admin);
        referralRegistry.activateReferral(tokenId1);
        
        (, , , , , bool isActive, , ) = referralRegistry.referralInfo(tokenId1);
        assertTrue(isActive);
    }
    
    function test_readFunctions_shouldStillWorkWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        // All read functions should still work
        assertEq(referralRegistry.ownerOf(tokenId1), kol1);
        assertEq(referralRegistry.balanceOf(kol1), 1);
        assertEq(referralRegistry.totalSupply(), 1);
        
        (string memory code, address kol, , , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(code, REFERRAL_CODE_1);
        assertEq(kol, kol1);
        
        assertTrue(referralRegistry.isValidReferralCode(REFERRAL_CODE_1));
        
        uint256[] memory kolTokens = referralRegistry.getKOLTokens(kol1);
        assertEq(kolTokens.length, 1);
        assertEq(kolTokens[0], tokenId1);
    }
    
    function test_approve_shouldStillWorkWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        // OpenZeppelin v5 doesn't pause approve functions
        vm.prank(kol1);
        referralRegistry.approve(kol2, tokenId1);
        
        assertEq(referralRegistry.getApproved(tokenId1), kol2);
    }
    
    function test_setApprovalForAll_shouldStillWorkWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        // OpenZeppelin v5 doesn't pause setApprovalForAll
        vm.prank(kol1);
        referralRegistry.setApprovalForAll(kol2, true);
        
        assertTrue(referralRegistry.isApprovedForAll(kol1, kol2));
    }
    
    function test_functionsResumeAfterUnpause() public {
        // Pause
        vm.prank(admin);
        referralRegistry.pause();
        
        // Unpause
        vm.prank(admin);
        referralRegistry.unpause();
        
        // All functions should work again
        mintReferralAsMinter(kol2, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
        
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
        
        assertEq(referralRegistry.ownerOf(tokenId1), kol2);
    }
    
    // Failure cases
    function test_pause_shouldRevertWithoutPauserRole() public {
        expectAccessControlError(unauthorized, referralRegistry.PAUSER_ROLE());
        
        vm.prank(unauthorized);
        referralRegistry.pause();
    }
    
    function test_unpause_shouldRevertWithoutPauserRole() public {
        // First pause by admin
        vm.prank(admin);
        referralRegistry.pause();
        
        expectAccessControlError(unauthorized, referralRegistry.PAUSER_ROLE());
        
        vm.prank(unauthorized);
        referralRegistry.unpause();
    }
    
    function test_kolCannotPause() public {
        expectAccessControlError(kol1, referralRegistry.PAUSER_ROLE());
        
        vm.prank(kol1);
        referralRegistry.pause();
    }
    
    function test_minterCannotPause() public {
        expectAccessControlError(minter, referralRegistry.PAUSER_ROLE());
        
        vm.prank(minter);
        referralRegistry.pause();
    }
    
    function test_updaterCannotPause() public {
        expectAccessControlError(updater, referralRegistry.PAUSER_ROLE());
        
        vm.prank(updater);
        referralRegistry.pause();
    }
} 