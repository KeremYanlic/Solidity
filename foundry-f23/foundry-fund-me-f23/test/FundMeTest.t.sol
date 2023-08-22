//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Test,console} from "lib/forge-std/src/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test{
    
    FundMe fundMe;

    address tempAddress = makeAddr("tempAddress");
    
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    function setUp() external{
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();

        vm.deal(tempAddress,STARTING_BALANCE);
    }
    function testMinimumDollarIsFive() public{
        
        assertEq(fundMe.MINIMUM_USD(),5e18);
    }
    function testOwnerIsMsgSender() public{
        assertEq(fundMe.getOwner(),msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public{
      
        assertEq(fundMe.getVersion(),4);
    }
    function testFundFailsWithoutEnoughETH() public{
        vm.expectRevert(); //The next line should revert,

        fundMe.fund();
    }
    function testFundUpdatesFundedDataStructe() public funded(){
        uint256 amountFunded = fundMe.getAddressToAmountFunded(tempAddress);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public funded(){
        address funder = fundMe.getFunder(0);
        assertEq(funder, tempAddress);
    } 
    function testOnlyOwnerCanWithdraw() public funded(){
        vm.expectRevert();
        vm.prank(tempAddress);
        fundMe.withdraw();
    }
    function testWithDrawWithASingleFunder() public funded(){
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
       
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        
        //Assert 
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(startingOwnerBalance + startingFundMeBalance, endingOwnerBalance);
    }
    function testWithdrawFromMultipleFundersCheaper() public funded(){
        //Arrange
        uint160 numberOfFunders = 10; //If you want to work with addresses then use uint160 instead uint256
        uint160 startingFunderIndex = 1;

        for(uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            // vm.prank new address
            // vm.deal new address
            // hoax is the combine of vm.prank and vm.deal
            hoax(address(i),SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        console.log(startingOwnerBalance);
        uint256 startingFundMeBalance = address(fundMe).balance;
        console.log(startingFundMeBalance);
        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
    }


    function testWithdrawFromMultipleFunders() public funded(){
        //Arrange
        uint160 numberOfFunders = 10; //If you want to work with addresses then use uint160 instead uint256
        uint160 startingFunderIndex = 1;

        for(uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            // vm.prank new address
            // vm.deal new address
            // hoax is the combine of vm.prank and vm.deal
            hoax(address(i),SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        console.log(startingOwnerBalance);
        uint256 startingFundMeBalance = address(fundMe).balance;
        console.log(startingFundMeBalance);
        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner().balance);
    }


    modifier funded(){
        vm.prank(tempAddress); //The next TX will be sent by user
        fundMe.fund{value: SEND_VALUE}();
        _;
    }
}