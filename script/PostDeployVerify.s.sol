// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {GoldToken} from "../src/GoldToken.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {GoldVaultV2} from "../src/GoldVaultV2.sol";
import {GoldCertificateNFT} from "../src/GoldCertificateNFT.sol";
import {GoldAMM} from "../src/GoldAMM.sol";
import {GoldPriceOracle} from "../src/GoldPriceOracle.sol";

contract PostDeployVerify is Script {
    function run() external view {
        address admin = vm.envAddress("DEPLOYED_ADMIN");
        address goldToken = vm.envAddress("DEPLOYED_GOLD_TOKEN");
        address governanceToken = vm.envAddress("DEPLOYED_GOVERNANCE_TOKEN");
        address vaultProxy = vm.envAddress("DEPLOYED_VAULT_PROXY");
        address nft = vm.envAddress("DEPLOYED_NFT");
        address amm = vm.envAddress("DEPLOYED_AMM");
        address oracle = vm.envAddress("DEPLOYED_ORACLE");

        require(
            GoldToken(goldToken).hasRole(GoldToken(goldToken).DEFAULT_ADMIN_ROLE(), admin),
            "GoldToken admin incorrect"
        );
        require(
            GovernanceToken(governanceToken)
                .hasRole(GovernanceToken(governanceToken).DEFAULT_ADMIN_ROLE(), admin),
            "GovernanceToken admin incorrect"
        );

        require(
            GoldVaultV2(vaultProxy).hasRole(GoldVaultV2(vaultProxy).DEFAULT_ADMIN_ROLE(), admin),
            "Vault admin incorrect"
        );
        require(
            GoldVaultV2(vaultProxy).hasRole(GoldVaultV2(vaultProxy).UPGRADER_ROLE(), admin),
            "Vault upgrader incorrect"
        );
        require(
            GoldVaultV2(vaultProxy).hasRole(GoldVaultV2(vaultProxy).CAP_MANAGER_ROLE(), admin),
            "Vault cap manager incorrect"
        );
        require(
            keccak256(bytes(GoldVaultV2(vaultProxy).version())) == keccak256(bytes("2")),
            "Vault not upgraded to V2"
        );

        require(
            GoldCertificateNFT(nft).hasRole(GoldCertificateNFT(nft).DEFAULT_ADMIN_ROLE(), admin),
            "NFT admin incorrect"
        );
        require(GoldAMM(amm).owner() == admin, "AMM owner incorrect");
        require(GoldPriceOracle(oracle).owner() == admin, "Oracle owner incorrect");

        console2.log("Post-deployment verification passed");
        console2.log("Admin:", admin);
        console2.log("GoldToken:", goldToken);
        console2.log("GovernanceToken:", governanceToken);
        console2.log("Vault proxy:", vaultProxy);
        console2.log("NFT:", nft);
        console2.log("AMM:", amm);
        console2.log("Oracle:", oracle);
    }
}
