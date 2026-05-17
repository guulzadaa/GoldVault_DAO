// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ReentrancyVulnerableVault {
    mapping(address => uint256) public balances;

    error ZeroAmount();
    error NoBalance();
    error TransferFailed();

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();

        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 userBalance = balances[msg.sender];

        if (userBalance == 0) revert NoBalance();

        (bool success,) = msg.sender.call{value: userBalance}("");
        if (!success) revert TransferFailed();

        balances[msg.sender] = 0;
    }

    function totalVaultBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
