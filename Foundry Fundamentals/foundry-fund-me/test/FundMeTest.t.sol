// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 1 ether;
    // uint256 constant GAS_PRICE = 1;

    address USER = makeAddr("user");

    // ^of type | ^variable

    function setUp() external {
        // Every time we run a test, it will first run the setup, and then run the selected test (if we do --match-test)

        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // means the next line should revert
        // assert(This tx fails/reverts
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); // Means the next TX will be sent by user

        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testAddsFunderToArrayOfFunders() public /* modifier: */ funded {
        // we have a modifier so now we don't have to do:
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public /* modifier: */ funded {
        // we have a modifier so now we don't have to do:
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // ARRANGE
        // ACT
        // ASSERT

        // Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance; // can't do fundMe.balance;

        // Act
        vm.prank(fundMe.getOwner()); // Sets the msg.sender to the owner of the fundMe contract for the next transaction
        fundMe.withdraw();

        // Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance // + endingFundMeBalance
        );
    }

    function testWithdrawWithMultipleFunders() public funded {
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1; // when doing tests make sure you're not sending stuff to 0th address cause it reverts sometimes

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // we're gonna do
            // vm.prank new address
            // vm.deal some money
            // and they're going to fund the fundMe

            // but forge std lib has "hoax" cheatcode (sets up a prank from an address that has some ether) <- this does both Prank and Deal combined

            // we do uint160 for address since it has the same number of bytes

            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        // vm.prank(address): Use this for a single function call where you want to impersonate a specific address.
        // vm.startPrank(address) / vm.stopPrank(): Use this for multiple function calls where you want to impersonate the same address over a series of interactions.

        // Act
        
        // uint256 gasStart = gasleft();
        // vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = (gasStart - gasEnd) * tx.gasprice;
        // console.log(gasUsed);

        // we can do as above or use startPrank and stopPrank:
        address testAddress = vm.addr(11);
        vm.startPrank(testAddress);
        vm.expectRevert();
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        assert(address(fundMe).balance == 0);
        // or we can do assertEq(address(fundMe).balance, 0);

        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            fundMe.getOwner().balance
        );
    }
}
