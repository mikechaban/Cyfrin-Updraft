// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle) {
        return deployRaffle();
    }

    function deployRaffle() public returns (Raffle, HelperConfig) {}
}
