// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "../src/interfaces/AggregatorV3Interface.sol";

interface IERC20MetadataFork {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router02Fork {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract ForkTests is Test {
    uint256 public mainnetFork;

    string public MAINNET_RPC_URL;

    // Ethereum mainnet addresses
    address public constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    function setUp() public {
        MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
    }

    function testForkChainlinkEthUsdFeedReturnsValidPrice() public view {
        AggregatorV3Interface feed = AggregatorV3Interface(CHAINLINK_ETH_USD);

        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            feed.latestRoundData();

        assertGt(roundId, 0);
        assertGt(answer, 0);
        assertGt(updatedAt, 0);
        assertGe(answeredInRound, roundId);
        assertEq(feed.decimals(), 8);
    }

    function testForkUSDCMetadataAndSupply() public view {
        IERC20MetadataFork usdc = IERC20MetadataFork(USDC);

        assertEq(usdc.symbol(), "USDC");
        assertEq(usdc.decimals(), 6);
        assertGt(usdc.totalSupply(), 0);
    }

    function testForkUSDCWhaleHasBalance() public view {
        IERC20MetadataFork usdc = IERC20MetadataFork(USDC);

        address whale = 0x55FE002aefF02F77364de339a1292923A15844B8;

        assertGt(usdc.balanceOf(whale), 0);
    }

    function testForkUniswapV2RouterHasCorrectWETHAndFactory() public view {
        IUniswapV2Router02Fork router = IUniswapV2Router02Fork(UNISWAP_V2_ROUTER);

        address factory = router.factory();
        address weth = router.WETH();

        assertEq(weth, WETH);
        assertTrue(factory != address(0));
    }

    function testForkUniswapV2GetAmountsOutEthToUsdc() public view {
        IUniswapV2Router02Fork router = IUniswapV2Router02Fork(UNISWAP_V2_ROUTER);

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        uint256[] memory amounts = router.getAmountsOut(1 ether, path);

        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1 ether);
        assertGt(amounts[1], 0);
    }
}
