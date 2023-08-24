//SPDX-License-Identifier: MIT
pragma solidity^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test,console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.sol";
import {Vm} from "lib/forge-std/src/Vm.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";


contract RaffleTest is Test{
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 private entranceFee;
    uint256 private interval;
    address private vrfCoordinator;
    bytes32 private gasLane;
    uint64 private subscriptionID;
    uint32 private callbackGasLimit;
    address private linkAddress;
    uint256 private deployerKey;

    address public PLAYER = makeAddr(("Player"));
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    
    function setUp() external{
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle,helperConfig) = deployRaffle.run();

         (entranceFee,interval,vrfCoordinator,gasLane,subscriptionID,callbackGasLimit,linkAddress,deployerKey) = helperConfig.activeNetworkConfig();
         
         vm.deal(PLAYER,STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
    function testRaffleRevertWhenYouDontPayEnough() public{
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value : entranceFee}();
        address playerRecorded = raffle.getPlayer(0); 
        assert(playerRecorded == PLAYER);  
    }
    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true,false,false,false,address(raffle));
        emit EnteredRaffle(PLAYER);
         raffle.enterRaffle{value : entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();    
    }
    function testCheckUpkeepReturnsFalseIfIthasNoBalance() public{
        
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        assert(!upkeepNeeded);
    }
    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        assert(upkeepNeeded == false);
    }
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public{
        vm.prank(PLAYER);
        vm.warp(block.timestamp);
        raffle.enterRaffle{value: entranceFee}();
        vm.roll(block.number + 1);
    
        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        assert(upkeepNeeded == false);
    }
    function testCheckUpkeepReturnsTrueWhenParamatersAreGood() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpKeep("");
        assert(upkeepNeeded);
    }
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public{
        //Arrange 
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        //Act / Assert
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle_UpkeepNotNeeded.selector,currentBalance,numPlayers,raffleState));
        raffle.performUpkeep("");
    }
     
    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value:entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    // What if i need to test using the output of an event ?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestID() public raffleEnteredAndTimePassed
    { 
        
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestID = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(requestID) > 0);
        assert(uint256(raffleState) == 1);
    }
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEnteredAndTimePassed {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){

            address players = address(uint160(i));
            hoax(players, STARTING_USER_BALANCE);
            raffle.enterRaffle{value : entranceFee}();
        }
        uint256 prize = entranceFee * (additionalEntrants + 1);

        //Pretend to be chainlink vrf to get random number & pick winner
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestID = entries[1].topics[1];
        
        uint256 previousTimestamp = raffle.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(uint256(requestID), address(raffle));

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthPlayerArray() == 0);
        assert(previousTimestamp < raffle.getLastTimestamp());
        assert(raffle.getRecentWinner().balance == prize + STARTING_USER_BALANCE - entranceFee);
    }
}
