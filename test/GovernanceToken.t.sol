// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken public governanceToken;

    address public admin = address(1);
    address public minter = address(2);
    address public pauser = address(3);
    address public user = address(4);
    address public delegatee = address(5);
    address public attacker = address(6);

    uint256 public constant AMOUNT = 100 ether;

    function setUp() public {
        governanceToken = new GovernanceToken(admin);

        vm.startPrank(admin);
        governanceToken.grantRole(governanceToken.MINTER_ROLE(), minter);
        governanceToken.grantRole(governanceToken.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    function testConstructorSetsNameSymbolAndRoles() public view {
        assertEq(governanceToken.name(), "GoldVault Governance");
        assertEq(governanceToken.symbol(), "GVG");
        assertTrue(governanceToken.hasRole(governanceToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(governanceToken.hasRole(governanceToken.PAUSER_ROLE(), admin));
    }

    function testConstructorRevertsWithZeroAdmin() public {
        vm.expectRevert(GovernanceToken.ZeroAddress.selector);
        new GovernanceToken(address(0));
    }

    function testMinterCanMint() public {
        vm.prank(minter);
        governanceToken.mint(user, AMOUNT);

        assertEq(governanceToken.balanceOf(user), AMOUNT);
        assertEq(governanceToken.totalSupply(), AMOUNT);
    }

    function testNonMinterCannotMint() public {
        vm.prank(attacker);
        vm.expectRevert();
        governanceToken.mint(attacker, AMOUNT);
    }

    function testMintRevertsWithZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(GovernanceToken.ZeroAddress.selector);
        governanceToken.mint(address(0), AMOUNT);
    }

    function testMintRevertsWithZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(GovernanceToken.ZeroAmount.selector);
        governanceToken.mint(user, 0);
    }

    function testUserCanDelegateVotingPowerToSelf() public {
        vm.prank(minter);
        governanceToken.mint(user, AMOUNT);

        vm.prank(user);
        governanceToken.delegate(user);

        assertEq(governanceToken.delegates(user), user);
        assertEq(governanceToken.getVotes(user), AMOUNT);
    }

    function testUserCanDelegateVotingPowerToAnotherAddress() public {
        vm.prank(minter);
        governanceToken.mint(user, AMOUNT);

        vm.prank(user);
        governanceToken.delegate(delegatee);

        assertEq(governanceToken.delegates(user), delegatee);
        assertEq(governanceToken.getVotes(delegatee), AMOUNT);
    }

    function testVotingPowerMovesAfterTransfer() public {
        vm.prank(minter);
        governanceToken.mint(user, AMOUNT);

        vm.prank(user);
        governanceToken.delegate(user);

        vm.prank(user);
        governanceToken.transfer(delegatee, 40 ether);

        vm.prank(delegatee);
        governanceToken.delegate(delegatee);

        assertEq(governanceToken.getVotes(user), 60 ether);
        assertEq(governanceToken.getVotes(delegatee), 40 ether);
    }

    function testPauserCanPauseAndUnpause() public {
        vm.prank(pauser);
        governanceToken.pause();

        assertTrue(governanceToken.paused());

        vm.prank(pauser);
        governanceToken.unpause();

        assertFalse(governanceToken.paused());
    }

    function testNonPauserCannotPause() public {
        vm.prank(attacker);
        vm.expectRevert();
        governanceToken.pause();
    }

    function testTransferRevertsWhenPaused() public {
        vm.prank(minter);
        governanceToken.mint(user, AMOUNT);

        vm.prank(pauser);
        governanceToken.pause();

        vm.prank(user);
        vm.expectRevert();
        governanceToken.transfer(attacker, 1 ether);
    }

    function testMintRevertsWhenPaused() public {
        vm.prank(pauser);
        governanceToken.pause();

        vm.prank(minter);
        vm.expectRevert();
        governanceToken.mint(user, AMOUNT);
    }

    function testNonceStartsAtZero() public view {
        assertEq(governanceToken.nonces(user), 0);
    }
}
