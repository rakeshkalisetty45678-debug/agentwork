const hre = require("hardhat");

async function main() {
    console.log("Deploying AgentWork contracts to Somnia Mainnet...");
    
    // Deploy AgentRegistry
    const AgentRegistry = await hre.ethers.getContractFactory("AgentRegistry");
    const agentRegistry = await AgentRegistry.deploy();
    await agentRegistry.waitForDeployment();
    console.log("AgentRegistry deployed to:", await agentRegistry.getAddress());
    
    // Deploy Escrow
    const Escrow = await hre.ethers.getContractFactory("Escrow");
    const escrow = await Escrow.deploy();
    await escrow.waitForDeployment();
    console.log("Escrow deployed to:", await escrow.getAddress());
    
    // Deploy Reputation
    const Reputation = await hre.ethers.getContractFactory("Reputation");
    const reputation = await Reputation.deploy();
    await reputation.waitForDeployment();
    console.log("Reputation deployed to:", await reputation.getAddress());
    
    console.log("\n✅ All contracts deployed successfully to Somnia Mainnet!");
    console.log("\nContract Addresses:");
    console.log("AgentRegistry:", await agentRegistry.getAddress());
    console.log("Escrow:", await escrow.getAddress());
    console.log("Reputation:", await reputation.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
