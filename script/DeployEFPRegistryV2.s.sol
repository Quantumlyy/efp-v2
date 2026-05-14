// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {EFPListRegistryV2} from "@efp/v2/EFPListRegistryV2.sol";

/// @notice Broadcasts a new {EFPListRegistryV2} with `msg.sender` as owner (adjust in fork tests as needed).
contract DeployEFPRegistryV2Script is Script {
    function run() external returns (EFPListRegistryV2 registry) {
        vm.startBroadcast();
        registry = new EFPListRegistryV2(msg.sender);
        vm.stopBroadcast();
    }
}
