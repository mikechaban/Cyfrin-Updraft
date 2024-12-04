// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {BasicNFT} from "../src/BasicNFT.sol";
import {MoodNFT} from "../src/MoodNFT.sol";

contract MintBasicNFT is Script {
    string public constant DOG = "ipfs://QmaQQdaRrLWDtD1zdxzzspJ1kihWknvk8GZSPa2ueUjqVJ";

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("BasicNFT", block.chainid);
        mintNFTOnContract(mostRecentlyDeployed);
    }

    function mintNFTOnContract(address contractAddress) public {
        vm.startBroadcast();
        BasicNFT(contractAddress).mintNFT(DOG);
        vm.stopBroadcast();
    }
}

contract MintMoodNFT is Script {
    function run() external {
        address mostRecentlyDeployedMoodNFT = DevOpsTools.get_most_recent_deployment("MoodNFT", block.chainid);
        mintNFTOnContract(mostRecentlyDeployedMoodNFT);
    }

    function mintNFTOnContract(address moodNFTAddress) public {
        vm.startBroadcast();
        MoodNFT(moodNFTAddress).mintNFT();
        vm.stopBroadcast();
    }
}

contract FlipMoodNFT is Script {
    uint256 public constant TOKEN_ID_TO_FLIP = 0;

    function run() external {
        address mostRecentlyDeployedMoodNFT = DevOpsTools.get_most_recent_deployment("MoodNFT", block.chainid);
        flipMoodOnContract(mostRecentlyDeployedMoodNFT);
    }

    function flipMoodOnContract(address moodNFTAddress) public {
        vm.startBroadcast();
        MoodNFT(moodNFTAddress).flipMood(TOKEN_ID_TO_FLIP);
        vm.stopBroadcast();
    }
}
