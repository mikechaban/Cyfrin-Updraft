// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title RebaseToken
 * @author Mike Chabanovskyi
 * @notice This is a cross-chain rebase token that incentivizes users to deposit into a vault and gain interest in rewards
 * @notice The interest rate in the smart contract can only decrease
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */

contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 currentInterestRate,
        uint256 newInterestRate
    );

    uint256 private s_interestRate = 5e10;

    constructor() ERC20("Rebase Token", "RBT") {}

    function setInterestRate(
        uint256 _newInterestRate
    ) external /* onlyOwner */ {
        // Set the interest rate
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
    }
}
