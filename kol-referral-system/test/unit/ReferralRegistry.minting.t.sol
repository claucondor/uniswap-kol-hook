// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralRegistry.base.t.sol";

contract ReferralRegistryMintingTest is ReferralRegistryBase {
    
    function test_mintReferral_shouldMintSuccessfully() public {
        uint256 tokenId = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        
        assertEq(tokenId, 1);
        assertEq(referralRegistry.ownerOf(tokenId), kol1);
        assertEq(referralRegistry.totalSupply(), 1);
        assertEq(referralRegistry.tokenURI(tokenId), METADATA_URI_1);
    }
    
    function test_mintReferral_shouldStoreCorrectReferralInfo() public {
        uint256 tokenId = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        
        (
            string memory referralCode,
            address kol,
            uint256 totalTVL,
            uint256 uniqueUsers,
            uint256 createdAt,
            bool isActive,
            string memory socialHandle,
            string memory metadata
        ) = referralRegistry.referralInfo(tokenId);
        
        assertEq(referralCode, REFERRAL_CODE_1);
        assertEq(kol, kol1);
        assertEq(totalTVL, 0);
        assertEq(uniqueUsers, 0);
        assertGt(createdAt, 0);
        assertTrue(isActive);
        assertEq(socialHandle, SOCIAL_HANDLE_1);
        assertEq(metadata, METADATA_URI_1);
    }
    
    function test_mintReferral_shouldMapCodeToTokenId() public {
        uint256 tokenId = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        
        assertEq(referralRegistry.codeToTokenId(REFERRAL_CODE_1), tokenId);
    }
    
    function test_mintReferral_shouldAddToKolTokens() public {
        uint256 tokenId = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        
        uint256[] memory kolTokens = referralRegistry.getKOLTokens(kol1);
        assertEq(kolTokens.length, 1);
        assertEq(kolTokens[0], tokenId);
    }
    
    function test_mintReferral_shouldEmitReferralMintedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit ReferralRegistry.ReferralMinted(1, kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1);
        
        mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
    }
    
    function test_mintReferral_shouldAllowMultipleReferralsForSameKol() public {
        uint256 tokenId1 = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        uint256 tokenId2 = mintReferralAsMinter(kol1, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        
        uint256[] memory kolTokens = referralRegistry.getKOLTokens(kol1);
        assertEq(kolTokens.length, 2);
        assertEq(kolTokens[0], tokenId1);
        assertEq(kolTokens[1], tokenId2);
    }
    
    function test_mintReferral_shouldHandleEmptyMetadataURI() public {
        uint256 tokenId = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, "");
        
        // Should not revert and tokenURI should be empty
        assertEq(referralRegistry.tokenURI(tokenId), "");
    }
    
    // Failure cases
    function test_mintReferral_shouldRevertWithoutMinterRole() public {
        expectAccessControlError(unauthorized, referralRegistry.MINTER_ROLE());
        
        vm.prank(unauthorized);
        referralRegistry.mintReferral(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
    }
    
    function test_mintReferral_shouldRevertWithDuplicateCode() public {
        mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        
        expectRevertWithMessage("Code already exists");
        mintReferralAsMinter(kol2, REFERRAL_CODE_1, SOCIAL_HANDLE_2, METADATA_URI_2);
    }
    
    function test_mintReferral_shouldRevertWithZeroAddress() public {
        expectRevertWithMessage("Invalid KOL address");
        mintReferralAsMinter(address(0), REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
    }
    
    function test_mintReferral_shouldRevertWithEmptyCode() public {
        expectRevertWithMessage("Empty referral code");
        mintReferralAsMinter(kol1, "", SOCIAL_HANDLE_1, METADATA_URI_1);
    }
    
    function test_mintReferral_shouldRevertWhenPaused() public {
        vm.prank(admin);
        referralRegistry.pause();
        
        expectPausedError();
        mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
    }
    
    function test_mintReferral_shouldIncrementTokenIds() public {
        uint256 tokenId1 = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        uint256 tokenId2 = mintReferralAsMinter(kol2, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
        
        assertEq(tokenId1, 1);
        assertEq(tokenId2, 2);
        assertEq(referralRegistry.totalSupply(), 2);
    }
} 