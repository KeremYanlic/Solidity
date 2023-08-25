//SPDX-License-Identifier: MIT
pragma solidity^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol"; 
import {OurToken} from "../src/OurToken.sol";
  

contract OurTokenTest is Test {
    
    OurToken public ourToken;
    DeployOurToken public deployOurToken;


    address _bob = makeAddr("bob");
    address _alice = makeAddr("alice");

      uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() external {

        deployOurToken = new DeployOurToken();
        ourToken = deployOurToken.run();

        vm.prank(msg.sender);
        ourToken.transfer(_bob, STARTING_BALANCE);
    }

    function testBobBalance() public{
        assert(ourToken.balanceOf(_bob) == STARTING_BALANCE);
    }

    function testAllowancesWorks() public {
        uint256 initialAllowance = 1000;

        vm.prank(_bob);
        ourToken.approve(_alice, initialAllowance);

        uint256 transferAmount = 500;
        vm.prank(_alice);
        ourToken.transferFrom(_bob, _alice, transferAmount);

        assertEq(ourToken.balanceOf(_alice),transferAmount);
        assertEq(ourToken.balanceOf(_bob),STARTING_BALANCE -transferAmount);
    }

}