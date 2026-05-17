// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";

interface IGovernor {
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);
}

contract CreateProposal is Script {
    function run() external {
        vm.startBroadcast();

        IGovernor governor = IGovernor(
            vm.envAddress("DEPLOYED_GOVERNOR")
        );

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = vm.envAddress("DEPLOYED_GOLD_TOKEN");
        values[0] = 0;

        calldatas[0] = abi.encodeWithSignature(
            "grantRole(bytes32,address)",
            keccak256("ISSUER_ROLE"),
            msg.sender
        );

        string memory description =
            "Demo proposal for GoldVault DAO";

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        console.log("Proposal created!");
        console.log("Proposal ID:");
        console.logUint(proposalId);

        vm.stopBroadcast();
    }
}