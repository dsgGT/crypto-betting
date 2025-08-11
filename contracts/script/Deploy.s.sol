// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {WagerManager} from "../src/WagerManager.sol";

/// @notice Deploys a fresh WagerManager.
///         Reads your deployer key from the env variable `PRIVATE_KEY`.
contract Deploy is Script {
    function run() external {
        // 1. start broadcast (will use private key from command line)
        vm.startBroadcast();

        // 3. deploy the contract
        new WagerManager();

        // 4. stop broadcasting
        vm.stopBroadcast();
    }
}