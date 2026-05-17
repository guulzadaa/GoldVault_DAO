// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {GoldToken} from "../src/GoldToken.sol";
import {GoldVaultV1} from "../src/GoldVaultV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GoldVaultV1Test is Test {
    GoldToken public asset;
    GoldVaultV1 public vault;

    address public admin = address(1);
    address public issuer = address(2);
    address public pauser = address(3);

    address public user = address(4);
    address public attacker = address(5);

    uint256 public constant STARTING_BALANCE = 1000 ether;

    function setUp() public {
        asset = new GoldToken(admin);

        vm.startPrank(admin);
        asset.grantRole(asset.ISSUER_ROLE(), issuer);
        asset.grantRole(asset.PAUSER_ROLE(), pauser);
        vm.stopPrank();

        GoldVaultV1 implementation = new GoldVaultV1();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(GoldVaultV1.initialize, (address(asset), admin))
        );

        vault = GoldVaultV1(address(proxy));

        vm.prank(issuer);
        asset.mint(user, STARTING_BALANCE);

        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
    }

    function testInitializeSetsCorrectValues() public view {
        assertEq(vault.name(), "GoldVault Share");
        assertEq(vault.symbol(), "gvSHARE");

        assertEq(address(vault.asset()), address(asset));

        assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(vault.hasRole(vault.PAUSER_ROLE(), admin));
        assertTrue(vault.hasRole(vault.UPGRADER_ROLE(), admin));
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert();
        vault.initialize(address(asset), admin);
    }

    function testDeposit() public {
        vm.prank(user);

        uint256 shares = vault.deposit(100 ether, user);

        assertEq(shares, 100 ether);

        assertEq(vault.balanceOf(user), 100 ether);

        assertEq(vault.totalAssets(), 100 ether);

        assertEq(asset.balanceOf(address(vault)), 100 ether);
    }

    function testMint() public {
        vm.prank(user);

        uint256 assets = vault.mint(100 ether, user);

        assertEq(assets, 100 ether);

        assertEq(vault.balanceOf(user), 100 ether);

        assertEq(vault.totalAssets(), 100 ether);
    }

    function testWithdraw() public {
        vm.startPrank(user);

        vault.deposit(200 ether, user);

        uint256 sharesBurned = vault.withdraw(50 ether, user, user);

        vm.stopPrank();

        assertEq(sharesBurned, 50 ether);

        assertEq(vault.balanceOf(user), 150 ether);

        assertEq(vault.totalAssets(), 150 ether);
    }

    function testRedeem() public {
        vm.startPrank(user);

        vault.deposit(300 ether, user);

        uint256 assetsReturned = vault.redeem(100 ether, user, user);

        vm.stopPrank();

        assertEq(assetsReturned, 100 ether);

        assertEq(vault.balanceOf(user), 200 ether);

        assertEq(vault.totalAssets(), 200 ether);
    }

    function testPreviewDeposit() public view {
        assertEq(vault.previewDeposit(100 ether), 100 ether);
    }

    function testPreviewMint() public view {
        assertEq(vault.previewMint(100 ether), 100 ether);
    }

    function testPreviewWithdraw() public view {
        assertEq(vault.previewWithdraw(100 ether), 100 ether);
    }

    function testPreviewRedeem() public view {
        assertEq(vault.previewRedeem(100 ether), 100 ether);
    }

    function testMaxDeposit() public view {
        assertEq(vault.maxDeposit(user), type(uint256).max);
    }

    function testMaxMint() public view {
        assertEq(vault.maxMint(user), type(uint256).max);
    }

    function testMaxWithdrawAfterDeposit() public {
        vm.prank(user);
        vault.deposit(400 ether, user);

        assertEq(vault.maxWithdraw(user), 400 ether);
    }

    function testMaxRedeemAfterDeposit() public {
        vm.prank(user);
        vault.deposit(500 ether, user);

        assertEq(vault.maxRedeem(user), 500 ether);
    }

    function testPauseAndUnpause() public {
        vm.prank(admin);
        vault.pause();

        assertTrue(vault.paused());

        vm.prank(admin);
        vault.unpause();

        assertFalse(vault.paused());
    }

    function testNonOwnerCannotPause() public {
        vm.prank(attacker);

        vm.expectRevert();

        vault.pause();
    }

    function testDepositRevertsWhenPaused() public {
        vm.prank(admin);
        vault.pause();

        vm.prank(user);

        vm.expectRevert();

        vault.deposit(100 ether, user);
    }

    function testWithdrawRevertsWhenPaused() public {
        vm.prank(user);
        vault.deposit(100 ether, user);

        vm.prank(admin);
        vault.pause();

        vm.prank(user);

        vm.expectRevert();

        vault.withdraw(50 ether, user, user);
    }

    function testTransferShares() public {
        vm.prank(user);
        vault.deposit(100 ether, user);

        vm.prank(user);
        vault.transfer(attacker, 40 ether);

        assertEq(vault.balanceOf(attacker), 40 ether);

        assertEq(vault.balanceOf(user), 60 ether);
    }
}
