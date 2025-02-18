// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // we need to parse the token address to the contsructor
    // need to create a deposit function that mints tokens to the user equal to the amount ETH the user has sent
    // need to create a redeem function that burns tokens from the user and sends the user ETH
    // need to create a way to add rewards to the vault

    IRebaseToken private immutable i_rebaseToken;

    event Deposited(address indexed user, uint256 amount);
    event Redeemed(address indexed user, uint256 amount);

    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint Rebase tokens in return
     */
    function deposit() external payable {
        // 1. we need to use the amount of ETH the user has sent to mint the tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Allows users to redeem their Rebase tokens for ETH
     * @param _amount The amount of Rebase tokens to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }

        // CEI
        // 1. Burn the tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. Send the user ETH
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeemed(msg.sender, _amount);
    }

    /**
     * @notice Get the address of the Rebase token
     * @return The address of the Rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
