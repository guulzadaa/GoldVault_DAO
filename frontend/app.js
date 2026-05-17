const ARBITRUM_SEPOLIA_CHAIN_ID = "0x66eee";

const CONTRACTS = {
  goldToken: "0x0e5235E22eFF248a2be4276D34Eebf64b5610DB7",
  governanceToken: "0xd2e1c943fBf919f0B123C1e8A2cBb1500c9c1538",
  vault: "0x2a0c1229d20f24eA53dB253E7925ebF43bcb6Cd9",
  governor: "0x823792C4D55a68006AfaAc477C5DCD470e2Ca6D2",
};

const ERC20_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function approve(address spender, uint256 amount) returns (bool)"
];

const GOVERNANCE_TOKEN_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
  "function delegates(address account) view returns (address)",
  "function getVotes(address account) view returns (uint256)",
  "function delegate(address delegatee)"
];

const VAULT_ABI = [
  "function balanceOf(address) view returns (uint256)",
  "function deposit(uint256 assets, address receiver)",
  "function withdraw(uint256 assets, address receiver, address owner)"
];

const GOVERNOR_ABI = [
  "function state(uint256 proposalId) view returns (uint8)",
  "function castVote(uint256 proposalId, uint8 support)"
];

let provider;
let signer;
let account;

function setStatus(message, type = "") {
  const el = document.getElementById("statusMessage");
  el.innerText = message;
  el.className = "status " + type;
}

async function connectWallet() {
  try {
    if (!window.ethereum) {
      alert("Please install MetaMask");
      return;
    }

    provider = new ethers.BrowserProvider(window.ethereum);

    const accounts = await window.ethereum.request({
      method: "eth_requestAccounts",
    });

    account = accounts[0];
    signer = await provider.getSigner();

    document.getElementById("account").innerText = account;

    await checkNetwork();
    await loadBalances();

    setStatus("Wallet connected successfully", "success");
  } catch (error) {
    setStatus("Wallet connection failed", "error");
    console.error(error);
  }
}

async function checkNetwork() {
  const chainId = await window.ethereum.request({
    method: "eth_chainId",
  });

  document.getElementById("chainId").innerText = chainId;

  if (chainId.toLowerCase() !== ARBITRUM_SEPOLIA_CHAIN_ID.toLowerCase()) {
    document.getElementById("networkWarning").classList.remove("hidden");
    return false;
  }

  document.getElementById("networkWarning").classList.add("hidden");
  return true;
}

async function switchToArbitrumSepolia() {
  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: ARBITRUM_SEPOLIA_CHAIN_ID }],
    });

    await checkNetwork();
    setStatus("Switched to Arbitrum Sepolia", "success");

    if (account) {
      await loadBalances();
    }
  } catch (error) {
    setStatus("Failed to switch network", "error");
    console.error(error);
  }
}

async function loadBalances() {
  try {
    const isCorrectNetwork = await checkNetwork();
    if (!isCorrectNetwork) return;

    const goldToken = new ethers.Contract(CONTRACTS.goldToken, ERC20_ABI, provider);
    const governanceToken = new ethers.Contract(CONTRACTS.governanceToken, GOVERNANCE_TOKEN_ABI, provider);
    const vault = new ethers.Contract(CONTRACTS.vault, VAULT_ABI, provider);

    const goldDecimals = await goldToken.decimals();
    const govDecimals = await governanceToken.decimals();

    const goldBalance = await goldToken.balanceOf(account);
    const govBalance = await governanceToken.balanceOf(account);
    const votingPower = await governanceToken.getVotes(account);
    const delegateAddress = await governanceToken.delegates(account);
    const vaultShares = await vault.balanceOf(account);

    document.getElementById("goldBalance").innerText =
      ethers.formatUnits(goldBalance, goldDecimals);

    document.getElementById("govBalance").innerText =
      ethers.formatUnits(govBalance, govDecimals);

    document.getElementById("votingPower").innerText =
      ethers.formatUnits(votingPower, govDecimals);

    document.getElementById("delegateAddress").innerText = delegateAddress;

    document.getElementById("vaultShares").innerText =
      ethers.formatUnits(vaultShares, 18);
  } catch (error) {
    setStatus("Failed to load balances. Check contract addresses.", "error");
    console.error(error);
  }
}

async function delegateVotes() {
  try {
    const governanceToken = new ethers.Contract(
      CONTRACTS.governanceToken,
      GOVERNANCE_TOKEN_ABI,
      signer
    );

    const tx = await governanceToken.delegate(account);
    setStatus("Delegation transaction sent...");
    await tx.wait();

    setStatus("Votes delegated successfully", "success");
    await loadBalances();
  } catch (error) {
    setStatus("Delegation failed or rejected", "error");
    console.error(error);
  }
}

async function deposit() {
  try {
    const amount = document.getElementById("depositInput").value;
    if (!amount || Number(amount) <= 0) {
      setStatus("Enter valid deposit amount", "error");
      return;
    }

    const parsedAmount = ethers.parseUnits(amount, 18);

    const goldToken = new ethers.Contract(CONTRACTS.goldToken, ERC20_ABI, signer);
    const vault = new ethers.Contract(CONTRACTS.vault, VAULT_ABI, signer);

    setStatus("Approving token...");
    const approveTx = await goldToken.approve(CONTRACTS.vault, parsedAmount);
    await approveTx.wait();

    setStatus("Depositing to vault...");
    const depositTx = await vault.deposit(parsedAmount, account);
    await depositTx.wait();

    setStatus("Deposit successful", "success");
    await loadBalances();
  } catch (error) {
    setStatus("Deposit failed. Check balance or approval.", "error");
    console.error(error);
  }
}

async function withdraw() {
  try {
    const amount = document.getElementById("withdrawInput").value;
    if (!amount || Number(amount) <= 0) {
      setStatus("Enter valid withdraw amount", "error");
      return;
    }

    const parsedAmount = ethers.parseUnits(amount, 18);

    const vault = new ethers.Contract(CONTRACTS.vault, VAULT_ABI, signer);

    setStatus("Withdrawing from vault...");
    const tx = await vault.withdraw(parsedAmount, account, account);
    await tx.wait();

    setStatus("Withdraw successful", "success");
    await loadBalances();
  } catch (error) {
    setStatus("Withdraw failed. Check vault shares.", "error");
    console.error(error);
  }
}

async function checkProposalState() {
  try {
    const proposalId = document.getElementById("proposalInput").value;

    if (!proposalId) {
      setStatus("Enter proposal ID", "error");
      return;
    }

    const governor = new ethers.Contract(
      CONTRACTS.governor,
      GOVERNOR_ABI,
      provider
    );

    const state = await governor.state(proposalId);

    const states = [
      "Pending",
      "Active",
      "Canceled",
      "Defeated",
      "Succeeded",
      "Queued",
      "Expired",
      "Executed",
    ];

    document.getElementById("proposalState").innerText = states[Number(state)];
    setStatus("Proposal state loaded", "success");
  } catch (error) {
    setStatus("Failed to load proposal state", "error");
    console.error(error);
  }
}

async function vote() {
  try {
    const proposalId = document.getElementById("proposalInput").value;

    if (!proposalId) {
      setStatus("Enter proposal ID", "error");
      return;
    }

    const governor = new ethers.Contract(
      CONTRACTS.governor,
      GOVERNOR_ABI,
      signer
    );

    setStatus("Voting...");
    const tx = await governor.castVote(proposalId, 1);
    await tx.wait();

    setStatus("Vote submitted successfully", "success");
    await checkProposalState();
  } catch (error) {
    setStatus("Vote failed or rejected", "error");
    console.error(error);
  }
}

document.getElementById("connectBtn").onclick = connectWallet;
document.getElementById("switchNetworkBtn").onclick = switchToArbitrumSepolia;
document.getElementById("delegateBtn").onclick = delegateVotes;
document.getElementById("depositBtn").onclick = deposit;
document.getElementById("withdrawBtn").onclick = withdraw;
document.getElementById("checkProposalBtn").onclick = checkProposalState;
document.getElementById("voteBtn").onclick = vote;

if (window.ethereum) {
  window.ethereum.on("chainChanged", () => {
    window.location.reload();
  });

  window.ethereum.on("accountsChanged", () => {
    window.location.reload();
  });
}