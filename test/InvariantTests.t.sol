// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {GoldToken} from "../src/GoldToken.sol";
import {GoldAMM} from "../src/GoldAMM.sol";
import {MockERC4626Vault} from "./mocks/MockERC4626Vault.sol";

contract VaultHandler is Test {
    GoldToken public asset;
    MockERC4626Vault public vault;

    address public user;

    constructor(GoldToken asset_, MockERC4626Vault vault_, address user_) {
        asset = asset_;
        vault = vault_;
        user = user_;
    }

    function deposit(uint256 amount) public {
        uint256 balance = asset.balanceOf(user);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(user);
        vault.deposit(amount, user);
    }

    function withdraw(uint256 amount) public {
        uint256 maxWithdraw = vault.maxWithdraw(user);
        if (maxWithdraw == 0) return;

        amount = bound(amount, 1, maxWithdraw);

        vm.prank(user);
        vault.withdraw(amount, user, user);
    }
}

contract AMMSwapHandler is Test {
    GoldToken public token0;
    GoldToken public token1;
    GoldAMM public amm;

    address public trader;

    uint256 public initialK;

    constructor(GoldToken token0_, GoldToken token1_, GoldAMM amm_, address trader_) {
        token0 = token0_;
        token1 = token1_;
        amm = amm_;
        trader = trader_;

        (uint256 reserve0, uint256 reserve1) = amm.getReserves();
        initialK = reserve0 * reserve1;
    }

    function swapToken0ForToken1(uint256 amountIn) public {
        uint256 traderBalance = token0.balanceOf(trader);
        (uint256 reserve0,) = amm.getReserves();

        if (traderBalance == 0 || reserve0 == 0) return;

        amountIn = bound(amountIn, 1, traderBalance);
        amountIn = bound(amountIn, 1, reserve0 / 10);

        vm.prank(trader);
        amm.swapExactToken0ForToken1(amountIn, 0, trader);
    }

    function swapToken1ForToken0(uint256 amountIn) public {
        uint256 traderBalance = token1.balanceOf(trader);
        (, uint256 reserve1) = amm.getReserves();

        if (traderBalance == 0 || reserve1 == 0) return;

        amountIn = bound(amountIn, 1, traderBalance);
        amountIn = bound(amountIn, 1, reserve1 / 10);

        vm.prank(trader);
        amm.swapExactToken1ForToken0(amountIn, 0, trader);
    }
}

contract InvariantTests is StdInvariant, Test {
    GoldToken public goldToken;
    GoldToken public token0;
    GoldToken public token1;

    MockERC4626Vault public vault;
    GoldAMM public amm;

    VaultHandler public vaultHandler;
    AMMSwapHandler public ammHandler;

    address public admin = address(1);
    address public issuer = address(2);
    address public user = address(3);
    address public trader = address(4);
    address public owner = address(5);

    uint256 public constant STARTING_BALANCE = 1_000_000 ether;
    uint256 public constant INITIAL_LIQUIDITY = 100_000 ether;

    function setUp() public {
        goldToken = new GoldToken(admin);
        token0 = new GoldToken(admin);
        token1 = new GoldToken(admin);

        vm.startPrank(admin);
        goldToken.grantRole(goldToken.ISSUER_ROLE(), issuer);
        token0.grantRole(token0.ISSUER_ROLE(), issuer);
        token1.grantRole(token1.ISSUER_ROLE(), issuer);
        vm.stopPrank();

        vault = new MockERC4626Vault(goldToken);
        amm = new GoldAMM(address(token0), address(token1), owner);

        vm.startPrank(issuer);
        goldToken.mint(user, STARTING_BALANCE);

        token0.mint(user, STARTING_BALANCE);
        token1.mint(user, STARTING_BALANCE);

        token0.mint(trader, STARTING_BALANCE);
        token1.mint(trader, STARTING_BALANCE);
        vm.stopPrank();

        vm.startPrank(user);
        goldToken.approve(address(vault), type(uint256).max);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        amm.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, user);
        vm.stopPrank();

        vm.startPrank(trader);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vaultHandler = new VaultHandler(goldToken, vault, user);
        ammHandler = new AMMSwapHandler(token0, token1, amm, trader);

        targetContract(address(vaultHandler));
        targetContract(address(ammHandler));
    }

    function invariantVaultTotalAssetsEqualsTokenBalance() public view {
        assertEq(vault.totalAssets(), goldToken.balanceOf(address(vault)));
    }

    function invariantVaultSharesMatchUserBalance() public view {
        assertEq(vault.totalSupply(), vault.balanceOf(user));
    }

    function invariantGoldTokenSupplyIsConserved() public view {
        assertEq(goldToken.totalSupply(), STARTING_BALANCE);
    }

    function invariantAMMReservesMatchTokenBalances() public view {
        (uint256 reserve0, uint256 reserve1) = amm.getReserves();

        assertEq(reserve0, token0.balanceOf(address(amm)));
        assertEq(reserve1, token1.balanceOf(address(amm)));
    }

    function invariantAMMKDoesNotDecreaseAfterSwaps() public view {
        (uint256 reserve0, uint256 reserve1) = amm.getReserves();

        uint256 currentK = reserve0 * reserve1;

        assertGe(currentK, ammHandler.initialK());
    }
}
