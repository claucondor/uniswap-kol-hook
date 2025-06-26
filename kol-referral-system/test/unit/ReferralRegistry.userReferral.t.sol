// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralRegistry.base.t.sol";

contract ReferralRegistryUserReferralTest is ReferralRegistryBase {
    
    uint256 tokenId1;
    uint256 tokenId2;
    
    function setUp() public override {
        super.setUp();
        tokenId1 = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        tokenId2 = mintReferralAsMinter(kol2, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
    }
    
    function test_setUserReferral_shouldSetReferralSuccessfully() public {
        (uint256 returnedTokenId, address returnedKol) = setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        
        assertEq(returnedTokenId, tokenId1);
        assertEq(returnedKol, kol1);
        assertEq(referralRegistry.userReferralToken(user1), tokenId1);
    }
    
    function test_setUserReferral_shouldIncrementUniqueUsers() public {
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        
        (, , , uint256 uniqueUsers, , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(uniqueUsers, 1);
    }
    
    function test_setUserReferral_shouldEmitUserReferredEvent() public {
        vm.expectEmit(true, true, true, true);
        emit ReferralRegistry.UserReferred(user1, tokenId1, kol1);
        
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
    }
    
    function test_setUserReferral_shouldAllowMultipleUsersForSameReferral() public {
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        setUserReferralAs(user2, user2, REFERRAL_CODE_1);
        setUserReferralAs(user3, user3, REFERRAL_CODE_1);
        
        assertEq(referralRegistry.userReferralToken(user1), tokenId1);
        assertEq(referralRegistry.userReferralToken(user2), tokenId1);
        assertEq(referralRegistry.userReferralToken(user3), tokenId1);
        
        (, , , uint256 uniqueUsers, , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(uniqueUsers, 3);
    }
    
    function test_setUserReferral_shouldWorkForDifferentReferrals() public {
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        setUserReferralAs(user2, user2, REFERRAL_CODE_2);
        
        assertEq(referralRegistry.userReferralToken(user1), tokenId1);
        assertEq(referralRegistry.userReferralToken(user2), tokenId2);
        
        (, , , uint256 uniqueUsers1, , , , ) = referralRegistry.referralInfo(tokenId1);
        (, , , uint256 uniqueUsers2, , , , ) = referralRegistry.referralInfo(tokenId2);
        assertEq(uniqueUsers1, 1);
        assertEq(uniqueUsers2, 1);
    }
    
    function test_setUserReferral_shouldAllowAnyoneToCallForAnyUser() public {
        // unauthorized can set referral for user1
        setUserReferralAs(unauthorized, user1, REFERRAL_CODE_1);
        
        assertEq(referralRegistry.userReferralToken(user1), tokenId1);
    }
    
    function test_getUserReferralInfo_shouldReturnCorrectInfo() public {
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        
        (uint256 returnedTokenId, address returnedKol, string memory returnedCode) = 
            referralRegistry.getUserReferralInfo(user1);
        
        assertEq(returnedTokenId, tokenId1);
        assertEq(returnedKol, kol1);
        assertEq(returnedCode, REFERRAL_CODE_1);
    }
    
    function test_getUserReferralInfo_shouldReturnZeroForUnreferredUser() public {
        (uint256 returnedTokenId, address returnedKol, string memory returnedCode) = 
            referralRegistry.getUserReferralInfo(user1);
        
        assertEq(returnedTokenId, 0);
        assertEq(returnedKol, address(0));
        assertEq(returnedCode, "");
    }
    
    // Failure cases
    function test_setUserReferral_shouldRevertWithZeroAddress() public {
        expectRevertWithMessage("Invalid user address");
        setUserReferralAs(user1, address(0), REFERRAL_CODE_1);
    }
    
    function test_setUserReferral_shouldRevertWhenUserAlreadyReferred() public {
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        
        expectRevertWithMessage("User already referred");
        setUserReferralAs(user1, user1, REFERRAL_CODE_2);
    }
    
    function test_setUserReferral_shouldRevertWithEmptyCode() public {
        expectRevertWithMessage("Empty referral code");
        setUserReferralAs(user1, user1, "");
    }
    
    function test_setUserReferral_shouldRevertWithInvalidCode() public {
        expectRevertWithMessage("Invalid referral code");
        setUserReferralAs(user1, user1, "INVALID_CODE");
    }
    
    function test_setUserReferral_shouldRevertWithInactiveReferral() public {
        // Deactivate the referral
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        expectRevertWithMessage("Referral inactive");
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
    }
    
    function test_getReferralByCode_shouldReturnCorrectInfo() public {
        (uint256 returnedTokenId, ReferralRegistry.ReferralInfo memory info) = 
            referralRegistry.getReferralByCode(REFERRAL_CODE_1);
        
        assertEq(returnedTokenId, tokenId1);
        assertEq(info.referralCode, REFERRAL_CODE_1);
        assertEq(info.kol, kol1);
        assertEq(info.totalTVL, 0);
        assertEq(info.uniqueUsers, 0);
        assertTrue(info.isActive);
        assertEq(info.socialHandle, SOCIAL_HANDLE_1);
        assertEq(info.metadata, METADATA_URI_1);
    }
    
    function test_getReferralByCode_shouldReturnZeroForInvalidCode() public {
        (uint256 returnedTokenId, ) = referralRegistry.getReferralByCode("INVALID_CODE");
        assertEq(returnedTokenId, 0);
    }
    
    function test_isValidReferralCode_shouldReturnTrueForActiveCode() public {
        assertTrue(referralRegistry.isValidReferralCode(REFERRAL_CODE_1));
    }
    
    function test_isValidReferralCode_shouldReturnFalseForInvalidCode() public {
        assertFalse(referralRegistry.isValidReferralCode("INVALID_CODE"));
    }
    
    function test_isValidReferralCode_shouldReturnFalseForInactiveCode() public {
        vm.prank(kol1);
        referralRegistry.deactivateReferral(tokenId1);
        
        assertFalse(referralRegistry.isValidReferralCode(REFERRAL_CODE_1));
    }
} 