// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GoldVaultV1} from "./GoldVaultV1.sol";

contract GoldVaultV2 is GoldVaultV1 {
    bytes32 public constant CAP_MANAGER_ROLE = keccak256("CAP_MANAGER_ROLE");

    uint256 public vaultDepositCap;
    uint256 public perUserDepositCap;
    mapping(address => uint256) public userTotalDeposited;

    uint256[47] private __gapV2;

    error DepositCapExceeded();
    error UserDepositCapExceeded();
    error FeeTooHigh();

    event VaultDepositCapUpdated(uint256 newCap);
    event PerUserDepositCapUpdated(uint256 newCap);

    function initializeV2(uint256 _vaultDepositCap, uint256 _perUserDepositCap, address capManager)
        external
        reinitializer(2)
    {
        if (capManager == address(0)) revert ZeroAddress();
        vaultDepositCap = _vaultDepositCap;
        perUserDepositCap = _perUserDepositCap;
        _grantRole(CAP_MANAGER_ROLE, capManager);
    }

    function setVaultDepositCap(uint256 _cap) external onlyRole(CAP_MANAGER_ROLE) {
        vaultDepositCap = _cap;
        emit VaultDepositCapUpdated(_cap);
    }

    function setPerUserDepositCap(uint256 _cap) external onlyRole(CAP_MANAGER_ROLE) {
        perUserDepositCap = _cap;
        emit PerUserDepositCapUpdated(_cap);
    }

    function maxDeposit(address user) public view override returns (uint256) {
        uint256 _vaultCap = vaultDepositCap;
        uint256 _userCap = perUserDepositCap;

        uint256 vaultSpace = _vaultCap == 0
            ? type(uint256).max
            : (_vaultCap > totalAssets() ? _vaultCap - totalAssets() : 0);

        uint256 userSpace = _userCap == 0
            ? type(uint256).max
            : (_userCap > userTotalDeposited[user] ? _userCap - userTotalDeposited[user] : 0);

        uint256 baseMax = super.maxDeposit(user);
        uint256 capMin = vaultSpace < userSpace ? vaultSpace : userSpace;
        return capMin < baseMax ? capMin : baseMax;
    }

    function maxMint(address user) public view override returns (uint256) {
        uint256 maxAssets = maxDeposit(user);
        return convertToShares(maxAssets);
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
    {
        uint256 _vaultCap = vaultDepositCap;
        uint256 _userCap = perUserDepositCap;

        if (_vaultCap != 0 && totalAssets() + assets > _vaultCap) revert DepositCapExceeded();
        if (_userCap != 0 && userTotalDeposited[receiver] + assets > _userCap) {
            revert UserDepositCapExceeded();
        }

        userTotalDeposited[receiver] += assets;
        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        uint256 deposited = userTotalDeposited[owner];
        userTotalDeposited[owner] = assets >= deposited ? 0 : deposited - assets;
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function version() external pure override returns (string memory) {
        return "2";
    }
}
