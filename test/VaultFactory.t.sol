// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {VaultFactory} from "../src/VaultFactory.sol";
import {GoldToken} from "../src/GoldToken.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {GoldVaultV1} from "../src/GoldVaultV1.sol";
import {GoldCertificateNFT} from "../src/GoldCertificateNFT.sol";
import {GoldAMM} from "../src/GoldAMM.sol";

contract VaultFactoryTest is Test {
    VaultFactory public factory;

    address public admin;
    address public deployer = address(2);
    address public user = address(3);
    address public attacker = address(4);

    GoldToken public asset;
    GoldVaultV1 public vaultImplementation;

    bytes32 public constant SALT = keccak256("GOLDVAULT_SALT");

    function setUp() public {
        admin = address(this);

        factory = new VaultFactory(admin);
        factory.grantRole(factory.DEPLOYER_ROLE(), deployer);
        asset = new GoldToken(admin);
        vaultImplementation = new GoldVaultV1();
    }

    function testConstructorSetsRoles() public view {
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.DEPLOYER_ROLE(), admin));
    }

    function testConstructorRevertsWithZeroAdmin() public {
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        new VaultFactory(address(0));
    }

    function testDeployGoldToken() public {
        vm.prank(deployer);
        address token = factory.deployGoldToken(user);

        assertEq(factory.deployedTokensCount(), 1);
        assertEq(factory.deployedTokens(0), token);
        assertEq(GoldToken(token).name(), "GoldVault Token");
        assertTrue(GoldToken(token).hasRole(GoldToken(token).DEFAULT_ADMIN_ROLE(), user));
    }

    function testDeployGoldTokenDeterministic() public {
        address predicted = factory.predictGoldTokenAddress(user, SALT);

        vm.prank(deployer);
        address token = factory.deployGoldTokenDeterministic(user, SALT);

        assertEq(token, predicted);
        assertEq(factory.deployedTokensCount(), 1);
        assertEq(factory.deployedTokens(0), token);
    }

    function testDeployGovernanceToken() public {
        vm.prank(deployer);
        address token = factory.deployGovernanceToken(user);

        assertEq(factory.deployedTokensCount(), 1);
        assertEq(factory.deployedTokens(0), token);
        assertEq(GovernanceToken(token).name(), "GoldVault Governance");
        assertTrue(
            GovernanceToken(token).hasRole(GovernanceToken(token).DEFAULT_ADMIN_ROLE(), user)
        );
    }

    function testDeployGovernanceTokenDeterministic() public {
        vm.prank(deployer);
        address token = factory.deployGovernanceTokenDeterministic(user, SALT);

        assertEq(factory.deployedTokensCount(), 1);
        assertEq(factory.deployedTokens(0), token);
        assertEq(GovernanceToken(token).symbol(), "GVG");
    }

    function testDeployVaultProxy() public {
        vm.prank(deployer);
        address proxy = factory.deployVaultProxy(address(vaultImplementation), address(asset), user);

        assertEq(factory.deployedVaultsCount(), 1);
        assertEq(factory.deployedVaults(0), proxy);
        assertEq(GoldVaultV1(proxy).name(), "GoldVault Share");
        assertEq(address(GoldVaultV1(proxy).asset()), address(asset));
        assertTrue(GoldVaultV1(proxy).hasRole(GoldVaultV1(proxy).DEFAULT_ADMIN_ROLE(), user));
    }

    function testDeployVaultProxyDeterministic() public {
        address predicted = factory.predictVaultProxyAddress(
            address(vaultImplementation), address(asset), user, SALT
        );

        vm.prank(deployer);
        address proxy = factory.deployVaultProxyDeterministic(
            address(vaultImplementation), address(asset), user, SALT
        );

        assertEq(proxy, predicted);
        assertEq(factory.deployedVaultsCount(), 1);
        assertEq(factory.deployedVaults(0), proxy);
    }

    function testDeployNFT() public {
        vm.prank(deployer);
        address nft = factory.deployNFT(user);

        assertEq(factory.deployedNFTsCount(), 1);
        assertEq(factory.deployedNFTs(0), nft);
        assertEq(GoldCertificateNFT(nft).name(), "GoldVault Certificate");
        assertTrue(
            GoldCertificateNFT(nft).hasRole(GoldCertificateNFT(nft).DEFAULT_ADMIN_ROLE(), user)
        );
    }

    function testDeployNFTDeterministic() public {
        address predicted = factory.predictNFTAddress(user, SALT);

        vm.prank(deployer);
        address nft = factory.deployNFTDeterministic(user, SALT);

        assertEq(nft, predicted);
        assertEq(factory.deployedNFTsCount(), 1);
        assertEq(factory.deployedNFTs(0), nft);
    }

    function testDeployAMM() public {
        GoldToken token0 = new GoldToken(admin);
        GoldToken token1 = new GoldToken(admin);

        vm.prank(deployer);
        address amm = factory.deployAMM(address(token0), address(token1), user);

        assertEq(factory.deployedAMMsCount(), 1);
        assertEq(factory.deployedAMMs(0), amm);
        assertEq(address(GoldAMM(amm).token0()), address(token0));
        assertEq(address(GoldAMM(amm).token1()), address(token1));
        assertEq(GoldAMM(amm).owner(), user);
    }

    function testNonDeployerCannotDeployGoldToken() public {
        vm.prank(attacker);
        vm.expectRevert();
        factory.deployGoldToken(user);
    }

    function testDeployGoldTokenRevertsWithZeroAdmin() public {
        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployGoldToken(address(0));
    }

    function testDeployGovernanceTokenRevertsWithZeroAdmin() public {
        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployGovernanceToken(address(0));
    }

    function testDeployVaultProxyRevertsWithZeroImplementation() public {
        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroImplementation.selector);
        factory.deployVaultProxy(address(0), address(asset), user);
    }

    function testDeployVaultProxyRevertsWithZeroAsset() public {
        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployVaultProxy(address(vaultImplementation), address(0), user);
    }

    function testDeployVaultProxyRevertsWithZeroAdmin() public {
        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployVaultProxy(address(vaultImplementation), address(asset), address(0));
    }

    function testDeployNFTRevertsWithZeroAdmin() public {
        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployNFT(address(0));
    }

    function testDeployAMMRevertsWithZeroToken0() public {
        GoldToken token1 = new GoldToken(admin);

        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployAMM(address(0), address(token1), user);
    }

    function testDeployAMMRevertsWithZeroToken1() public {
        GoldToken token0 = new GoldToken(admin);

        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployAMM(address(token0), address(0), user);
    }

    function testDeployAMMRevertsWithZeroOwner() public {
        GoldToken token0 = new GoldToken(admin);
        GoldToken token1 = new GoldToken(admin);

        vm.prank(deployer);
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        factory.deployAMM(address(token0), address(token1), address(0));
    }

    function testInitialCountsAreZero() public view {
        assertEq(factory.deployedTokensCount(), 0);
        assertEq(factory.deployedVaultsCount(), 0);
        assertEq(factory.deployedNFTsCount(), 0);
        assertEq(factory.deployedAMMsCount(), 0);
    }
}
