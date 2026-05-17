// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GoldPriceOracle} from "../src/GoldPriceOracle.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract GoldPriceOracleTest is Test {
    GoldPriceOracle public oracle;
    MockV3Aggregator public mockFeed;

    address public admin = address(1);
    address public attacker = address(2);

    uint256 public constant STALE_PERIOD = 1 hours;
    int256 public constant INITIAL_PRICE = 2350e8;

    function setUp() public {
        vm.warp(1_700_000_000);

        mockFeed = new MockV3Aggregator(8, INITIAL_PRICE);
        oracle = new GoldPriceOracle(address(mockFeed), STALE_PERIOD, admin);
    }

    function testConstructorSetsCorrectValues() public {
        assertEq(oracle.getPriceFeed(), address(mockFeed));
        assertEq(oracle.stalePeriod(), STALE_PERIOD);
        assertEq(oracle.owner(), admin);
    }

    function testGetLatestPriceReturnsPrice() public {
        uint256 price = oracle.getLatestPrice();

        assertEq(price, uint256(INITIAL_PRICE));
    }

    function testGetDecimalsReturnsFeedDecimals() public {
        uint8 decimals = oracle.getDecimals();

        assertEq(decimals, 8);
    }

    function testGetDescriptionReturnsFeedDescription() public {
        string memory description = oracle.getDescription();

        assertEq(description, "Mock Gold / USD Price Feed");
    }

    function testOwnerCanUpdatePriceFeed() public {
        MockV3Aggregator newFeed = new MockV3Aggregator(8, 2500e8);

        vm.prank(admin);
        oracle.setPriceFeed(address(newFeed));

        assertEq(oracle.getPriceFeed(), address(newFeed));
        assertEq(oracle.getLatestPrice(), 2500e8);
    }

    function testNonOwnerCannotUpdatePriceFeed() public {
        MockV3Aggregator newFeed = new MockV3Aggregator(8, 2500e8);

        vm.prank(attacker);
        vm.expectRevert();
        oracle.setPriceFeed(address(newFeed));
    }

    function testCannotSetZeroPriceFeed() public {
        vm.prank(admin);
        vm.expectRevert(GoldPriceOracle.ZeroAddress.selector);
        oracle.setPriceFeed(address(0));
    }

    function testOwnerCanUpdateStalePeriod() public {
        uint256 newStalePeriod = 2 hours;

        vm.prank(admin);
        oracle.setStalePeriod(newStalePeriod);

        assertEq(oracle.stalePeriod(), newStalePeriod);
    }

    function testNonOwnerCannotUpdateStalePeriod() public {
        vm.prank(attacker);
        vm.expectRevert();
        oracle.setStalePeriod(2 hours);
    }

    function testCannotSetZeroStalePeriod() public {
        vm.prank(admin);
        vm.expectRevert(GoldPriceOracle.InvalidStalePeriod.selector);
        oracle.setStalePeriod(0);
    }

    function testRevertsWhenPriceIsZero() public {
        mockFeed.updateAnswer(0);

        vm.expectRevert(GoldPriceOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testRevertsWhenPriceIsNegative() public {
        mockFeed.updateAnswer(-1);

        vm.expectRevert(GoldPriceOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testRevertsWhenPriceIsStale() public {
        uint256 oldUpdatedAt = block.timestamp - STALE_PERIOD - 1;

        mockFeed.setRoundData(1, INITIAL_PRICE, oldUpdatedAt, oldUpdatedAt, 1);

        vm.expectRevert(GoldPriceOracle.StalePrice.selector);
        oracle.getLatestPrice();
    }

    function testRevertsWhenUpdatedAtIsZero() public {
        mockFeed.setRoundData(1, INITIAL_PRICE, 0, 0, 1);

        vm.expectRevert(GoldPriceOracle.IncompleteRound.selector);
        oracle.getLatestPrice();
    }

    function testRevertsWhenAnsweredInRoundIsOld() public {
        mockFeed.setRoundData(2, INITIAL_PRICE, block.timestamp, block.timestamp, 1);

        vm.expectRevert(GoldPriceOracle.IncompleteRound.selector);
        oracle.getLatestPrice();
    }

    function testConstructorRevertsWithZeroFeed() public {
        vm.expectRevert(GoldPriceOracle.ZeroAddress.selector);
        new GoldPriceOracle(address(0), STALE_PERIOD, admin);
    }

    function testConstructorRevertsWithZeroAdmin() public {
        vm.expectRevert();
        new GoldPriceOracle(address(mockFeed), STALE_PERIOD, address(0));
    }

    function testConstructorRevertsWithZeroStalePeriod() public {
        vm.expectRevert(GoldPriceOracle.InvalidStalePeriod.selector);
        new GoldPriceOracle(address(mockFeed), 0, admin);
    }
}
