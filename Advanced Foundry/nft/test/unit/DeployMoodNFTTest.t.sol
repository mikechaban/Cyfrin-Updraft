// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DeployMoodNFT} from "../../script/DeployMoodNFT.s.sol";

contract DeployMoodNFTTest is Test {
    DeployMoodNFT public deployer;

    function setUp() public {
        deployer = new DeployMoodNFT();
    }

    function testConvertSVGtoImageURI() public view {
        string memory expectedURI = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHhtbG5zOnhsaW5rPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5L3hsaW5rIiB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCI+PHRleHQgeD0iMCIgeT0iMTUiIGZpbGw9ImJsYWNrIj5oaSB1ciBicm93c2VyIGRlY29kZWQgdGhpczwvdGV4dD48L3N2Zz4=";
        string memory svg = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="500" height="500"><text x="0" y="15" fill="black">hi ur browser decoded this</text></svg>';

        string memory actualURI = deployer.SVGtoImageURI(svg);

        assert(keccak256(abi.encodePacked(actualURI)) == keccak256(abi.encodePacked(expectedURI))); // <- first you make it packed byte array with abi.encodePacked() and then turn it into bytes32 hash with keccak256()
    }
}
