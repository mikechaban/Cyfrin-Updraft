// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "../lib/forge-std/src/Script.sol";
import {MoodNFT} from "../src/MoodNFT.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployMoodNFT is Script {
    function run() external returns (MoodNFT) {
        string memory sadSVG = vm.readFile("./images/sad.svg");
        string memory happySVG = vm.readFile("./images/happy.svg");

        vm.startBroadcast();
        MoodNFT moodNFT = new MoodNFT(SVGtoImageURI(sadSVG), SVGtoImageURI(happySVG));
        vm.stopBroadcast();
        return moodNFT;
    }

    function SVGtoImageURI(string memory svg) public pure returns (string memory) {
        string memory baseURI = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));

        return string(abi.encodePacked(baseURI, svgBase64Encoded));
    }
}
