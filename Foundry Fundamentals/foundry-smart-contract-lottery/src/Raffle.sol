// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/dev/vrf/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Mike Chabanovskyi
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle_NotEnoughETHSent();
    error Raffle_NotEnoughTimePassed();

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_entranceFee;
    // the declaration uint256 private immutable i_entranceFee; just creates the variable but doesn’t give it a value.
    uint256 private immutable i_interval;
    // @dev the duration of the lottery in seconds
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    address payable[] private s_players; // <- this is the syntax for making an address array payable
    uint256 private s_lastTimeStamp;

    /* Events */
    event RaffleEntered(address indexed player);

    // a constructor is a special function that runs only once when a smart contract is first deployed to the blockchain. It’s used to set up the contract’s initial state, like assigning values or initializing variables. After it’s executed, it can’t be called again.
    // in this case, the constructor is used to assign a value to that variable when the contract is deployed.
    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subscriptionId) /* we also need to add the inherited contract's constructor: */ VRFConsumerBaseV2Plus(vrfCoordinator) {
        /* we now have the access to the s_vrfCoordinator variable from VRFConsumerBaseV2Plus */
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
    }

    function enterRaffle() external payable {
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

    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle_NotEnoughTimePassed();
        } // <- globally available unit like msg.sender or msg.value

        uint256 requestId = s_vrfCoordinator.requestRandomWords( // s_vrfCoordinator is going to be some type of coordinator smart contract, which has a function called requestRandomWords()
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {}

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
