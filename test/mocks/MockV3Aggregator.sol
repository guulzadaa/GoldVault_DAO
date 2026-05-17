// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "../../src/interfaces/AggregatorV3Interface.sol";

contract MockV3Aggregator is AggregatorV3Interface {
    uint8 private immutable feedDecimals;
    string private feedDescription;

    uint80 private currentRoundId;
    int256 private currentAnswer;
    uint256 private currentStartedAt;
    uint256 private currentUpdatedAt;
    uint80 private currentAnsweredInRound;

    constructor(uint8 decimals_, int256 initialAnswer) {
        feedDecimals = decimals_;
        feedDescription = "Mock Gold / USD Price Feed";

        currentRoundId = 1;
        currentAnswer = initialAnswer;
        currentStartedAt = block.timestamp;
        currentUpdatedAt = block.timestamp;
        currentAnsweredInRound = 1;
    }

    function decimals() external view override returns (uint8) {
        return feedDecimals;
    }

    function description() external view override returns (string memory) {
        return feedDescription;
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 roundId)
        external
        view
        override
        returns (
            uint80 roundId_,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        roundId_;
        require(roundId == currentRoundId, "Round not found");

        return
            (
                currentRoundId,
                currentAnswer,
                currentStartedAt,
                currentUpdatedAt,
                currentAnsweredInRound
            );
    }

    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (
            currentRoundId,
            currentAnswer,
            currentStartedAt,
            currentUpdatedAt,
            currentAnsweredInRound
        );
    }

    function updateAnswer(int256 newAnswer) external {
        currentRoundId++;
        currentAnswer = newAnswer;
        currentStartedAt = block.timestamp;
        currentUpdatedAt = block.timestamp;
        currentAnsweredInRound = currentRoundId;
    }

    function setRoundData(
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) external {
        currentRoundId = roundId;
        currentAnswer = answer;
        currentStartedAt = startedAt;
        currentUpdatedAt = updatedAt;
        currentAnsweredInRound = answeredInRound;
    }
}
