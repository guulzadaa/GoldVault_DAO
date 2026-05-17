// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GoldToken} from "./GoldToken.sol";
import {GovernanceToken} from "./GovernanceToken.sol";
import {GoldVaultV1} from "./GoldVaultV1.sol";
import {GoldCertificateNFT} from "./GoldCertificateNFT.sol";
import {GoldAMM} from "./GoldAMM.sol";

contract VaultFactory is AccessControl {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    address[] public deployedTokens;
    address[] public deployedVaults;
    address[] public deployedNFTs;
    address[] public deployedAMMs;

    error ZeroAddress();
    error ZeroImplementation();

    event GoldTokenDeployed(address indexed token, bool deterministic, bytes32 salt);
    event GovernanceTokenDeployed(address indexed token, bool deterministic, bytes32 salt);
    event VaultDeployed(address indexed proxy, bool deterministic, bytes32 salt);
    event NFTDeployed(address indexed nft, bool deterministic, bytes32 salt);
    event AMMDeployed(address indexed amm, address indexed token0, address indexed token1);

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(DEPLOYER_ROLE, admin);
    }

    // ─── GoldToken ───────────────────────────────────────────────────────────

    function deployGoldToken(address admin)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address token)
    {
        if (admin == address(0)) revert ZeroAddress();
        token = address(new GoldToken(admin));
        deployedTokens.push(token);
        emit GoldTokenDeployed(token, false, bytes32(0));
    }

    function deployGoldTokenDeterministic(address admin, bytes32 salt)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address token)
    {
        if (admin == address(0)) revert ZeroAddress();
        token = address(new GoldToken{salt: salt}(admin));
        deployedTokens.push(token);
        emit GoldTokenDeployed(token, true, salt);
    }

    // ─── GovernanceToken ─────────────────────────────────────────────────────

    function deployGovernanceToken(address admin)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address token)
    {
        if (admin == address(0)) revert ZeroAddress();
        token = address(new GovernanceToken(admin));
        deployedTokens.push(token);
        emit GovernanceTokenDeployed(token, false, bytes32(0));
    }

    function deployGovernanceTokenDeterministic(address admin, bytes32 salt)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address token)
    {
        if (admin == address(0)) revert ZeroAddress();
        token = address(new GovernanceToken{salt: salt}(admin));
        deployedTokens.push(token);
        emit GovernanceTokenDeployed(token, true, salt);
    }

    // ─── GoldVault Proxy ─────────────────────────────────────────────────────

    function deployVaultProxy(address implementation, address asset, address admin)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address proxy)
    {
        if (implementation == address(0)) revert ZeroImplementation();
        if (asset == address(0) || admin == address(0)) revert ZeroAddress();
        bytes memory initData = abi.encodeCall(GoldVaultV1.initialize, (asset, admin));
        proxy = address(new ERC1967Proxy(implementation, initData));
        deployedVaults.push(proxy);
        emit VaultDeployed(proxy, false, bytes32(0));
    }

    function deployVaultProxyDeterministic(
        address implementation,
        address asset,
        address admin,
        bytes32 salt
    ) external onlyRole(DEPLOYER_ROLE) returns (address proxy) {
        if (implementation == address(0)) revert ZeroImplementation();
        if (asset == address(0) || admin == address(0)) revert ZeroAddress();
        bytes memory initData = abi.encodeCall(GoldVaultV1.initialize, (asset, admin));
        proxy = address(new ERC1967Proxy{salt: salt}(implementation, initData));
        deployedVaults.push(proxy);
        emit VaultDeployed(proxy, true, salt);
    }

    // ─── GoldCertificateNFT ──────────────────────────────────────────────────

    function deployNFT(address admin) external onlyRole(DEPLOYER_ROLE) returns (address nft) {
        if (admin == address(0)) revert ZeroAddress();
        nft = address(new GoldCertificateNFT(admin));
        deployedNFTs.push(nft);
        emit NFTDeployed(nft, false, bytes32(0));
    }

    function deployNFTDeterministic(address admin, bytes32 salt)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address nft)
    {
        if (admin == address(0)) revert ZeroAddress();
        nft = address(new GoldCertificateNFT{salt: salt}(admin));
        deployedNFTs.push(nft);
        emit NFTDeployed(nft, true, salt);
    }

    // ─── GoldAMM ─────────────────────────────────────────────────────────────

    function deployAMM(address token0, address token1, address ammOwner)
        external
        onlyRole(DEPLOYER_ROLE)
        returns (address amm)
    {
        if (token0 == address(0) || token1 == address(0) || ammOwner == address(0)) {
            revert ZeroAddress();
        }
        amm = address(new GoldAMM(token0, token1, ammOwner));
        deployedAMMs.push(amm);
        emit AMMDeployed(amm, token0, token1);
    }

    // ─── Address Prediction ──────────────────────────────────────────────────

    function predictGoldTokenAddress(address admin, bytes32 salt) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(abi.encodePacked(type(GoldToken).creationCode, abi.encode(admin)))
            )
        );
        return address(uint160(uint256(hash)));
    }

    function predictVaultProxyAddress(
        address implementation,
        address asset,
        address admin,
        bytes32 salt
    ) external view returns (address) {
        bytes memory initData = abi.encodeCall(GoldVaultV1.initialize, (asset, admin));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode, abi.encode(implementation, initData)
                    )
                )
            )
        );
        return address(uint160(uint256(hash)));
    }

    function predictNFTAddress(address admin, bytes32 salt) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(
                    abi.encodePacked(type(GoldCertificateNFT).creationCode, abi.encode(admin))
                )
            )
        );
        return address(uint160(uint256(hash)));
    }

    // ─── View Helpers ────────────────────────────────────────────────────────

    function deployedTokensCount() external view returns (uint256) {
        return deployedTokens.length;
    }

    function deployedVaultsCount() external view returns (uint256) {
        return deployedVaults.length;
    }

    function deployedNFTsCount() external view returns (uint256) {
        return deployedNFTs.length;
    }

    function deployedAMMsCount() external view returns (uint256) {
        return deployedAMMs.length;
    }
}
