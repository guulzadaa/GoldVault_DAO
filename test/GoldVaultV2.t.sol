// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {GoldToken} from "../src/GoldToken.sol";
import {GoldVaultV1} from "../src/GoldVaultV1.sol";
import {GoldVaultV2} from "../src/GoldVaultV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GoldVaultV2Test is Test {
    GoldToken public asset;
    GoldVaultV2 public vault;

    address public admin;
    address public issuer = address(2);
    address public user = address(3);
    address public attacker = address(4);

    function setUp() public {
        admin = address(this);

        asset = new GoldToken(admin);
        asset.grantRole(asset.ISSUER_ROLE(), issuer);

        GoldVaultV1 implementationV1 = new GoldVaultV1();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementationV1),
            abi.encodeCall(GoldVaultV1.initialize, (address(asset), admin))
        );

        GoldVaultV2 implementationV2 = new GoldVaultV2();

        GoldVaultV1(address(proxy))
            .upgradeToAndCall(
                address(implementationV2),
                abi.encodeCall(GoldVaultV2.initializeV2, (500 ether, 200 ether, admin))
            );

        vault = GoldVaultV2(address(proxy));

        vm.prank(issuer);
        asset.mint(user, 1000 ether);

        vm.prank(user);
        asset.approve(address(vault), type(uint256).max);
    }

    function testVersionReturns2() public view {
        assertEq(vault.version(), "2");
    }

    function testV2CapsAreSet() public view {
        assertEq(vault.vaultDepositCap(), 500 ether);
        assertEq(vault.perUserDepositCap(), 200 ether);
        assertTrue(vault.hasRole(vault.CAP_MANAGER_ROLE(), admin));
    }

    function testDepositStillWorksInV2() public {
        vm.prank(user);
        vault.deposit(100 ether, user);

        assertEq(vault.balanceOf(user), 100 ether);
        assertEq(vault.totalAssets(), 100 ether);
        assertEq(vault.userTotalDeposited(user), 100 ether);
    }

    function testDepositRevertsAbovePerUserCap() public {
        vm.prank(user);
        vm.expectRevert();
        vault.deposit(201 ether, user);
    }

    function testAdminCanUpdateVaultDepositCap() public {
        vault.setVaultDepositCap(800 ether);

        assertEq(vault.vaultDepositCap(), 800 ether);
    }

    function testAdminCanUpdatePerUserDepositCap() public {
        vault.setPerUserDepositCap(300 ether);

        assertEq(vault.perUserDepositCap(), 300 ether);
    }

    function testNonAdminCannotUpdateVaultDepositCap() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.setVaultDepositCap(800 ether);
    }

    function testNonAdminCannotUpdatePerUserDepositCap() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.setPerUserDepositCap(300 ether);
    }

    function testWithdrawStillWorksInV2() public {
        vm.startPrank(user);

        vault.deposit(100 ether, user);
        vault.withdraw(50 ether, user, user);

        vm.stopPrank();

        assertEq(vault.balanceOf(user), 50 ether);
        assertEq(vault.totalAssets(), 50 ether);
        assertEq(vault.userTotalDeposited(user), 50 ether);
    }

    function testPauseStillWorksInV2() public {
        vault.pause();

        assertTrue(vault.paused());
    }

    function testOnlyAdminCanPause() public {
        vm.prank(attacker);
        vm.expectRevert();
        vault.pause();
    }

    function testPreviewFunctionsStillWork() public view {
        assertEq(vault.previewDeposit(100 ether), 100 ether);
        assertEq(vault.previewMint(100 ether), 100 ether);
        assertEq(vault.previewWithdraw(100 ether), 100 ether);
        assertEq(vault.previewRedeem(100 ether), 100 ether);
    }

    function testTransferSharesInV2() public {
        vm.prank(user);
        vault.deposit(100 ether, user);

        vm.prank(user);
        vault.transfer(attacker, 25 ether);

        assertEq(vault.balanceOf(attacker), 25 ether);
        assertEq(vault.balanceOf(user), 75 ether);
    }
}
