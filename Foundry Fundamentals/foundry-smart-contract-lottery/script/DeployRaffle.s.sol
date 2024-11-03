// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle) {}

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // if we're on local network -> deploy mocks, get local config
        // if we're on sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast();
        Raffle raffle = new Raffle(config.entranceFee, config.interval, config.vrfCoordinator, config.gasLane, config.subscriptionId, config.callbackGasLimit);
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
