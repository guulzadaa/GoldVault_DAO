// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldToken} from "../src/GoldToken.sol";

contract GoldTokenTest is Test {
    GoldToken public goldToken;

    address public admin = address(1);
    address public issuer = address(2);
    address public pauser = address(3);
    address public user = address(4);
    address public attacker = address(5);

    uint256 public constant AMOUNT = 100 ether;

    function setUp() public {
        goldToken = new GoldToken(admin);

        vm.startPrank(admin);
        goldToken.grantRole(goldToken.ISSUER_ROLE(), issuer);
        goldToken.grantRole(goldToken.PAUSER_ROLE(), pauser);
        vm.stopPrank();
    }

    function testConstructorSetsNameSymbolAndRoles() public view {
        assertEq(goldToken.name(), "GoldVault Token");
        assertEq(goldToken.symbol(), "GOLD");
        assertTrue(goldToken.hasRole(goldToken.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(goldToken.hasRole(goldToken.PAUSER_ROLE(), admin));
    }

    function testConstructorRevertsWithZeroAdmin() public {
        vm.expectRevert(GoldToken.ZeroAddress.selector);
        new GoldToken(address(0));
    }

    function testIssuerCanMint() public {
        vm.prank(issuer);
        goldToken.mint(user, AMOUNT);

        assertEq(goldToken.balanceOf(user), AMOUNT);
        assertEq(goldToken.totalSupply(), AMOUNT);
    }

    function testNonIssuerCannotMint() public {
        vm.prank(attacker);
        vm.expectRevert();
        goldToken.mint(attacker, AMOUNT);
    }

    function testMintRevertsWithZeroAddress() public {
        vm.prank(issuer);
        vm.expectRevert(GoldToken.ZeroAddress.selector);
        goldToken.mint(address(0), AMOUNT);
    }

    function testMintRevertsWithZeroAmount() public {
        vm.prank(issuer);
        vm.expectRevert(GoldToken.ZeroAmount.selector);
        goldToken.mint(user, 0);
    }

    function testIssuerCanBurn() public {
        vm.prank(issuer);
        goldToken.mint(user, AMOUNT);

        vm.prank(issuer);
        goldToken.burn(user, 40 ether);

        assertEq(goldToken.balanceOf(user), 60 ether);
        assertEq(goldToken.totalSupply(), 60 ether);
    }

    function testNonIssuerCannotBurn() public {
        vm.prank(issuer);
        goldToken.mint(user, AMOUNT);

        vm.prank(attacker);
        vm.expectRevert();
        goldToken.burn(user, AMOUNT);
    }

    function testBurnRevertsWithZeroAddress() public {
        vm.prank(issuer);
        vm.expectRevert(GoldToken.ZeroAddress.selector);
        goldToken.burn(address(0), AMOUNT);
    }

    function testBurnRevertsWithZeroAmount() public {
        vm.prank(issuer);
        vm.expectRevert(GoldToken.ZeroAmount.selector);
        goldToken.burn(user, 0);
    }

    function testUserCanTransferWhenNotPaused() public {
        vm.prank(issuer);
        goldToken.mint(user, AMOUNT);

        vm.prank(user);
        goldToken.transfer(attacker, 10 ether);

        assertEq(goldToken.balanceOf(attacker), 10 ether);
        assertEq(goldToken.balanceOf(user), 90 ether);
    }

    function testPauserCanPauseAndUnpause() public {
        vm.prank(pauser);
        goldToken.pause();

        assertTrue(goldToken.paused());

        vm.prank(pauser);
        goldToken.unpause();

        assertFalse(goldToken.paused());
    }

    function testNonPauserCannotPause() public {
        vm.prank(attacker);
        vm.expectRevert();
        goldToken.pause();
    }

    function testTransferRevertsWhenPaused() public {
        vm.prank(issuer);
        goldToken.mint(user, AMOUNT);

        vm.prank(pauser);
        goldToken.pause();

        vm.prank(user);
        vm.expectRevert();
        goldToken.transfer(attacker, 1 ether);
    }

    function testMintRevertsWhenPaused() public {
        vm.prank(pauser);
        goldToken.pause();

        vm.prank(issuer);
        vm.expectRevert();
        goldToken.mint(user, AMOUNT);
    }
}
