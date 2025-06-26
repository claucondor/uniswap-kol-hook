// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralRegistry.base.t.sol";

contract ReferralRegistryNFTTransferTest is ReferralRegistryBase {
    
    uint256 tokenId1;
    uint256 tokenId2;
    address newKol = address(0x300);
    
    function setUp() public override {
        super.setUp();
        tokenId1 = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        tokenId2 = mintReferralAsMinter(kol1, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
    }
    
    function test_transfer_shouldTransferNFTSuccessfully() public {
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, newKol, tokenId1);
        
        assertEq(referralRegistry.ownerOf(tokenId1), newKol);
        assertEq(referralRegistry.balanceOf(kol1), 1); // Still has tokenId2
        assertEq(referralRegistry.balanceOf(newKol), 1);
    }
    
    function test_transfer_shouldUpdateKolInReferralInfo() public {
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, newKol, tokenId1);
        
        (, address kol, , , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(kol, newKol);
    }
    
    function test_transfer_shouldUpdateKolTokensMappings() public {
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, newKol, tokenId1);
        
        // Check old owner's tokens
        uint256[] memory kol1Tokens = referralRegistry.getKOLTokens(kol1);
        assertEq(kol1Tokens.length, 1);
        assertEq(kol1Tokens[0], tokenId2); // Only tokenId2 remains
        
        // Check new owner's tokens
        uint256[] memory newKolTokens = referralRegistry.getKOLTokens(newKol);
        assertEq(newKolTokens.length, 1);
        assertEq(newKolTokens[0], tokenId1);
    }
    
    function test_transfer_shouldHandleMultipleTokensCorrectly() public {
        // kol1 has tokenId1 and tokenId2
        uint256[] memory initialTokens = referralRegistry.getKOLTokens(kol1);
        assertEq(initialTokens.length, 2);
        
        // Transfer tokenId1 (first token in array)
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, newKol, tokenId1);
        
        // kol1 should now only have tokenId2
        uint256[] memory kol1Tokens = referralRegistry.getKOLTokens(kol1);
        assertEq(kol1Tokens.length, 1);
        assertEq(kol1Tokens[0], tokenId2);
        
        // newKol should have tokenId1
        uint256[] memory newKolTokens = referralRegistry.getKOLTokens(newKol);
        assertEq(newKolTokens.length, 1);
        assertEq(newKolTokens[0], tokenId1);
    }
    
    function test_transfer_shouldTransferSecondTokenCorrectly() public {
        // Transfer tokenId2 (second token in array)
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, newKol, tokenId2);
        
        // kol1 should now only have tokenId1
        uint256[] memory kol1Tokens = referralRegistry.getKOLTokens(kol1);
        assertEq(kol1Tokens.length, 1);
        assertEq(kol1Tokens[0], tokenId1);
        
        // newKol should have tokenId2
        uint256[] memory newKolTokens = referralRegistry.getKOLTokens(newKol);
        assertEq(newKolTokens.length, 1);
        assertEq(newKolTokens[0], tokenId2);
    }
    
    function test_transfer_shouldAllowTransferToExistingKol() public {
        // Transfer tokenId1 from kol1 to kol2
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
        
        // kol2 should now have the transferred token
        uint256[] memory kol2Tokens = referralRegistry.getKOLTokens(kol2);
        assertEq(kol2Tokens.length, 1);
        assertEq(kol2Tokens[0], tokenId1);
        
        // Verify the referral info is updated
        (, address kol, , , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(kol, kol2);
    }
    
    function test_safeTransferFrom_shouldWorkCorrectly() public {
        vm.prank(kol1);
        referralRegistry.safeTransferFrom(kol1, newKol, tokenId1);
        
        assertEq(referralRegistry.ownerOf(tokenId1), newKol);
        
        // Check mappings are updated
        uint256[] memory newKolTokens = referralRegistry.getKOLTokens(newKol);
        assertEq(newKolTokens.length, 1);
        assertEq(newKolTokens[0], tokenId1);
    }
    
    function test_approve_shouldAllowApprovedTransfer() public {
        // Approve newKol to transfer tokenId1
        vm.prank(kol1);
        referralRegistry.approve(newKol, tokenId1);
        
        // newKol can now transfer the token
        vm.prank(newKol);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
        
        assertEq(referralRegistry.ownerOf(tokenId1), kol2);
        
        // Check mappings are updated
        (, address kol, , , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(kol, kol2);
    }
    
    function test_setApprovalForAll_shouldAllowOperatorTransfer() public {
        // Set newKol as operator for all kol1's tokens
        vm.prank(kol1);
        referralRegistry.setApprovalForAll(newKol, true);
        
        // newKol can transfer any of kol1's tokens
        vm.prank(newKol);
        referralRegistry.transferFrom(kol1, kol2, tokenId1);
        
        vm.prank(newKol);
        referralRegistry.transferFrom(kol1, kol2, tokenId2);
        
        // Both tokens should be with kol2
        uint256[] memory kol2Tokens = referralRegistry.getKOLTokens(kol2);
        assertEq(kol2Tokens.length, 2);
        
        // kol1 should have no tokens
        uint256[] memory kol1Tokens = referralRegistry.getKOLTokens(kol1);
        assertEq(kol1Tokens.length, 0);
    }
    
    // Failure cases
    function test_transfer_shouldRevertWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        expectPausedError();
        
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, newKol, tokenId1);
    }
    
    function test_transfer_shouldRevertFromUnauthorized() public {
        expectInsufficientApprovalError(unauthorized, tokenId1);
        
        vm.prank(unauthorized);
        referralRegistry.transferFrom(kol1, newKol, tokenId1);
    }
    
    function test_transfer_shouldNotUpdateMappingsForSameOwner() public {
        // Transfer to same owner should not update mappings
        uint256[] memory initialTokens = referralRegistry.getKOLTokens(kol1);
        
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, kol1, tokenId1);
        
        uint256[] memory finalTokens = referralRegistry.getKOLTokens(kol1);
        assertEq(finalTokens.length, initialTokens.length);
        
        // Referral info should remain the same
        (, address kol, , , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(kol, kol1);
    }
    
    function test_transfer_shouldNotAffectUserReferrals() public {
        // Add some user referrals first
        setUserReferralAs(user1, user1, REFERRAL_CODE_1);
        setUserReferralAs(user2, user2, REFERRAL_CODE_1);
        
        // Transfer the NFT
        vm.prank(kol1);
        referralRegistry.transferFrom(kol1, newKol, tokenId1);
        
        // User referrals should still work and point to the same token
        (uint256 user1TokenId, address user1Kol, ) = referralRegistry.getUserReferralInfo(user1);
        (uint256 user2TokenId, address user2Kol, ) = referralRegistry.getUserReferralInfo(user2);
        
        assertEq(user1TokenId, tokenId1);
        assertEq(user2TokenId, tokenId1);
        // But the KOL should be updated to the new owner
        assertEq(user1Kol, newKol);
        assertEq(user2Kol, newKol);
    }
} 