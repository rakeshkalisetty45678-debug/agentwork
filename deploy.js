require("dotenv").config();

const { ethers } = require("ethers");

const SOMNIA_RPC =
  process.env.SOMNIA_RPC_URL ||
  "https://dream-rpc.somnia.network";

const SOMNIA_CHAIN_ID = 50312;

async function deploy() {
  console.log("\n╔══════════════════════════════════════╗");
  console.log("║      AgentWork Deployment Tool      ║");
  console.log("╚══════════════════════════════════════╝\n");

  const privateKey = process.env.DEPLOYER_PRIVATE_KEY;

  if (!privateKey) {
    throw new Error(
      "DEPLOYER_PRIVATE_KEY missing in .env"
    );
  }

  const provider = new ethers.JsonRpcProvider(
    SOMNIA_RPC
  );

  const network = await provider.getNetwork();

  if (
    Number(network.chainId) !== SOMNIA_CHAIN_ID
  ) {
    throw new Error(
      `Wrong network. Expected ${SOMNIA_CHAIN_ID}, got ${network.chainId}`
    );
  }

  const wallet = new ethers.Wallet(
    privateKey,
    provider
  );

  const balance = await provider.getBalance(
    wallet.address
  );

  console.log(`📍 Wallet : ${wallet.address}`);
  console.log(
    `💰 Balance : ${ethers.formatEther(balance)} STT`
  );
  console.log(`🌐 Network : Somnia Agentic L1`);
  console.log(`⚡ RPC : ${SOMNIA_RPC}\n`);

  if (balance <= 0n) {
    throw new Error(
      "Wallet has no STT for deployment"
    );
  }

  console.log("✅ Environment Verified");
  console.log("✅ Wallet Connected");
  console.log("✅ Somnia RPC Connected");
  console.log("✅ Ready To Deploy\n");

  console.log("Next Steps:");
  console.log("1. Compile contract");
  console.log("   npx hardhat compile\n");

  console.log("2. Deploy contract");
  console.log(
    "   npx hardhat run scripts/deploy.js --network somnia\n"
  );

  console.log("3. Save deployed address");
  console.log(
    "   CONTRACT_ADDRESS=0xYourContractAddress\n"
  );

  console.log(
    "🚀 AgentWork deployment configuration complete."
  );
}

deploy().catch((err) => {
  console.error("\n❌ Deployment Failed");
  console.error(err.message);
  process.exit(1);
});
