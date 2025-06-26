// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralRegistry.base.t.sol";

contract ReferralRegistryTVLUpdateTest is ReferralRegistryBase {
    
    uint256 tokenId1;
    uint256 tokenId2;
    
    function setUp() public override {
        super.setUp();
        tokenId1 = mintReferralAsMinter(kol1, REFERRAL_CODE_1, SOCIAL_HANDLE_1, METADATA_URI_1);
        tokenId2 = mintReferralAsMinter(kol2, REFERRAL_CODE_2, SOCIAL_HANDLE_2, METADATA_URI_2);
    }
    
    function test_updateTVL_shouldUpdateSuccessfully() public {
        uint256 newTVL = 1000e18;
        updateTVLAs(updater, tokenId1, newTVL);
        
        (, , uint256 totalTVL, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL, newTVL);
    }
    
    function test_updateTVL_shouldEmitTVLUpdatedEvent() public {
        uint256 newTVL = 1000e18;
        
        vm.expectEmit(true, false, false, true);
        emit ReferralRegistry.TVLUpdated(tokenId1, newTVL);
        
        updateTVLAs(updater, tokenId1, newTVL);
    }
    
    function test_updateTVL_shouldAllowMultipleUpdates() public {
        uint256 firstTVL = 1000e18;
        uint256 secondTVL = 2000e18;
        uint256 thirdTVL = 500e18;
        
        updateTVLAs(updater, tokenId1, firstTVL);
        (, , uint256 totalTVL1, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL1, firstTVL);
        
        updateTVLAs(updater, tokenId1, secondTVL);
        (, , uint256 totalTVL2, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL2, secondTVL);
        
        updateTVLAs(updater, tokenId1, thirdTVL);
        (, , uint256 totalTVL3, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL3, thirdTVL);
    }
    
    function test_updateTVL_shouldUpdateDifferentTokensSeparately() public {
        uint256 tvl1 = 1000e18;
        uint256 tvl2 = 2000e18;
        
        updateTVLAs(updater, tokenId1, tvl1);
        updateTVLAs(updater, tokenId2, tvl2);
        
        (, , uint256 totalTVL1, , , , , ) = referralRegistry.referralInfo(tokenId1);
        (, , uint256 totalTVL2, , , , , ) = referralRegistry.referralInfo(tokenId2);
        
        assertEq(totalTVL1, tvl1);
        assertEq(totalTVL2, tvl2);
    }
    
    function test_updateTVL_shouldAllowZeroTVL() public {
        uint256 initialTVL = 1000e18;
        uint256 zeroTVL = 0;
        
        updateTVLAs(updater, tokenId1, initialTVL);
        updateTVLAs(updater, tokenId1, zeroTVL);
        
        (, , uint256 totalTVL, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL, zeroTVL);
    }
    
    function test_updateTVL_shouldAllowAdminToUpdate() public {
        uint256 newTVL = 1000e18;
        updateTVLAs(admin, tokenId1, newTVL);
        
        (, , uint256 totalTVL, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL, newTVL);
    }
    
    function test_updateTVL_shouldHandleLargeTVLValues() public {
        uint256 largeTVL = type(uint256).max;
        updateTVLAs(updater, tokenId1, largeTVL);
        
        (, , uint256 totalTVL, , , , , ) = referralRegistry.referralInfo(tokenId1);
        assertEq(totalTVL, largeTVL);
    }
    
    // Failure cases
    function test_updateTVL_shouldRevertWithoutUpdaterRole() public {
        uint256 newTVL = 1000e18;
        
        expectAccessControlError(unauthorized, referralRegistry.UPDATER_ROLE());
        
        vm.prank(unauthorized);
        referralRegistry.updateTVL(tokenId1, newTVL);
    }
    
    function test_updateTVL_shouldRevertForNonexistentToken() public {
        uint256 nonexistentTokenId = 999;
        uint256 newTVL = 1000e18;
        
        expectRevertWithMessage("Token does not exist");
        updateTVLAs(updater, nonexistentTokenId, newTVL);
    }
    
    function test_updateTVL_shouldRevertForKolWithoutRole() public {
        uint256 newTVL = 1000e18;
        
        expectAccessControlError(kol1, referralRegistry.UPDATER_ROLE());
        
        vm.prank(kol1);
        referralRegistry.updateTVL(tokenId1, newTVL);
    }
    
    function test_updateTVL_shouldNotAffectOtherFields() public {
        // Get initial state
        (
            string memory initialCode,
            address initialKol,
            ,
            uint256 initialUsers,
            uint256 initialCreatedAt,
            bool initialIsActive,
            string memory initialSocialHandle,
            string memory initialMetadata
        ) = referralRegistry.referralInfo(tokenId1);
        
        uint256 newTVL = 1000e18;
        updateTVLAs(updater, tokenId1, newTVL);
        
        // Get updated state
        (
            string memory updatedCode,
            address updatedKol,
            uint256 updatedTVL,
            uint256 updatedUsers,
            uint256 updatedCreatedAt,
            bool updatedIsActive,
            string memory updatedSocialHandle,
            string memory updatedMetadata
        ) = referralRegistry.referralInfo(tokenId1);
        
        // Only TVL should change
        assertEq(updatedCode, initialCode);
        assertEq(updatedKol, initialKol);
        assertEq(updatedTVL, newTVL);
        assertEq(updatedUsers, initialUsers);
        assertEq(updatedCreatedAt, initialCreatedAt);
        assertEq(updatedIsActive, initialIsActive);
        assertEq(updatedSocialHandle, initialSocialHandle);
        assertEq(updatedMetadata, initialMetadata);
    }
} 