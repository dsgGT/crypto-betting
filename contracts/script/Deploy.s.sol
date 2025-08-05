// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import {WagerManager} from "../src/WagerManager.sol";

/// @notice Deploys a fresh WagerManager.
///         Reads your deployer key from the env variable `PRIVATE_KEY`.
contract Deploy is Script {
    function run() external {
        // 1. grab private key
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // 2. every tx after this line is signed with `pk`
        vm.startBroadcast(pk);

        // 3. deploy the contract
        new WagerManager();

        // 4. stop broadcasting
        vm.stopBroadcast();
    }
}