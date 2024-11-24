// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract MoodNFT is ERC721 {
    uint256 private s_tokenCounter;
    string private s_sadSVGImageURI;
    string private s_happySVGImageURI;

    enum Mood {
        HAPPY,
        SAD
    }

    mapping(uint256 => Mood) private s_tokenIDToMood;

    error MoodNFT__MoodNotDefined();

    constructor(
        string memory sadSVGImageURI,
        string memory happySVGImageURI
    ) ERC721("MoodNFT", "MN") {
        s_tokenCounter = 0;
        s_sadSVGImageURI = sadSVGImageURI;
        s_happySVGImageURI = happySVGImageURI;
    }

    function mintNFT() public {
        _safeMint(msg.sender, s_tokenCounter); // <- so that the msg.sender gets their tokenID

        s_tokenIDToMood[s_tokenCounter] = Mood.HAPPY;

        s_tokenCounter++;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(
        uint256 tokenID
    ) public view override returns (string memory) {
        string memory imageURI;
        if (s_tokenIDToMood[tokenID] == Mood.HAPPY) {
            imageURI = s_happySVGImageURI;
        } else if (s_tokenIDToMood[tokenID] == Mood.SAD) {
            imageURI = s_sadSVGImageURI;
        } else {
            revert MoodNFT__MoodNotDefined();
        }

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name(),
                                '", "description":"An NFT that reflects the mood of the owner", ',
                                '"attributes": [{"trait_type": "moodiness", "value": 100}], "image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
