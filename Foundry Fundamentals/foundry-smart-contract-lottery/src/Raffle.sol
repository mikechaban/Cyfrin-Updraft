// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

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
    error Raffle__TransferFailed();
    error Raffle__RaffleIsCalculating();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /* Type Declarations */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
        // ANOTHER_STATE // 2
    }

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // the declaration uint256 private immutable i_entranceFee; just creates the variable but doesn’t give it a value.
    uint256 private immutable i_interval;
    // @dev the duration of the lottery in seconds
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players; // <- this is the syntax for making an address array payable
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    // a constructor is a special function that runs only once when a smart contract is first deployed to the blockchain. It’s used to set up the contract’s initial state, like assigning values or initializing variables. After it’s executed, it can’t be called again.
    // in this case, the constructor is used to assign a value to that variable when the contract is deployed.
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit /* we also need to add the inherited contract's constructor: */
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        /* we now have the access to the s_vrfCoordinator variable from VRFConsumerBaseV2Plus */
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN; // same as RaffleState(0)
    }

    function enterRaffle() external payable {
        // Two checks:
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughETHSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleIsCalculating();
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

    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink nodes will call to see if the lottery is ready to ahev a winner picked.
     * The following should be true in order for upkeepNeeded to be true
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH (has players)
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignored
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool upkeepNeeded /* now this var is initialized, defaults to false */,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);

        bool isOpen = s_raffleState == RaffleState.OPEN;

        bool hasBalance = address(this).balance > 0;

        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    /* was pickWinner() */ function performUpkeep(bytes calldata /* performData */) external {
        // Checks
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS, // Number of Random numbers required
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        s_vrfCoordinator.requestRandomWords(request);
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] calldata randomWords
    )
        internal
        override
    /* we're overriding because in the imported contract the function is virtual, which means it's meant to be overriden (also means it's meant to be implemented in our contract) */ /* abstract contracts (like) VRFConsumerBaseV2Plus can have both undefined and defined functions. 'if you're going to import this contract, you need to define fulfillRandomWords" */ {
        // Checks
        // require() (conditionals)

        // Effects (Internal Contract State Changes)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;

        s_players = new address payable[](/* of size: */ 0);
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Interactions)
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
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
