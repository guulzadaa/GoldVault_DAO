Team Project: GoldVault DAO — RWA Tokenization Platform for Tokenized Gold

Team Member 1: Zukhra
Role: Smart Contract Core Developer
Responsibilities:
- GoldToken ERC-20 implementation
- ERC-4626 GoldVault implementation
- GovernanceToken ERC20Votes/ERC20Permit
- UUPS upgradeability V1 → V2
- Factory with CREATE and CREATE2
- Yul assembly gas optimization
- Smart contract architecture documentation

Team Member 2: Gulzada
Role: Security, Testing and Deployment Engineer
Responsibilities:
- Chainlink price oracle integration with staleness check
- Unit, fuzz, invariant and fork tests
- Reentrancy and access-control vulnerability case studies
- Slither analysis and security audit report
- GitHub Actions CI pipeline
- L2 deployment and contract verification
- Gas comparison report

Team Member 3: Inabat
Role: Governance, Frontend and Indexing Developer
Responsibilities:
- OpenZeppelin Governor and Timelock setup
- Full propose → vote → queue → execute lifecycle
- The Graph subgraph with entities and GraphQL queries
- Frontend dApp with MetaMask connection
- Deposit, withdraw, delegate and vote UI
- README and final presentation

## DAO Governance

GoldVault DAO uses OpenZeppelin Governor and TimelockController to manage protocol decisions through decentralized voting.

### Governance Parameters

- Voting delay: 1 day
- Voting period: 1 week
- Quorum: 4%
- Proposal threshold: 0
- Timelock delay: 1 day

### Governance Lifecycle

1. Token holders delegate their voting power.
2. A proposal is created through the Governor contract.
3. Token holders vote For, Against, or Abstain.
4. If the proposal succeeds, it is queued in the TimelockController.
5. After the timelock delay, the proposal can be executed.

### Deployed Governance Contracts

Network: Arbitrum Sepolia

- TimelockController: `0xfDd58bfcD9e73577095cC4Ba3b2Ce4a4456bf6b3`
- GoldGovernor: `0x823792C4D55a68006AfaAc477C5DCD470e2Ca6D2`

### Governance Test

The governance lifecycle is tested in:

`test/GoldGovernor.t.sol`

The test covers:

- delegate
- propose
- vote
- queue
- execute

## Frontend

The frontend allows users to interact with the GoldVault DAO protocol through MetaMask.

### Features

- Wallet connection
- Arbitrum Sepolia network detection
- Gold token balance display
- Governance token balance display
- Voting power display
- Delegate voting power
- Deposit GOLD into vault
- Withdraw GOLD from vault
- View vault shares
- Check proposal state
- Vote on governance proposals

### Tech Stack

- HTML
- CSS
- JavaScript
- ethers.js
- MetaMask

## The Graph Subgraph

The project includes a subgraph for indexing GoldVault DAO protocol events.

### Indexed Events

- Vault Deposit
- Vault Withdraw
- Governance Token DelegateChanged
- Governor ProposalCreated
- Governor VoteCast

### Entities

- VaultDeposit
- VaultWithdraw
- Delegate
- Proposal
- Vote

### GraphQL Queries

Example queries are located in:

`subgraph/queries/example-queries.graphql`

The subgraph supports queries for:

- Recent deposits
- Recent withdrawals
- Delegate changes
- Governance proposals
- Votes

### Build Commands

```bash
cd subgraph
npm install
npm run codegen
npm run build