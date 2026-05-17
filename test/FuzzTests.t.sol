// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldToken} from "../src/GoldToken.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {MockERC4626Vault} from "./mocks/MockERC4626Vault.sol";
import {GoldAMM} from "../src/GoldAMM.sol";

contract FuzzTests is Test {
    GoldToken public goldToken;
    GoldToken public token0;
    GoldToken public token1;
    GovernanceToken public governanceToken;
    MockERC4626Vault public vault;
    GoldAMM public amm;

    address public admin = address(1);
    address public issuer = address(2);
    address public minter = address(3);
    address public user = address(4);
    address public trader = address(5);
    address public delegatee = address(6);
    address public owner = address(7);

    uint256 public constant MAX_AMOUNT = 1_000_000 ether;

    function setUp() public {
        goldToken = new GoldToken(admin);
        token0 = new GoldToken(admin);
        token1 = new GoldToken(admin);
        governanceToken = new GovernanceToken(admin);
        vault = new MockERC4626Vault(goldToken);

        vm.startPrank(admin);
        goldToken.grantRole(goldToken.ISSUER_ROLE(), issuer);
        token0.grantRole(token0.ISSUER_ROLE(), issuer);
        token1.grantRole(token1.ISSUER_ROLE(), issuer);
        governanceToken.grantRole(governanceToken.MINTER_ROLE(), minter);
        vm.stopPrank();

        amm = new GoldAMM(address(token0), address(token1), owner);

        vm.startPrank(issuer);
        goldToken.mint(user, MAX_AMOUNT);
        goldToken.mint(trader, MAX_AMOUNT);
        token0.mint(user, MAX_AMOUNT);
        token1.mint(user, MAX_AMOUNT);
        token0.mint(trader, MAX_AMOUNT);
        token1.mint(trader, MAX_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user);
        goldToken.approve(address(vault), type(uint256).max);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader);
        goldToken.approve(address(vault), type(uint256).max);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function testFuzzVaultDepositMintsShares(uint256 amount) public {
        amount = bound(amount, 1, MAX_AMOUNT);

        vm.prank(user);
        uint256 shares = vault.deposit(amount, user);

        assertGt(shares, 0);
        assertEq(vault.balanceOf(user), shares);
        assertEq(vault.totalAssets(), amount);
    }

    function testFuzzVaultWithdrawReturnsAssets(uint256 depositAmount, uint256 withdrawAmount)
        public
    {
        depositAmount = bound(depositAmount, 2, MAX_AMOUNT);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        vm.startPrank(user);
        vault.deposit(depositAmount, user);

        uint256 balanceBefore = goldToken.balanceOf(user);
        uint256 sharesBurned = vault.withdraw(withdrawAmount, user, user);
        uint256 balanceAfter = goldToken.balanceOf(user);

        vm.stopPrank();

        assertGt(sharesBurned, 0);
        assertEq(balanceAfter, balanceBefore + withdrawAmount);
        assertEq(vault.totalAssets(), depositAmount - withdrawAmount);
    }

    function testFuzzVaultRedeemBurnsShares(uint256 amount) public {
        amount = bound(amount, 1, MAX_AMOUNT);

        vm.startPrank(user);
        uint256 shares = vault.deposit(amount, user);

        uint256 assetsReturned = vault.redeem(shares, user, user);
        vm.stopPrank();

        assertEq(assetsReturned, amount);
        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.totalAssets(), 0);
    }

    function testFuzzVaultPreviewDepositMatchesDeposit(uint256 amount) public {
        amount = bound(amount, 1, MAX_AMOUNT);

        uint256 previewShares = vault.previewDeposit(amount);

        vm.prank(user);
        uint256 actualShares = vault.deposit(amount, user);

        assertEq(actualShares, previewShares);
    }

    function testFuzzGovernanceMintAndDelegateToSelf(uint256 amount) public {
        amount = bound(amount, 1, MAX_AMOUNT);

        vm.prank(minter);
        governanceToken.mint(user, amount);

        vm.prank(user);
        governanceToken.delegate(user);

        assertEq(governanceToken.getVotes(user), amount);
        assertEq(governanceToken.delegates(user), user);
    }

    function testFuzzGovernanceDelegateToAnotherAddress(uint256 amount) public {
        amount = bound(amount, 1, MAX_AMOUNT);

        vm.prank(minter);
        governanceToken.mint(user, amount);

        vm.prank(user);
        governanceToken.delegate(delegatee);

        assertEq(governanceToken.getVotes(delegatee), amount);
        assertEq(governanceToken.getVotes(user), 0);
    }

    function testFuzzGovernanceVotingPowerAfterTransfer(uint256 amount, uint256 transferAmount)
        public
    {
        amount = bound(amount, 2, MAX_AMOUNT);
        transferAmount = bound(transferAmount, 1, amount - 1);

        vm.prank(minter);
        governanceToken.mint(user, amount);

        vm.prank(user);
        governanceToken.delegate(user);

        vm.prank(user);
        governanceToken.transfer(delegatee, transferAmount);

        vm.prank(delegatee);
        governanceToken.delegate(delegatee);

        assertEq(governanceToken.getVotes(user), amount - transferAmount);
        assertEq(governanceToken.getVotes(delegatee), transferAmount);
    }

    function testFuzzAMMSwapToken0ForToken1(uint256 liquidityAmount, uint256 swapAmount) public {
        liquidityAmount = bound(liquidityAmount, 1000 ether, 500_000 ether);
        swapAmount = bound(swapAmount, 1, liquidityAmount / 2);

        vm.prank(user);
        amm.addLiquidity(liquidityAmount, liquidityAmount, 0, 0, user);

        uint256 expectedOut = amm.getAmountOut(swapAmount, address(token0));
        uint256 traderToken1Before = token1.balanceOf(trader);

        vm.prank(trader);
        uint256 actualOut = amm.swapExactToken0ForToken1(swapAmount, 0, trader);

        assertEq(actualOut, expectedOut);
        assertEq(token1.balanceOf(trader), traderToken1Before + actualOut);

        (uint256 reserve0, uint256 reserve1) = amm.getReserves();
        assertEq(reserve0, liquidityAmount + swapAmount);
        assertEq(reserve1, liquidityAmount - actualOut);
    }

    function testFuzzAMMSwapToken1ForToken0(uint256 liquidityAmount, uint256 swapAmount) public {
        liquidityAmount = bound(liquidityAmount, 1000 ether, 500_000 ether);
        swapAmount = bound(swapAmount, 1, liquidityAmount / 2);

        vm.prank(user);
        amm.addLiquidity(liquidityAmount, liquidityAmount, 0, 0, user);

        uint256 expectedOut = amm.getAmountOut(swapAmount, address(token1));
        uint256 traderToken0Before = token0.balanceOf(trader);

        vm.prank(trader);
        uint256 actualOut = amm.swapExactToken1ForToken0(swapAmount, 0, trader);

        assertEq(actualOut, expectedOut);
        assertEq(token0.balanceOf(trader), traderToken0Before + actualOut);

        (uint256 reserve0, uint256 reserve1) = amm.getReserves();
        assertEq(reserve0, liquidityAmount - actualOut);
        assertEq(reserve1, liquidityAmount + swapAmount);
    }

    function testFuzzAMMAddAndRemoveLiquidity(uint256 liquidityAmount) public {
        liquidityAmount = bound(liquidityAmount, 1000 ether, 500_000 ether);

        vm.startPrank(user);

        (,, uint256 shares) = amm.addLiquidity(liquidityAmount, liquidityAmount, 0, 0, user);

        uint256 token0Before = token0.balanceOf(user);
        uint256 token1Before = token1.balanceOf(user);

        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(shares, 0, 0, user);

        vm.stopPrank();

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(token0.balanceOf(user), token0Before + amount0);
        assertEq(token1.balanceOf(user), token1Before + amount1);
    }
}
