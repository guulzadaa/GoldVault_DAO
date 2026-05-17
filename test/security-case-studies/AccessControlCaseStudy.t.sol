// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    AccessControlVulnerableToken
} from "../../src/security-case-studies/AccessControlVulnerableToken.sol";
import {AccessControlFixedToken} from "../../src/security-case-studies/AccessControlFixedToken.sol";

contract AccessControlCaseStudyTest is Test {
    AccessControlVulnerableToken public vulnerableToken;
    AccessControlFixedToken public fixedToken;

    address public admin = address(1);
    address public attacker = address(2);
    address public user = address(3);

    uint256 public constant MINT_AMOUNT = 1000 ether;

    function setUp() public {
        vulnerableToken = new AccessControlVulnerableToken();
        fixedToken = new AccessControlFixedToken(admin);
    }

    function testVulnerableTokenAllowsAnyoneToMint() public {
        vm.prank(attacker);
        vulnerableToken.mint(attacker, MINT_AMOUNT);

        assertEq(vulnerableToken.balanceOf(attacker), MINT_AMOUNT);
        assertEq(vulnerableToken.totalSupply(), MINT_AMOUNT);
    }

    function testFixedTokenBlocksUnauthorizedMint() public {
        vm.prank(attacker);
        vm.expectRevert();
        fixedToken.mint(attacker, MINT_AMOUNT);

        assertEq(fixedToken.balanceOf(attacker), 0);
        assertEq(fixedToken.totalSupply(), 0);
    }

    function testFixedTokenAllowsAuthorizedMinterToMint() public {
        vm.prank(admin);
        fixedToken.mint(user, MINT_AMOUNT);

        assertEq(fixedToken.balanceOf(user), MINT_AMOUNT);
        assertEq(fixedToken.totalSupply(), MINT_AMOUNT);
    }
}
