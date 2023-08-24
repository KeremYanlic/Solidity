// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions


//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script,console} from "lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";
/**
 * @title A sample Raffle contract
 * @author Me
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */

contract Raffle is VRFConsumerBaseV2  {
   
   error Raffle_NotEnoughEthSent();
   error Raffle_TransferFailed();
   error Raffle_RaffleNotOpen();
   error Raffle_UpkeepNotNeeded(uint256 currentBalance,uint256 numPlayers,uint256 raffleState);

   enum RaffleState{
    OPEN, //0
    CALCULATING //1
   }

   uint16 private constant REQUEST_CONFIRMATIONS = 3;
   uint32 private constant NUM_WORDS = 1;

   uint256 private immutable i_entranceFee;
   uint256 private immutable i_interval; //Duration of the lottery in seconds
   VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
   bytes32 private immutable i_gasLane;
   uint64 private immutable i_subscriptionID;
   uint32 private immutable i_callBackGasLimit;
   address payable[] private s_players;
   uint256 private s_lastTimeStamp;
   address private s_recentWinnerAddress;
   RaffleState private s_raffleState;
   
   //** Events */
   event EnteredRaffle(address indexed player);
   event WinnerPicked(address indexed winner);
   event RequestedRaffleWinner(uint256 indexed requestID);

   constructor(uint256 entranceFee,uint256 interval,address vrfCoordinator,bytes32 gasLane,uint64 subscriptionID,uint32 callBackGasLimit) VRFConsumerBaseV2(vrfCoordinator) {
     
      i_entranceFee = entranceFee;
      i_interval = interval;
      i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
      i_gasLane = gasLane;
      i_subscriptionID = subscriptionID;
      i_callBackGasLimit = callBackGasLimit;
      s_lastTimeStamp = block.timestamp;

      s_raffleState = RaffleState.OPEN;
   }

   //<summary>
   //<All the competitors must enter raffle if they want to be chosen by random. The only way to enter raffle is paying a price. Thats why we add payable key.
   //</summary>
   function enterRaffle() public payable{

     if(msg.value < i_entranceFee)
     {
        revert Raffle_NotEnoughEthSent();
     }
     if(s_raffleState != RaffleState.OPEN){
        revert Raffle_RaffleNotOpen();
     }
     s_players.push(payable(msg.sender));

     emit EnteredRaffle(msg.sender);
  }

 
  //When is the winner supposed to be picked ?
  /**
   * @dev This is the function that the Chainlink Automation nodes call
   * to see if it's time to perform an upkeep.
   * The following should be true for this to return true.
   * 1. The time interval has passed between raffle runs
   * 2. The raffle is in the OPEN state
   * 3. The contract has ETH(aka,players)
   * 4. (Implicit) The subscription is funded with LINK
   */
  function checkUpKeep(bytes memory /*callData*/) public view returns(bool upkeepNeeded,bytes memory performData){
    bool hasTimePassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
    bool isOpen = s_raffleState == RaffleState.OPEN;
    bool hasBalance = address(this).balance > 0;
    bool hasPlayers = s_players.length > 0;

    upkeepNeeded = (hasTimePassed && isOpen && hasBalance && hasPlayers);
    return (upkeepNeeded,"0x0");
  }

  // 1. Get a random number
  // 2. Use the random number to pick a player
  // 3.Be automatically called
  function performUpkeep(bytes calldata /* performData */) external{
    (bool upkeepNeeded,) = checkUpKeep("");
    if(!upkeepNeeded){
      revert Raffle_UpkeepNotNeeded(address(this).balance,s_players.length,uint256(s_raffleState));
    }


    s_raffleState = RaffleState.CALCULATING; 
    uint256 requestID = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionID,
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUM_WORDS);
     
    
     emit RequestedRaffleWinner(requestID);
  }
  function fulfillRandomWords(uint256 /*_requestId*/,uint256[] memory _randomWords) internal override{
    uint256 randomWinnerIndex = _randomWords[0] % s_players.length;
    address payable winnerAddress = s_players[randomWinnerIndex];
    s_recentWinnerAddress = winnerAddress;

    s_raffleState = RaffleState.OPEN;
    s_players = new address payable[](0);
    s_lastTimeStamp = block.timestamp;

    //Pay to the winner address
    (bool success,) = winnerAddress.call{value: address(this).balance}("");
    if(!success){
      revert Raffle_TransferFailed();
    }

    emit WinnerPicked(winnerAddress);
  }


  // *** Getter Functions */

  //Get the entrance fee amount
  function getEntranceFee() public view returns (uint256){
    return i_entranceFee;
  }

  function getRaffleState() external view returns (RaffleState){
    return s_raffleState;
  }
  function getPlayer(uint256 playerIndex) external view returns (address){
    return s_players[playerIndex];
  }
  function getLengthPlayerArray() external view returns(uint256){
    return s_players.length;
  }
  function getRecentWinner() external view returns (address){
    return s_recentWinnerAddress;
  }
  function getLastTimestamp() external view returns (uint256){
    return s_lastTimeStamp;
  }
}