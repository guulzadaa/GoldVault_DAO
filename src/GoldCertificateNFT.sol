// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721Enumerable
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract GoldCertificateNFT is ERC721Enumerable, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 private _nextTokenId;

    struct CertificateData {
        uint256 goldAmountWei;
        uint256 issuedAt;
        address issuer;
    }

    mapping(uint256 => CertificateData) public certificates;

    error ZeroAddress();
    error ZeroAmount();
    error NotOwnerOrApproved();

    event CertificateMinted(address indexed to, uint256 indexed tokenId, uint256 goldAmountWei);
    event CertificateBurned(uint256 indexed tokenId);

    constructor(address admin) ERC721("GoldVault Certificate", "GVCERT") {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function mint(address to, uint256 goldAmountWei)
        external
        onlyRole(MINTER_ROLE)
        whenNotPaused
        returns (uint256 tokenId)
    {
        if (to == address(0)) revert ZeroAddress();
        if (goldAmountWei == 0) revert ZeroAmount();
        tokenId = _nextTokenId++;
        certificates[tokenId] = CertificateData({
            goldAmountWei: goldAmountWei, issuedAt: block.timestamp, issuer: msg.sender
        });
        _safeMint(to, tokenId);
        emit CertificateMinted(to, tokenId, goldAmountWei);
    }

    function burn(uint256 tokenId) external onlyRole(MINTER_ROLE) {
        delete certificates[tokenId];
        _burn(tokenId);
        emit CertificateBurned(tokenId);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Enumerable)
        returns (address)
    {
        _requireNotPaused();
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
