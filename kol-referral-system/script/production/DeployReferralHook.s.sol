// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ReferralHook} from "../../contracts/hooks/ReferralHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IReferralRegistry} from "../../contracts/interfaces/IReferralRegistry.sol";
import {ITVLLeaderboard} from "../../contracts/interfaces/ITVLLeaderboard.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

contract DeployReferralHook is Script {
    // --- Standard CREATE2 Deployer Address ---
    address private constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    // --- Immutable Mainnet Addresses for Constructor ---
    IPoolManager private constant POOL_MANAGER = IPoolManager(0x498581fF718922c3f8e6A244956aF099B2652b2b);
    IReferralRegistry private constant REFERRAL_REGISTRY = IReferralRegistry(0x9E895E8DA3fF34C7B73D9Ad94d9E562c2D4Dc01e);
    ITVLLeaderboard private constant TVL_LEADERBOARD = ITVLLeaderboard(0xBf133a716f07FF6a9C93e60EF3781EA491390688);

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== DEPLOYING REFERRAL HOOK VIA CREATE2 ===");
        console.log("Deployer Account (EOA):", vm.addr(deployerPrivateKey));
        console.log("Actual Deployer (CREATE2 Factory):", CREATE2_DEPLOYER);
        console.log("Network:", vm.toString(block.chainid));
        console.log("Using PoolManager:", address(POOL_MANAGER));
        console.log("Using ReferralRegistry:", address(REFERRAL_REGISTRY));
        console.log("Using TVLLeaderboard:", address(TVL_LEADERBOARD));

        // Define the required hook flags
        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG |
            Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );
        console.log("Required Flags (uint160 raw):", uint256(flags));
        console.log("Flags for HookMiner prepared.");

        // Encode constructor arguments for ReferralHook
        bytes memory constructorArgs = abi.encode(
            POOL_MANAGER,
            REFERRAL_REGISTRY,
            TVL_LEADERBOARD
        );
        console.log("Constructor arguments (ABI encoded):");
        console.logBytes(constructorArgs);

        // Mine the salt and predict the hook address
        (address predictedHookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(ReferralHook).creationCode,
            constructorArgs
        );

        console.log("Salt mined:", vm.toString(salt));
        console.log("Predicted Hook Address:", predictedHookAddress);

        // Deploy the hook using CREATE2
        ReferralHook referralHook;
        if (predictedHookAddress.code.length == 0) {
            console.log("Deploying contract using CREATE2 factory...");
            bytes memory deploymentCode = abi.encodePacked(type(ReferralHook).creationCode, constructorArgs);
            (bool success, ) = CREATE2_DEPLOYER.call(abi.encodePacked(salt, deploymentCode));
            require(success, "CREATE2 deployment call failed");
            referralHook = ReferralHook(payable(predictedHookAddress));
            console.log("Deployment via raw CREATE2 call successful.");
        } else {
            console.log("Contract already deployed at predicted address or CREATE2_DEPLOYER interaction failed previously.");
            referralHook = ReferralHook(payable(predictedHookAddress));
        }

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT COMPLETE ===");
        require(address(referralHook) == predictedHookAddress, "Hook address mismatch: deployed vs predicted");
        console.log("ReferralHook deployed at:", address(referralHook));
        console.log("Actual mined address matches deployed address.");

        console.log("Verifying Constructor Arguments on deployed hook:");
        require(address(referralHook.poolManager()) == address(POOL_MANAGER), "PoolManager address mismatch");
        console.log("  PoolManager OK:", address(referralHook.poolManager()));
        require(address(referralHook.referralRegistry()) == address(REFERRAL_REGISTRY), "ReferralRegistry address mismatch");
        console.log("  ReferralRegistry OK:", address(referralHook.referralRegistry()));
        require(address(referralHook.tvlLeaderboard()) == address(TVL_LEADERBOARD), "TVLLeaderboard address mismatch");
        console.log("  TVLLeaderboard OK:", address(referralHook.tvlLeaderboard()));
        console.log("Constructor arguments verified successfully.");

        // --- Commented out file writing ---
        // console.log("Deployment info would be saved to: deployment_referral_hook.txt");
    }
} 