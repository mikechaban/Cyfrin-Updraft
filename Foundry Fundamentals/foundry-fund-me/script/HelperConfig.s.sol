// 1. Deploy mocks when we are on a local anvil chain
// 2. Keep track of contract address across different chains

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8; // <- magic number
    int256 public constant INITIAL_PRICE = 2000e8; // <- magic number

    // struct keyword is used to create a type
    struct NetworkConfig {
        // <- new object of type NetworkConfig
        address priceFeed; // ETH/USD price feed address
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        pure
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        NetworkConfig memory sepoliaNetworkConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306 // ETH / USD
        });
        return sepoliaNetworkConfig;
    }

    function getAnvilEthConfig()
        public
        returns (
            /* (can't be pure because we modify the state of the blockchain) */
            NetworkConfig memory
        )
    {
        // 1. Deploy the mocks
        // 2. Return the mock address

        vm.startBroadcast();

        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS, // <- magic number
            INITIAL_PRICE // <- magic number
        );

        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed)
        });
        return anvilConfig;
    }
}
