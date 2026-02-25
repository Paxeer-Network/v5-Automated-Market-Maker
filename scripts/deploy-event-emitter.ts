import { ethers } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Deploy EventEmitter and wire it to the Diamond.
 * Run after main deploy: npx hardhat run scripts/deploy-event-emitter.ts --network paxeer-network
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  // Load deployment addresses
  const deployFile = path.join(
    __dirname,
    '..',
    'deployments',
    `paxeer-network-${Number(network.chainId)}.json`,
  );
  if (!fs.existsSync(deployFile)) {
    console.error('No deployment file found. Run deploy.ts first.');
    process.exit(1);
  }
  const deployment = JSON.parse(fs.readFileSync(deployFile, 'utf8'));
  const diamondAddr = deployment.contracts.Diamond;

  console.log('═'.repeat(60));
  console.log('  Deploy EventEmitter');
  console.log('═'.repeat(60));
  console.log(`  Network:  ${network.name} (chainId: ${network.chainId})`);
  console.log(`  Diamond:  ${diamondAddr}`);
  console.log('');

  // Deploy EventEmitter
  const EventEmitter = await ethers.getContractFactory('EventEmitter');
  const eventEmitter = await EventEmitter.deploy(diamondAddr);
  await eventEmitter.waitForDeployment();
  console.log(`  EventEmitter deployed: ${eventEmitter.target}`);

  // Wire EventEmitter into Diamond via PoolFacet.setEventEmitter
  const pool = await ethers.getContractAt('PoolFacet', diamondAddr);
  const tx = await pool.setEventEmitter(eventEmitter.target);
  await tx.wait();
  console.log(`  EventEmitter wired to Diamond ✅`);

  // Update deployment file
  deployment.contracts.EventEmitter = eventEmitter.target;
  fs.writeFileSync(
    deployFile,
    JSON.stringify(deployment, (_, v) => (typeof v === 'bigint' ? v.toString() : v), 2),
  );
  console.log(`  Deployment file updated`);

  console.log('\n' + '═'.repeat(60));
  console.log('  EventEmitter Ready!');
  console.log('═'.repeat(60));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
