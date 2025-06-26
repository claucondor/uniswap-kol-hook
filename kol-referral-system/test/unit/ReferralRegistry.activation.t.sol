// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralRegistry.base.t.sol";

contract ReferralRegistryActivationTest is ReferralRegistryBase {
    
    uint256 tokenId1;
    uint256 tokenId2;
    
    function setUp() public override {
        super.setUp();
        tokenId1 = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        tokenId2 = mintReferralAsMinter(kol2, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
    }
    
    function test_deactivateReferral_shouldDeactivateByOwner() public {
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        (, , , , , bool isActive, , ) = referralRegistry.referralInfo(tokenId1);
        assertFalse(isActive);
    }
    
    function test_deactivateReferral_shouldDeactivateByAdmin() public {
        vm.prank(admin);
        referralRegistry.deactivateReferral(tokenId1);
        
        (, , , , , bool isActive, , ) = referralRegistry.referralInfo(tokenId1);
        assertFalse(isActive);
    }
    
    function test_deactivateReferral_shouldEmitEvent() public {
        vm.expectEmit(true, false, false, false);
        emit ReferralRegistry.ReferralDeactivated(tokenId1);
        
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
    }
    
    function test_deactivateReferral_shouldNotAffectOtherReferrals() public {
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // tokenId1 should be inactive
        (, , , , , bool isActive1, , ) = referralRegistry.referralInfo(tokenId1);
        assertFalse(isActive1);
        
        // tokenId2 should still be active
        (, , , , , bool isActive2, , ) = referralRegistry.referralInfo(tokenId2);
        assertTrue(isActive2);
    }
    
    function test_activateReferral_shouldActivateByAdmin() public {
        // First deactivate
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Then reactivate by admin
        vm.prank(admin);
        referralRegistry.activateReferral(tokenId1);
        
        (, , , , , bool isActive, , ) = referralRegistry.referralInfo(tokenId1);
        assertTrue(isActive);
    }
    
    function test_activateReferral_shouldOnlyAllowAdmin() public {
        // First deactivate
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Owner cannot reactivate
        expectAccessControlError(kol1, referralRegistry.DEFAULT_ADMIN_ROLE());
        
        vm.prank(kol1);
        referralRegistry.activateReferral(tokenId1);
    }
    
    function test_isValidReferralCode_shouldRespectActivation() public {
        // Initially active
        assertTrue(referralRegistry.isValidReferralCode(REFERRAL_CODE_1));
        
        // Deactivate
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Should be invalid now
        assertFalse(referralRegistry.isValidReferralCode(REFERRAL_CODE_1));
        
        // Reactivate
        vm.prank(admin);
        referralRegistry.activateReferral(tokenId1);
        
        // Should be valid again
        assertTrue(referralRegistry.isValidReferralCode(REFERRAL_CODE_1));
    }
    
    function test_setUserReferral_shouldFailForInactiveReferral() public {
        // Deactivate referral
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Should not be able to set user referral
        expectRevertWithMessage("Referral inactive");
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
    }
    
    function test_setUserReferral_shouldStillWorkAfterReactivation() public {
        // Deactivate referral
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Reactivate
        vm.prank(admin);
        referralRegistry.activateReferral(tokenId1);
        
        // Should work now
        (uint256 returnedTokenId, address returnedKol) = setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        assertEq(returnedTokenId, tokenId1);
        assertEq(returnedKol, kol1);
    }
    
    function test_deactivation_shouldNotAffectExistingUserReferrals() public {
        // Set user referral while active
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        
        // Deactivate referral
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Existing user referral should still be accessible
        (uint256 tokenId, address kol, string memory code) = referralRegistry.getUserReferralInfo(user1);
        assertEq(tokenId, tokenId1);
        assertEq(kol, kol1);
        assertEq(code, REFERRAL_CODE_1);
    }
    
    function test_deactivation_shouldNotAffectTVLUpdates() public {
        // Deactivate referral
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // TVL updates should still work
        uint256 newTVL = 1000e18;
        updateTVLAs(updater, tokenId1, newTVL);
        
        (, , uint256 totalTVL, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL, newTVL);
    }
    
    function test_transferAfterDeactivation_shouldUpdateNewOwner() public {
        // Deactivate referral
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        // Transfer to kol2
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
        
        // Referral should still be inactive but owned by kol2
        (, address kol, , , , bool isActive, , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(kol, kol2);
        assertFalse(isActive);
        
        // kol2 should be able to reactivate (but only admin can)
        expectAccessControlError(kol2, referralRegistry.DEFAULT_ADMIN_ROLE());
        
        vm.prank(kol2);
        referralRegistry.activateReferral(tokenId1);
    }
    
    // Failure cases
    function test_deactivateReferral_shouldRevertForUnauthorized() public {
        expectRevertWithMessage("Not authorized");
        
        vm.prank(unauthorized);
        referralRegistry.deactivateReferral(tokenId1);
    }
    
    function test_deactivateReferral_shouldRevertForNonexistentToken() public {
        uint256 nonexistentTokenId = 999;
        
        expectNonexistentTokenError(nonexistentTokenId);
        
        vm.prank(admin);
        referralRegistry.deactivateReferral(nonexistentTokenId);
    }
    
    function test_activateReferral_shouldRevertForNonexistentToken() public {
        uint256 nonexistentTokenId = 999;
        
        expectRevertWithMessage("Token does not exist");
        
        vm.prank(admin);
        referralRegistry.activateReferral(nonexistentTokenId);
    }
    
    function test_activateReferral_shouldRevertForUnauthorized() public {
        expectAccessControlError(unauthorized, referralRegistry.DEFAULT_ADMIN_ROLE());
        
        vm.prank(unauthorized);
        referralRegistry.activateReferral(tokenId1);
    }
    
    function test_ownerCanDeactivateAfterTransfer() public {
        // Transfer token
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
        
        // New owner should be able to deactivate
        vm.prank(kol2);
        referralRegistry.deactivateReferral(tokenId1);
        
        (, , , , , bool isActive, , ) = referralRegistry.referralInfo(tokenId1);
        assertFalse(isActive);
    }
    
    function test_oldOwnerCannotDeactivateAfterTransfer() public {
        // Transfer token
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
        
        // Old owner should not be able to deactivate
        expectRevertWithMessage("Not authorized");
        
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
    }
} 