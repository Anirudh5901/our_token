//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "../lib/forge-std/src/Test.sol";
import {DeployOurToken} from "../script/DeployOurToken.s.sol";
import {OurToken} from "../src/OurToken.sol";

contract OurTokenTest is Test {
    event Transfer(address sender, address receiver, uint256 amount);
    event Approval(address approver, address receiver, uint256 allowance);

    OurToken public ourToken;
    DeployOurToken public deployer;

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");
    address charlie = makeAddr("charlie");

    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() public {
        deployer = new DeployOurToken();
        ourToken = deployer.run();

        vm.prank(msg.sender);
        ourToken.transfer(bob, STARTING_BALANCE);
    }

    // Initial state tests
    function testInitialSupply() public view {
        assertEq(ourToken.totalSupply(), deployer.INITIAL_SUPPLY());
    }

    function testBobBalance() public view {
        assertEq(STARTING_BALANCE, ourToken.balanceOf(bob));
    }

    function testTokenMetadata() public view {
        assertEq(ourToken.name(), "Our Token");
        assertEq(ourToken.symbol(), "OT");
        assertEq(ourToken.decimals(), 18);
    }

    // Transfer tests
    function testTransfer() public {
        uint256 transferAmount = 50 ether;

        vm.prank(bob);
        ourToken.transfer(alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
    }

    function testTransferFailsIfNotEnoughBalance() public {
        uint256 transferAmount = STARTING_BALANCE + 1 ether;

        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(alice, transferAmount);
    }

    function testTransferToZeroAddressFails() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.transfer(address(0), 1 ether);
    }

    // Allowance tests
    function testAllowanceWorks() public {
        uint256 initialAllowance = 1000;
        uint256 transferAmount = 500;

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, transferAmount);

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.allowance(bob, alice), initialAllowance - transferAmount);
    }

    function testApprove() public {
        uint256 allowanceAmount = 500;

        vm.prank(bob);
        ourToken.approve(alice, allowanceAmount);

        assertEq(ourToken.allowance(bob, alice), allowanceAmount);
    }

    function testTransferFromFailsIfNotApproved() public {
        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, 1 ether);
    }

    function testTransferFromFailsIfNotEnoughAllowance() public {
        uint256 initialAllowance = 1000;
        uint256 transferAmount = 1001;

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, transferAmount);
    }

    function testTransferFromFailsIfNotEnoughBalance() public {
        uint256 initialAllowance = type(uint256).max;

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, STARTING_BALANCE + 1);
    }

    function testAllowanceNotSpentIfTransferFails() public {
        uint256 initialAllowance = 1000;
        uint256 transferAmount = STARTING_BALANCE + 1; // Will fail

        vm.prank(bob);
        ourToken.approve(alice, initialAllowance);

        vm.prank(alice);
        vm.expectRevert();
        ourToken.transferFrom(bob, alice, transferAmount);

        // Allowance should remain unchanged
        assertEq(ourToken.allowance(bob, alice), initialAllowance);
    }

    // Edge cases
    function testTransferZeroAmount() public {
        vm.prank(bob);
        ourToken.transfer(alice, 0);

        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
        assertEq(ourToken.balanceOf(alice), 0);
    }

    function testApproveZeroAddress() public {
        vm.prank(bob);
        vm.expectRevert();
        ourToken.approve(address(0), 1000);
    }

    function testTransferFromZeroAmount() public {
        vm.prank(bob);
        ourToken.approve(alice, 1000);

        vm.prank(alice);
        ourToken.transferFrom(bob, alice, 0);

        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE);
        assertEq(ourToken.balanceOf(alice), 0);
        assertEq(ourToken.allowance(bob, alice), 1000);
    }

    // Approval race condition test
    function testApprovalRaceCondition() public {
        uint256 firstAllowance = 100;
        uint256 secondAllowance = 200;

        vm.prank(bob);
        ourToken.approve(alice, firstAllowance);
        assertEq(ourToken.allowance(bob, alice), firstAllowance);

        vm.prank(bob);
        ourToken.approve(alice, secondAllowance);
        assertEq(ourToken.allowance(bob, alice), secondAllowance);
    }

    // Test for transfer and approval in same transaction
    function testTransferAndApprovalInSameTx() public {
        uint256 transferAmount = 10 ether;
        uint256 approveAmount = 5 ether;

        vm.startPrank(bob);
        ourToken.transfer(alice, transferAmount);
        ourToken.approve(charlie, approveAmount);
        vm.stopPrank();

        assertEq(ourToken.balanceOf(alice), transferAmount);
        assertEq(ourToken.balanceOf(bob), STARTING_BALANCE - transferAmount);
        assertEq(ourToken.allowance(bob, charlie), approveAmount);
    }
}
