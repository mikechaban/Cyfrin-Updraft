// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle) {}

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // if we're on local network -> deploy mocks, get local config
        // if we're on sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription /* or we can call the var subscriptionContract */ = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(
                config.vrfCoordinator
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
