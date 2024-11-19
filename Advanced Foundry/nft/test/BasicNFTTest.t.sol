// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployBasicNFT} from "../script/DeployBasicNFT.s.sol";
import {BasicNFT} from "../src/BasicNFT.sol";

contract DeployBasicNFTTest is Test {
    DeployBasicNFT public deployer;
    BasicNFT public basicNFT;
    address public USER = makeAddr("user");
    string public constant DOG =
        "ipfs://QmaQQdaRrLWDtD1zdxzzspJ1kihWknvk8GZSPa2ueUjqVJ";

    function setUp() public {
        deployer = new DeployBasicNFT();
        basicNFT = deployer.run();
    }

    function testNameIsCorrect() public view {
        string memory expectedName = "Doggy:P";
        string memory actualName = basicNFT.name();
        // assert(expectedName == actualName);
        assert(
            keccak256(abi.encodePacked(expectedName)) ==
                keccak256(abi.encodePacked(actualName))
        );
    }

    function testCanMintAndHaveABalance() public {
        vm.prank(USER);
        basicNFT.mintNFT(DOG);

        assert(basicNFT.balanceOf(USER) == 1);
        assert(
            keccak256(abi.encodePacked(DOG)) ==
                keccak256(abi.encodePacked(basicNFT.tokenURI(0)))
        );
    }
}
