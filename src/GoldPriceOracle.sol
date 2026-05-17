// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

contract GoldPriceOracle is Ownable {
    AggregatorV3Interface private priceFeed;

    uint256 public stalePeriod;

    error ZeroAddress();
    error InvalidStalePeriod();
    error InvalidPrice();
    error StalePrice();
    error IncompleteRound();

    event PriceFeedUpdated(address indexed oldFeed, address indexed newFeed);
    event StalePeriodUpdated(uint256 oldStalePeriod, uint256 newStalePeriod);

    constructor(address initialFeed, uint256 initialStalePeriod, address admin) Ownable(admin) {
        if (initialFeed == address(0) || admin == address(0)) revert ZeroAddress();
        if (initialStalePeriod == 0) revert InvalidStalePeriod();

        priceFeed = AggregatorV3Interface(initialFeed);
        stalePeriod = initialStalePeriod;
    }

    function setPriceFeed(address newFeed) external onlyOwner {
        if (newFeed == address(0)) revert ZeroAddress();

        address oldFeed = address(priceFeed);
        priceFeed = AggregatorV3Interface(newFeed);

        emit PriceFeedUpdated(oldFeed, newFeed);
    }

    function setStalePeriod(uint256 newStalePeriod) external onlyOwner {
        if (newStalePeriod == 0) revert InvalidStalePeriod();

        uint256 oldStalePeriod = stalePeriod;
        stalePeriod = newStalePeriod;

        emit StalePeriodUpdated(oldStalePeriod, newStalePeriod);
    }

    function getLatestPrice() external view returns (uint256) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        if (answer <= 0) revert InvalidPrice();
        if (updatedAt == 0) revert IncompleteRound();
        if (answeredInRound < roundId) revert IncompleteRound();
        if (block.timestamp - updatedAt > stalePeriod) revert StalePrice();

        return uint256(answer);
    }

    function getPriceFeed() external view returns (address) {
        return address(priceFeed);
    }

    function getDecimals() external view returns (uint8) {
        return priceFeed.decimals();
    }

    function getDescription() external view returns (string memory) {
        return priceFeed.description();
    }
}
