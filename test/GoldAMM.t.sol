// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldAMM} from "../src/GoldAMM.sol";
import {GoldToken} from "../src/GoldToken.sol";

contract GoldAMMTest is Test {
    GoldToken public token0;
    GoldToken public token1;
    GoldToken public invalidToken;
    GoldAMM public amm;

    address public admin = address(1);
    address public issuer = address(2);
    address public owner = address(3);
    address public user = address(4);
    address public attacker = address(5);

    uint256 public constant INITIAL_AMOUNT = 1000 ether;

    function setUp() public {
        token0 = new GoldToken(admin);
        token1 = new GoldToken(admin);
        invalidToken = new GoldToken(admin);

        vm.startPrank(admin);
        token0.grantRole(token0.ISSUER_ROLE(), issuer);
        token1.grantRole(token1.ISSUER_ROLE(), issuer);
        invalidToken.grantRole(invalidToken.ISSUER_ROLE(), issuer);
        vm.stopPrank();

        amm = new GoldAMM(address(token0), address(token1), owner);

        vm.startPrank(issuer);
        token0.mint(user, INITIAL_AMOUNT);
        token1.mint(user, INITIAL_AMOUNT);
        token0.mint(attacker, INITIAL_AMOUNT);
        token1.mint(attacker, INITIAL_AMOUNT);
        vm.stopPrank();

        vm.startPrank(user);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(attacker);
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function testConstructorSetsTokensAndOwner() public view {
        assertEq(address(amm.token0()), address(token0));
        assertEq(address(amm.token1()), address(token1));
        assertEq(amm.owner(), owner);
        assertEq(amm.name(), "GoldAMM LP");
        assertEq(amm.symbol(), "GVLP");
    }

    function testConstructorRevertsWithZeroToken0() public {
        vm.expectRevert(GoldAMM.ZeroAddress.selector);
        new GoldAMM(address(0), address(token1), owner);
    }

    function testConstructorRevertsWithZeroToken1() public {
        vm.expectRevert(GoldAMM.ZeroAddress.selector);
        new GoldAMM(address(token0), address(0), owner);
    }

    function testConstructorRevertsWithZeroOwner() public {
        vm.expectRevert();
        new GoldAMM(address(token0), address(token1), address(0));
    }

    function testConstructorRevertsWithIdenticalTokens() public {
        vm.expectRevert(GoldAMM.IdenticalTokens.selector);
        new GoldAMM(address(token0), address(token0), owner);
    }

    function testAddInitialLiquidity() public {
        vm.prank(user);
        (uint256 amount0, uint256 amount1, uint256 shares) =
            amm.addLiquidity(100 ether, 100 ether, 90 ether, 90 ether, user);

        assertEq(amount0, 100 ether);
        assertEq(amount1, 100 ether);
        assertGt(shares, 0);
        assertEq(amm.balanceOf(user), shares);
        assertEq(token0.balanceOf(address(amm)), 100 ether);
        assertEq(token1.balanceOf(address(amm)), 100 ether);

        (uint256 reserve0, uint256 reserve1) = amm.getReserves();
        assertEq(reserve0, 100 ether);
        assertEq(reserve1, 100 ether);
    }

    function testAddLiquidityRevertsWithZeroAmount0() public {
        vm.prank(user);
        vm.expectRevert(GoldAMM.ZeroAmount.selector);
        amm.addLiquidity(0, 100 ether, 0, 0, user);
    }

    function testAddLiquidityRevertsWithZeroAmount1() public {
        vm.prank(user);
        vm.expectRevert(GoldAMM.ZeroAmount.selector);
        amm.addLiquidity(100 ether, 0, 0, 0, user);
    }

    function testAddLiquidityRevertsWithZeroReceiver() public {
        vm.prank(user);
        vm.expectRevert(GoldAMM.ZeroAddress.selector);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, address(0));
    }

    function testAddLiquidityRevertsWithSlippage() public {
        vm.prank(user);
        vm.expectRevert(GoldAMM.SlippageExceeded.selector);
        amm.addLiquidity(100 ether, 100 ether, 101 ether, 100 ether, user);
    }

    function testAddSecondLiquidityKeepsRatio() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        vm.prank(attacker);
        (uint256 amount0, uint256 amount1, uint256 shares) =
            amm.addLiquidity(50 ether, 50 ether, 49 ether, 49 ether, attacker);

        assertEq(amount0, 50 ether);
        assertEq(amount1, 50 ether);
        assertGt(shares, 0);

        (uint256 reserve0, uint256 reserve1) = amm.getReserves();
        assertEq(reserve0, 150 ether);
        assertEq(reserve1, 150 ether);
    }

    function testRemoveLiquidity() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        uint256 userShares = amm.balanceOf(user);

        vm.prank(user);
        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(userShares / 2, 0, 0, user);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(token0.balanceOf(user), INITIAL_AMOUNT - 100 ether + amount0);
        assertEq(token1.balanceOf(user), INITIAL_AMOUNT - 100 ether + amount1);
    }

    function testRemoveLiquidityRevertsWithZeroShares() public {
        vm.prank(user);
        vm.expectRevert(GoldAMM.ZeroAmount.selector);
        amm.removeLiquidity(0, 0, 0, user);
    }

    function testRemoveLiquidityRevertsWithZeroReceiver() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        uint256 userShares = amm.balanceOf(user);

        vm.prank(user);
        vm.expectRevert(GoldAMM.ZeroAddress.selector);
        amm.removeLiquidity(userShares, 0, 0, address(0));
    }

    function testSwapExactToken0ForToken1() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        uint256 expectedOut = amm.getAmountOut(10 ether, address(token0));
        uint256 balanceBefore = token1.balanceOf(attacker);

        vm.prank(attacker);
        uint256 amountOut = amm.swapExactToken0ForToken1(10 ether, 0, attacker);

        assertEq(amountOut, expectedOut);
        assertEq(token1.balanceOf(attacker), balanceBefore + expectedOut);

        (uint256 reserve0, uint256 reserve1) = amm.getReserves();
        assertEq(reserve0, 110 ether);
        assertEq(reserve1, 100 ether - expectedOut);
    }

    function testSwapExactToken1ForToken0() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        uint256 expectedOut = amm.getAmountOut(10 ether, address(token1));
        uint256 balanceBefore = token0.balanceOf(attacker);

        vm.prank(attacker);
        uint256 amountOut = amm.swapExactToken1ForToken0(10 ether, 0, attacker);

        assertEq(amountOut, expectedOut);
        assertEq(token0.balanceOf(attacker), balanceBefore + expectedOut);

        (uint256 reserve0, uint256 reserve1) = amm.getReserves();
        assertEq(reserve0, 100 ether - expectedOut);
        assertEq(reserve1, 110 ether);
    }

    function testSwapRevertsWithZeroAmount() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        vm.prank(attacker);
        vm.expectRevert(GoldAMM.ZeroAmount.selector);
        amm.swapExactToken0ForToken1(0, 0, attacker);
    }

    function testSwapRevertsWithZeroReceiver() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        vm.prank(attacker);
        vm.expectRevert(GoldAMM.ZeroAddress.selector);
        amm.swapExactToken0ForToken1(10 ether, 0, address(0));
    }

    function testSwapRevertsWithInsufficientLiquidity() public {
        vm.prank(attacker);
        vm.expectRevert(GoldAMM.InsufficientLiquidity.selector);
        amm.swapExactToken0ForToken1(10 ether, 0, attacker);
    }

    function testSwapRevertsWithSlippageExceeded() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        vm.prank(attacker);
        vm.expectRevert(GoldAMM.SlippageExceeded.selector);
        amm.swapExactToken0ForToken1(10 ether, 100 ether, attacker);
    }

    function testGetAmountOutRevertsWithInvalidToken() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        vm.expectRevert(GoldAMM.InvalidToken.selector);
        amm.getAmountOut(10 ether, address(invalidToken));
    }

    function testOwnerCanPauseAndUnpause() public {
        vm.prank(owner);
        amm.pause();

        assertTrue(amm.paused());

        vm.prank(owner);
        amm.unpause();

        assertFalse(amm.paused());
    }

    function testNonOwnerCannotPause() public {
        vm.prank(attacker);
        vm.expectRevert();
        amm.pause();
    }

    function testAddLiquidityRevertsWhenPaused() public {
        vm.prank(owner);
        amm.pause();

        vm.prank(user);
        vm.expectRevert();
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);
    }

    function testSwapRevertsWhenPaused() public {
        vm.prank(user);
        amm.addLiquidity(100 ether, 100 ether, 0, 0, user);

        vm.prank(owner);
        amm.pause();

        vm.prank(attacker);
        vm.expectRevert();
        amm.swapExactToken0ForToken1(10 ether, 0, attacker);
    }
}
