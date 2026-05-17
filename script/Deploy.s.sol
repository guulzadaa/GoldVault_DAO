// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {GoldToken} from "../src/GoldToken.sol";
import {GovernanceToken} from "../src/GovernanceToken.sol";
import {GoldVaultV1} from "../src/GoldVaultV1.sol";
import {GoldVaultV2} from "../src/GoldVaultV2.sol";
import {GoldCertificateNFT} from "../src/GoldCertificateNFT.sol";
import {GoldAMM} from "../src/GoldAMM.sol";
import {GoldPriceOracle} from "../src/GoldPriceOracle.sol";
// import {VaultFactory} from "../src/VaultFactory.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.addr(deployerPrivateKey);

        address priceFeed = vm.envAddress("PRICE_FEED");
        uint256 stalePeriod = vm.envOr("STALE_PERIOD", uint256(1 days));

        vm.startBroadcast(deployerPrivateKey);

        GoldToken goldToken = new GoldToken(admin);
        GovernanceToken governanceToken = new GovernanceToken(admin);

        GoldVaultV1 vaultV1Implementation = new GoldVaultV1();

        ERC1967Proxy vaultProxy = new ERC1967Proxy(
            address(vaultV1Implementation),
            abi.encodeCall(GoldVaultV1.initialize, (address(goldToken), admin))
        );

        GoldVaultV2 vaultV2Implementation = new GoldVaultV2();

        GoldVaultV1(address(vaultProxy))
            .upgradeToAndCall(
                address(vaultV2Implementation),
                abi.encodeCall(GoldVaultV2.initializeV2, (0, 0, admin))
            );

        GoldCertificateNFT certificateNFT = new GoldCertificateNFT(admin);

        GoldAMM amm = new GoldAMM(address(goldToken), address(governanceToken), admin);

        GoldPriceOracle oracle = new GoldPriceOracle(priceFeed, stalePeriod, admin);

        // VaultFactory factory = new VaultFactory(admin);

        vm.stopBroadcast();

        console2.log("GoldVault DAO deployment completed");
        console2.log("Admin:", admin);
        console2.log("GoldToken:", address(goldToken));
        console2.log("GovernanceToken:", address(governanceToken));
        console2.log("GoldVaultV1 implementation:", address(vaultV1Implementation));
        console2.log("GoldVaultV2 implementation:", address(vaultV2Implementation));
        console2.log("GoldVault proxy:", address(vaultProxy));
        console2.log("GoldCertificateNFT:", address(certificateNFT));
        console2.log("GoldAMM:", address(amm));
        console2.log("GoldPriceOracle:", address(oracle));
        // console2.log("VaultFactory:", address(factory));
    }
}
