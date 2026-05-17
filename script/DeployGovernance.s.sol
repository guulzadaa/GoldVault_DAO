// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GoldGovernor} from "../src/GoldGovernor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

contract DeployGovernance is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address governanceToken = vm.envAddress("DEPLOYED_GOVERNANCE_TOKEN");

        uint256 minDelay = 1 days;

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0); // anyone can execute successful proposals

        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);

TimelockController timelock = new TimelockController(
    minDelay,
    proposers,
    executors,
    deployer
);

        GoldGovernor governor = new GoldGovernor(
            IVotes(governanceToken),
            timelock
        );

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, deployer);

        vm.stopBroadcast();

        console.log("Timelock deployed at:", address(timelock));
        console.log("Governor deployed at:", address(governor));
    }
}