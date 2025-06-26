// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TestToken18 - ERC20 token with 18 decimals for testing
/// @notice This token matches KOL token decimals to avoid decimal mismatch issues
contract TestToken18 is ERC20, Ownable {
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }
    
    /// @notice Mint tokens to a specific address (only owner)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    /// @notice Burn tokens from caller
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    /// @notice Get decimals (18 to match KOL token)
    function decimals() public pure override returns (uint8) {
        return 18;
    }
} 