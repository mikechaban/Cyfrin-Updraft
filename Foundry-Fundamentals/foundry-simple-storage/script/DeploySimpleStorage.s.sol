// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

contract DeploySimpleStorage is Script {
    function run() external returns (SimpleStorage) {
        vm.startBroadcast();
        // vm keyword exists in Foundry

        // any transaction that we wanna actually send we put here (inside the two cheatcodes)

        SimpleStorage simpleStorage = new /* creates a new contract */ SimpleStorage();

        vm.stopBroadcast();

        return simpleStorage;
    }
}
