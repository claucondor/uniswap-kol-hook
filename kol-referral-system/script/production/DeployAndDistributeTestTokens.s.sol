// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TestToken18} from "../../contracts/mocks/TestToken18.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployAndDistributeTestTokens is Script {
    // --- Configuration ---
    string private constant TOKEN1_NAME = "KOL Test Token 1";
    string private constant TOKEN1_SYMBOL = "KOLTEST1";
    string private constant TOKEN2_NAME = "KOL Test Token 2";
    string private constant TOKEN2_SYMBOL = "KOLTEST2";
    uint256 private constant INITIAL_SUPPLY_UNITS = 1_000_000_000; // 1 Billion tokens
    uint256 private constant DECIMALS = 18;
    address private constant RECIPIENT_ADDRESS = 0xc5c5A0220c1AbFCfA26eEc68e55d9b689193d6b2;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING & DISTRIBUTING TEST TOKENS ===");
        console.log("Deployer/Admin Account:", deployerAddress);
        console.log("Recipient Address for Distribution:", RECIPIENT_ADDRESS);
        console.log("Network:", vm.toString(block.chainid));

        uint256 actualInitialSupply = INITIAL_SUPPLY_UNITS * (10**DECIMALS);
        console.log("Calculated Initial Supply (with decimals) per token:", actualInitialSupply);

        vm.startBroadcast(deployerPrivateKey);

        // --- Deploy Token 1 (KOLTEST1) ---
        console.log("Deploying Token 1 (%s - %s)...", TOKEN1_NAME, TOKEN1_SYMBOL);
        TestToken18 token1 = new TestToken18(TOKEN1_NAME, TOKEN1_SYMBOL, actualInitialSupply);
        console.log("Token 1 (KOLTEST1) deployed at:", address(token1));

        // --- Deploy Token 2 (KOLTEST2) ---
        console.log("Deploying Token 2 (%s - %s)...", TOKEN2_NAME, TOKEN2_SYMBOL);
        TestToken18 token2 = new TestToken18(TOKEN2_NAME, TOKEN2_SYMBOL, actualInitialSupply);
        console.log("Token 2 (KOLTEST2) deployed at:", address(token2));

        // --- Distribute Token 1 ---
        uint256 token1TotalSupply = token1.totalSupply();
        uint256 token1AmountToSend = token1TotalSupply / 2;
        console.log("KOLTEST1 Total Supply:", token1TotalSupply);
        console.log("Attempting to send %s KOLTEST1 to %s...", token1AmountToSend, RECIPIENT_ADDRESS);
        bool success1 = token1.transfer(RECIPIENT_ADDRESS, token1AmountToSend);
        require(success1, "Transfer of KOLTEST1 failed");
        console.log("Successfully sent %s KOLTEST1 to recipient.", token1AmountToSend);

        // --- Distribute Token 2 ---
        uint256 token2TotalSupply = token2.totalSupply();
        uint256 token2AmountToSend = token2TotalSupply / 2;
        console.log("KOLTEST2 Total Supply:", token2TotalSupply);
        console.log("Attempting to send %s KOLTEST2 to %s...", token2AmountToSend, RECIPIENT_ADDRESS);
        bool success2 = token2.transfer(RECIPIENT_ADDRESS, token2AmountToSend);
        require(success2, "Transfer of KOLTEST2 failed");
        console.log("Successfully sent %s KOLTEST2 to recipient.", token2AmountToSend);

        vm.stopBroadcast();

        console.log("=== DEPLOYMENT & DISTRIBUTION COMPLETE ===");

        // --- Verification of Balances ---
        console.log("Verifying balances...");
        uint256 recipientToken1Balance = IERC20(address(token1)).balanceOf(RECIPIENT_ADDRESS);
        console.log("Recipient's KOLTEST1 balance:", recipientToken1Balance);
        require(recipientToken1Balance == token1AmountToSend, "Recipient KOLTEST1 balance mismatch");

        uint256 deployerToken1Balance = IERC20(address(token1)).balanceOf(deployerAddress);
        console.log("Deployer's KOLTEST1 balance:", deployerToken1Balance);
        require(deployerToken1Balance == (token1TotalSupply - token1AmountToSend), "Deployer KOLTEST1 balance mismatch");

        uint256 recipientToken2Balance = IERC20(address(token2)).balanceOf(RECIPIENT_ADDRESS);
        console.log("Recipient's KOLTEST2 balance:", recipientToken2Balance);
        require(recipientToken2Balance == token2AmountToSend, "Recipient KOLTEST2 balance mismatch");

        uint256 deployerToken2Balance = IERC20(address(token2)).balanceOf(deployerAddress);
        console.log("Deployer's KOLTEST2 balance:", deployerToken2Balance);
        require(deployerToken2Balance == (token2TotalSupply - token2AmountToSend), "Deployer KOLTEST2 balance mismatch");

        console.log("All tokens deployed, distributed, and balances verified successfully!");

        // --- Save deployment info (optional, commented out for now) ---
        // string memory deploymentInfo = string.concat(
        //     "Token1 (KOLTEST1) deployed at: ", vm.toString(address(token1)), "\n",
        //     "Token2 (KOLTEST2) deployed at: ", vm.toString(address(token2)), "\n",
        //     "Distributed to: ", vm.toString(RECIPIENT_ADDRESS), "\n",
        //     "Amount KOLTEST1 sent: ", vm.toString(token1AmountToSend), "\n",
        //     "Amount KOLTEST2 sent: ", vm.toString(token2AmountToSend), "\n"
        // );
        // vm.writeFile("deployment_test_tokens.txt", deploymentInfo);
        // console.log("Deployment info would be saved to: deployment_test_tokens.txt");
    }
} 