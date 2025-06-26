// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../../contracts/core/ReferralRegistry.sol";

abstract contract ReferralRegistryBase is Test {
    ReferralRegistry public referralRegistry;
    
    // Test accounts
    address public admin = address(0x1);
    address public minter = address(0x2);
    address public updater = address(0x3);
    address public kol1 = address(0x100);
    address public kol2 = address(0x101);
    address public user1 = address(0x200);
    address public user2 = address(0x201);
    address public user3 = address(0x202);
    address public unauthorized = address(0x999);
    
    // Test data
    string public constant REFERRAL_CODE_1 = "KOL001";
    string public constant REFERRAL_CODE_2 = "KOL002";
    string public constant SOCIAL_HANDLE_1 = "@kol1_twitter";
    string public constant SOCIAL_HANDLE_2 = "@kol2_twitter";
    string public constant METADATA_URI_1 = "ipfs://QmTest1";
    string public constant METADATA_URI_2 = "ipfs://QmTest2";
    
    function setUp() public virtual {
        vm.startPrank(admin);
        
        // Deploy ReferralRegistry
        referralRegistry = new ReferralRegistry();
        
        // Grant roles
        referralRegistry.grantRole(referralRegistry.MINTER_ROLE(), minter);
        referralRegistry.grantRole(referralRegistry.UPDATER_ROLE(), updater);
        
        vm.stopPrank();
    }
    
    // Helper functions
    function mintReferralAsAdmin(
        address kol,
        string memory referralCode,
        string memory socialHandle,
        string memory metadataURI
    ) internal returns (uint256) {
        vm.prank(admin);
        return referralRegistry.mintReferral(kol, referralCode, socialHandle, metadataURI);
    }
    
    function mintReferralAsMinter(
        address kol,
        string memory referralCode,
        string memory socialHandle,
        string memory metadataURI
    ) internal returns (uint256) {
        vm.prank(minter);
        return referralRegistry.mintReferral(kol, referralCode, socialHandle, metadataURI);
    }
    
    function setUserReferralAs(address caller, address user, string memory referralCode) 
        internal 
        returns (uint256 tokenId, address kol) {
        vm.prank(caller);
        return referralRegistry.setUserReferral(user, referralCode);
    }
    
    function updateTVLAs(address caller, uint256 tokenId, uint256 newTVL) internal {
        vm.prank(caller);
        referralRegistry.updateTVL(tokenId, newTVL);
    }
    
    function expectRevertWithMessage(string memory message) internal {
        vm.expectRevert(bytes(message));
    }
    
    // Helper for OpenZeppelin v5 AccessControl errors
    function expectAccessControlError(address account, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, role));
    }
    
    // Helper for OpenZeppelin v5 Pausable errors
    function expectPausedError() internal {
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
    }
    
    // Helper for OpenZeppelin v5 ERC721 errors
    function expectInsufficientApprovalError(address operator, uint256 tokenId) internal {
        vm.expectRevert(abi.encodeWithSignature("ERC721InsufficientApproval(address,uint256)", operator, tokenId));
    }
    
    function expectNonexistentTokenError(uint256 tokenId) internal {
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", tokenId));
    }
} 