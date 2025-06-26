// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ReferralRegistry.base.t.sol";

contract ReferralRegistryDeploymentTest is ReferralRegistryBase {
    function test_deployment_shouldSetCorrectName() public {
        assertEq(referralRegistry.name(), "KOL Referral NFT");
    }
    
    function test_deployment_shouldSetCorrectSymbol() public {
        assertEq(referralRegistry.symbol(), "KOLREF");
    }
    
    function test_deployment_shouldGrantAdminRoleToDeployer() public {
        assertTrue(referralRegistry.hasRole(referralRegistry.DEFAULT_ADMIN_ROLE(), admin));
    }
    
    function test_deployment_shouldGrantMinterRoleToDeployer() public {
        assertTrue(referralRegistry.hasRole(referralRegistry.MINTER_ROLE(), admin));
    }
    
    function test_deployment_shouldGrantPauserRoleToDeployer() public {
        assertTrue(referralRegistry.hasRole(referralRegistry.PAUSER_ROLE(), admin));
    }
    
    function test_deployment_shouldGrantUpdaterRoleToDeployer() public {
        assertTrue(referralRegistry.hasRole(referralRegistry.UPDATER_ROLE(), admin));
    }
    
    function test_deployment_shouldStartUnpaused() public {
        assertFalse(referralRegistry.paused());
    }
    
    function test_deployment_shouldHaveZeroTotalSupply() public {
        assertEq(referralRegistry.totalSupply(), 0);
    }
    
    function test_deployment_shouldSupportERC721Interface() public {
        assertTrue(referralRegistry.supportsInterface(0x80ac58cd)); // ERC721
    }
    
    function test_deployment_shouldSupportERC721EnumerableInterface() public {
        assertTrue(referralRegistry.supportsInterface(0x780e9d63)); // ERC721Enumerable
    }
    
    function test_deployment_shouldSupportAccessControlInterface() public {
        assertTrue(referralRegistry.supportsInterface(0x7965db0b)); // AccessControl
    }
    
    function test_roles_shouldHaveCorrectRoleBytes() public {
        assertEq(referralRegistry.MINTER_ROLE(), keccak256("MINTER_ROLE"));
        assertEq(referralRegistry.PAUSER_ROLE(), keccak256("PAUSER_ROLE"));
        assertEq(referralRegistry.UPDATER_ROLE(), keccak256("UPDATER_ROLE"));
    }
} 