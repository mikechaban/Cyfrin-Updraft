// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title A sample Raffle contract
 * @author Mike Chabanovskyi
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */

contract Raffle {
    /* Errors */
    error Raffle_NotEnoughETHSent();

    uint256 private immutable i_entranceFee;
    // the declaration uint256 private immutable i_entranceFee; just creates the variable but doesn’t give it a value.
    address payable[] private s_players; // <- this is the syntax for making an address array payable

    /* Events */
    event RaffleEntered(address indexed player);

    // a constructor is a special function that runs only once when a smart contract is first deployed to the blockchain. It’s used to set up the contract’s initial state, like assigning values or initializing variables. After it’s executed, it can’t be called again.
    // in this case, the constructor is used to assign a value to that variable when the contract is deployed.
    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughETHSent();
        }

        s_players.push(payable(msg.sender));
        // ^ whenever we update a storage var, we need to emit an event
        emit RaffleEntered(msg.sender);

        // Not available to use right now:
        // require(msg.value >= i_entranceFee, Raffle_NotEnoughETHSent());

        // gas-inefficient:
        // function enterRaffle() public payable {
        //     require(
        //         msg.value >= i_entranceFee,
        //         string(
        //             abi.encodePacked(
        //                 "Not enough ETH sent. A minimum of ",
        //                 uint2str(i_entranceFee),
        //                 " ETH is required."
        //             )
        //         )
        //     );
        // }
    }

    function pickWinner() public {}

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    // helper function to turn uint to string
    // function uint2str(uint _i) internal pure returns (string memory) {
    //     if (_i == 0) {
    //         return "0";
    //     }
    //     uint j = _i;
    //     uint len;
    //     while (j != 0) {
    //         len++;
    //         j /= 10;
    //     }
    //     bytes memory bstr = new bytes(len);
    //     uint k = len - 1;
    //     while (_i != 0) {
    //         bstr[k--] = bytes1(uint8(48 + (_i % 10)));
    //         _i /= 10;
    //     }
    //     return string(bstr);
    // }
}
