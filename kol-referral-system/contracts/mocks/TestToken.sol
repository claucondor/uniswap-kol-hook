// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20, Ownable {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimalsValue,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _decimals = decimalsValue;
        _mint(msg.sender, initialSupply * 10**decimalsValue);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // Anyone can mint for testing (remove in production)
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    // Owner can mint
    function ownerMint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Faucet function - anyone can get 1000 tokens per call
    function faucet() external {
        _mint(msg.sender, 1000 * 10**_decimals);
    }

    // Burn function
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
} 