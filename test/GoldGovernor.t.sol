// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

import {GoldGovernor} from "../src/GoldGovernor.sol";

contract MockGovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    constructor()
        ERC20("Mock Governance Token", "MGT")
        ERC20Permit("Mock Governance Token")
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}

contract GovernanceTarget {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }
}

contract GoldGovernorTest is Test {
    MockGovernanceToken public token;
    TimelockController public timelock;
    GoldGovernor public governor;
    GovernanceTarget public target;

    address public voter = address(1);

    function setUp() public {
        token = new MockGovernanceToken();

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);

        timelock = new TimelockController(
            1 days,
            proposers,
            executors,
            address(this)
        );

        governor = new GoldGovernor(
            IVotes(address(token)),
            timelock
        );

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, address(this));

        target = new GovernanceTarget();

        token.mint(voter, 100 ether);

        vm.prank(voter);
        token.delegate(voter);
    }

    function testFullGovernanceLifecycle() public {
        address[] memory targets = new address[](1);
        targets[0] = address(target);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSelector(
            GovernanceTarget.setValue.selector,
            777
        );

        string memory description = "Proposal: set target value to 777";

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voter);
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.roll(block.number + governor.votingDelay() + 1);

        vm.prank(voter);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        bytes32 descriptionHash = keccak256(bytes(description));

        governor.queue(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        vm.warp(block.timestamp + 1 days + 1);

        governor.execute(
            targets,
            values,
            calldatas,
            descriptionHash
        );

        assertEq(target.value(), 777);
    }

    function testGovernanceParametersAreCorrect() public view {
        assertEq(governor.votingDelay(), 7200);
        assertEq(governor.votingPeriod(), 50400);
        assertEq(governor.quorumNumerator(), 4);
        assertEq(governor.proposalThreshold(), 0);
    }
}