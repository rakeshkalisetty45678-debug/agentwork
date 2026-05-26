/**
 * AgentWork — Deploy Script
 * Deploys AgentWork.sol to Somnia Testnet
 *
 * Usage:
 *   npm install
 *   export DEPLOYER_PRIVATE_KEY=0xyourprivatekey
 *   node scripts/deploy.js
 */

const { ethers } = require("ethers");
const fs         = require("fs");
const path       = require("path");

const SOMNIA_RPC     = "https://dream-rpc.somnia.network";
const SOMNIA_CHAINID = 50312;

async function deploy() {
  console.log("\n🚀 Deploying AgentWork to Somnia Agentic L1...\n");

  const provider = new ethers.JsonRpcProvider(SOMNIA_RPC);
  const network  = await provider.getNetwork();

  if (Number(network.chainId) !== SOMNIA_CHAINID) {
    throw new Error(`Wrong network! Expected Somnia (50312), got ${network.chainId}`);
  }

  const wallet  = new ethers.Wallet(process.env.DEPLOYER_PRIVATE_KEY, provider);
  const balance = await provider.getBalance(wallet.address);

  console.log(`📍 Deployer : ${wallet.address}`);
  console.log(`💰 Balance  : ${ethers.formatEther(balance)} STT`);
  console.log(`🌐 Network  : Somnia Testnet (Chain ID: ${SOMNIA_CHAINID})\n`);

  if (balance === 0n) {
    console.error("❌ Insufficient STT balance!");
    console.error("   Get testnet STT from: https://somnia-testnet.socialscan.io/faucet");
    process.exit(1);
  }

  // Read compiled contract (use hardhat or solc to compile first)
  // For now, log instructions
  console.log("📋 To deploy:");
  console.log("   1. Install Hardhat: npm install --save-dev hardhat");
  console.log("   2. Run: npx hardhat compile");
  console.log("   3. Run: npx hardhat run scripts/deploy.js --network somnia");
  console.log("\n📋 Hardhat config for Somnia:");
  console.log(`
  networks: {
    somnia: {
      url: "https://dream-rpc.somnia.network",
      chainId: 50312,
      accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    }
  }
  `);
}

deploy().catch(console.error);
