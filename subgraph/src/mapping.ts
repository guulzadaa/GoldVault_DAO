import { VaultDeposit, VaultWithdraw, Delegate, Proposal, Vote } from "../generated/schema";

import {
  Deposit as DepositEvent,
  Withdraw as WithdrawEvent
} from "../generated/GoldVault/GoldVault";

import {
  DelegateChanged as DelegateChangedEvent
} from "../generated/GovernanceToken/GovernanceToken";

import {
  ProposalCreated as ProposalCreatedEvent,
  VoteCast as VoteCastEvent
} from "../generated/GoldGovernor/GoldGovernor";

export function handleDeposit(event: DepositEvent): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();

  let entity = new VaultDeposit(id);
  entity.sender = event.params.sender;
  entity.owner = event.params.owner;
  entity.assets = event.params.assets;
  entity.shares = event.params.shares;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleWithdraw(event: WithdrawEvent): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();

  let entity = new VaultWithdraw(id);
  entity.sender = event.params.sender;
  entity.receiver = event.params.receiver;
  entity.owner = event.params.owner;
  entity.assets = event.params.assets;
  entity.shares = event.params.shares;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleDelegateChanged(event: DelegateChangedEvent): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();

  let entity = new Delegate(id);
  entity.delegator = event.params.delegator;
  entity.fromDelegate = event.params.fromDelegate;
  entity.toDelegate = event.params.toDelegate;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleProposalCreated(event: ProposalCreatedEvent): void {
  let id = event.params.proposalId.toString();

  let entity = new Proposal(id);
  entity.proposalId = event.params.proposalId;
  entity.proposer = event.params.proposer;
  entity.description = event.params.description;
  entity.startBlock = event.params.voteStart;
  entity.endBlock = event.params.voteEnd;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}

export function handleVoteCast(event: VoteCastEvent): void {
  let id = event.transaction.hash.toHexString() + "-" + event.logIndex.toString();

  let entity = new Vote(id);
  entity.proposalId = event.params.proposalId;
  entity.voter = event.params.voter;
  entity.support = event.params.support;
  entity.weight = event.params.weight;
  entity.reason = event.params.reason;
  entity.blockNumber = event.block.number;
  entity.timestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}