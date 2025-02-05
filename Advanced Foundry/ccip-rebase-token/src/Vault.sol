// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Vault {
    // we need to parse the token address to the contsructor
    // need to create a deposit function that mints tokens to the user equal to the amount ETH the user has sent
    // need to create a redeem function that burns tokens from the user and sends the user ETH
    // need to create a way to add rewards to the vault

    address private immutable i_rebaseToken;

    constructor(address _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        // 1. we need to use the amount of ETH the user has sent to mint the tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);
    }

    function getRebaseTokenAddress() external view returns (address) {
        return i_rebaseToken;
    }
}
