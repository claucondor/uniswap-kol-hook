// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library HookMiner {
    // Hook flags for ReferralHook
    uint160 constant FLAG_BEFORE_ADD_LIQUIDITY = 1 << 5;
    uint160 constant FLAG_AFTER_ADD_LIQUIDITY = 1 << 6;
    uint160 constant FLAG_BEFORE_REMOVE_LIQUIDITY = 1 << 7;
    uint160 constant FLAG_AFTER_REMOVE_LIQUIDITY = 1 << 8;
    
    uint160 constant REFERRAL_HOOK_FLAGS = 
        FLAG_BEFORE_ADD_LIQUIDITY |
        FLAG_AFTER_ADD_LIQUIDITY |
        FLAG_BEFORE_REMOVE_LIQUIDITY |
        FLAG_AFTER_REMOVE_LIQUIDITY;
    
    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) external view returns (address, bytes32) {
        address hookAddress;
        bytes32 salt;
        
        for (uint256 i = 0; i < 100000; i++) {
            salt = keccak256(abi.encodePacked(i));
            hookAddress = computeAddress(deployer, salt, creationCode, constructorArgs);
            
            if (uint160(hookAddress) & (2 ** 19 - 1) == flags) {
                return (hookAddress, salt);
            }
        }
        
        revert("HookMiner: could not find hook address");
    }
    
    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) public pure returns (address) {
        return address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            deployer,
                            salt,
                            keccak256(abi.encodePacked(creationCode, constructorArgs))
                        )
                    )
                )
            )
        );
    }
} 