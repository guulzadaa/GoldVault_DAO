# GoldVault DAO Security Audit Report

## 1. Project Overview

GoldVault DAO is an RWA tokenization platform for tokenized gold. The system includes ERC-20 asset tokens, ERC-4626 vault logic, governance tokens, oracle integration, AMM logic, certificate NFTs, upgradeable vault contracts, and deployment scripts.

This audit focuses on the security, testing, oracle integration, deployment, and CI pipeline components.

## 2. Scope

The audit covered the following contracts:

- `GoldToken.sol`
- `GovernanceToken.sol`
- `GoldVaultV1.sol`
- `GoldVaultV2.sol`
- `GoldPriceOracle.sol`
- `GoldAMM.sol`
- `GoldCertificateNFT.sol`
- `VaultFactory.sol`
- `security-case-studies/ReentrancyVulnerableVault.sol`
- `security-case-studies/ReentrancyFixedVault.sol`
- `security-case-studies/AccessControlVulnerableToken.sol`
- `security-case-studies/AccessControlFixedToken.sol`

## 3. Tools Used

- Foundry
- Forge unit tests
- Forge fuzz tests
- Forge invariant tests
- Forge fork tests
- Forge coverage
- Slither
- GitHub Actions CI
- Arbitrum Sepolia deployment verification

## 4. Test Summary

The project includes:

- Unit tests
- Fuzz tests
- Invariant tests
- Fork tests
- Vulnerability case study tests
- Post-deployment verification script

Final local coverage result:

| Metric | Coverage |
|---|---|
| Lines | 95.45% |
| Statements | 90.99% |
| Functions | 92.86% |

The project satisfies the requirement of at least 90% coverage.

## 5. Slither Summary

Slither was executed with the following command:

```bash
slither . --filter-paths "lib|test|src/security-case-studies"
```

Result:

High severity issues: 0
Medium severity issues: 0
Low / Informational issues: present and documented below
## 6. Findings
Finding 1: Divide before multiply in GoldAMM

Severity: Informational / Low

Slither reported divide-before-multiply behavior in GoldAMM.addLiquidity.

Explanation:

The AMM uses reserve ratio calculations to determine optimal token amounts and liquidity shares. This is expected behavior in AMM-style liquidity logic. Rounding is acceptable because the contract checks minimum amounts using slippage protection.

Status: Accepted

Mitigation:

The contract includes slippage parameters:

amount0Min
amount1Min

These reduce the risk of unexpected rounding loss.

Finding 2: Timestamp usage in GoldPriceOracle

Severity: Informational / Low

Slither reported timestamp usage in the oracle staleness check.

Explanation:

block.timestamp is used to check whether the Chainlink oracle price is stale:

block.timestamp - updatedAt > stalePeriod

This is standard behavior for oracle freshness validation.

Status: Accepted

Mitigation:

The contract includes a configurable stalePeriod, and stale oracle data causes the transaction to revert.

Finding 3: Assembly usage in GasBenchmark

Severity: Informational

Slither reported inline assembly usage in GasBenchmark.sol.

Explanation:

This contract is intentionally included to compare pure Solidity and Yul assembly gas usage. It is not part of the critical protocol flow.

Status: Accepted

Mitigation:

Assembly functions are covered by tests comparing their output against pure Solidity implementations.

Finding 4: Benign reentrancy warning in VaultFactory

Severity: Informational / Low

Slither reported benign reentrancy patterns in VaultFactory.deployVaultProxy and deployVaultProxyDeterministic.

Explanation:

The warning appears because the factory deploys a new proxy contract and then updates internal arrays and emits events. This is not a user fund transfer function and does not expose protocol funds.

Status: Accepted

Mitigation:

Factory functions are protected by DEPLOYER_ROLE. The deployed contract address is pushed only after deployment succeeds.

Finding 5: Naming convention warnings

Severity: Informational

Slither reported naming convention issues such as:

__gap
__gapV2
parameters with leading underscores

Explanation:

The __gap pattern is standard in upgradeable OpenZeppelin-style contracts to preserve storage layout for future upgrades.

Status: Accepted

Finding 6: Unused state variable __gapV2

Severity: Informational

Slither reported that __gapV2 is unused.

Explanation:

This is intentional. Storage gaps are reserved for future upgradeable contract versions.

Status: Accepted

Finding 7: Dead code warning in GoldCertificateNFT

Severity: Informational

Slither reported _increaseBalance as unused.

Explanation:

This function is part of the required override structure for OpenZeppelin ERC721 extensions.

Status: Accepted

## 7. Vulnerability Case Studies
Reentrancy Case Study

A vulnerable vault contract was created to demonstrate a reentrancy attack.

Result:

Vulnerable version: attack succeeds
Fixed version: attack is blocked

Mitigation used:

Checks-Effects-Interactions pattern
ReentrancyGuard
Access Control Case Study

A vulnerable token contract was created to demonstrate missing access control.

Result:

Vulnerable version: anyone can mint
Fixed version: only authorized minters can mint

Mitigation used:

AccessControl
role-based minting
## 8. Security Practices Applied

The project applies the following security practices:

AccessControl for role-based permissions
Ownable where single-owner control is appropriate
ReentrancyGuard in sensitive flow examples
SafeERC20 for token transfers
CEI pattern in fixed vulnerability examples
Chainlink oracle staleness checks
No tx.origin
No unsafe transfer / send ETH usage
UUPS upgradeability with restricted upgrader role
Post-deployment verification script
GitHub Actions CI pipeline
## 9. Deployment Verification

The project was deployed to Arbitrum Sepolia.

Post-deployment verification confirmed:

GoldToken admin role
GovernanceToken admin role
Vault admin role
Vault upgrader role
Vault cap manager role
Vault upgraded to V2
NFT admin role
AMM owner
Oracle owner

Result:

Post-deployment verification passed
## 10. CI Pipeline

GitHub Actions CI includes:

Foundry installation
Dependency installation
Forge formatting check
Contract build
Unit, fuzz, invariant, and fork tests
Coverage
Slither analysis

Final CI status:

```bash
Passed
```

## 11. Final Audit Result
The project satisfies the security and testing requirements:

| Requirement                  | Status |
| ---------------------------- | ------ |
| Unit tests                   | Passed |
| Fuzz tests                   | Passed |
| Invariant tests              | Passed |
| Fork tests                   | Passed |
| Coverage ≥ 90%               | Passed |
| Slither zero High            | Passed |
| Slither zero Medium          | Passed |
| Deployment script            | Passed |
| Post-deployment verification | Passed |
| GitHub Actions CI            | Passed |

## 12. Conclusion

GoldVault DAO passed the required security, testing, deployment, and CI checks. Slither reported only low and informational findings, which were reviewed and documented. No high or medium severity vulnerabilities were found in the final audited scope.
