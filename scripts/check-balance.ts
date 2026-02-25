import { ethers } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  const balance = await ethers.provider.getBalance(deployer.address);
  const network = await ethers.provider.getNetwork();
  console.log(`Network:  ${network.name} (chainId: ${network.chainId})`);
  console.log(`Address:  ${deployer.address}`);
  console.log(`Balance:  ${ethers.formatEther(balance)} ETH`);
}

main().catch(console.error);
