// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

contract DeploySimpleStorage is Script {
    function run() external returns (SimpleStorage) {
        // Start sending real transactions
        vm.startBroadcast();

        SimpleStorage simpleStorage = new /* creates a new contract */ SimpleStorage();

        vm.stopBroadcast();
        // Stop sending real transactions
        return simpleStorage;
    }
}
