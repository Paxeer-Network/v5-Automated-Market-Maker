import { ethers } from 'hardhat';
import { deployDiamond } from './libraries/diamond';
import * as fs from 'fs';
import * as path from 'path';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('='.repeat(60));
  console.log('v5-ASAMM Protocol Deployment');
  console.log('='.repeat(60));
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Network:  ${(await ethers.provider.getNetwork()).name}`);
  console.log(
    `Balance:  ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`,
  );
  console.log('');

  // ── Step 1: Deploy Diamond with all facets ──
  const facetNames = [
    'DiamondLoupeFacet',
    'OwnershipFacet',
    'PoolFacet',
    'SwapFacet',
    'LiquidityFacet',
    'FeeFacet',
    'OracleFacet',
    'OraclePegFacet',
    'OrderFacet',
    'RewardFacet',
    'FlashLoanFacet',
  ];

  const initArgs = {
    treasury: deployer.address,
    flashLoanFeeBps: 9, // 0.09%
    maxOrdersPerPool: 100,
    defaultOrderTTL: 30 * 24 * 60 * 60, // 30 days
    minOrderSize: ethers.parseEther('0.001'),
    keeperBountyBps: 1, // 0.01%
    epochDuration: 7 * 24 * 60 * 60, // 7 days
    minSwapsForRebate: 5,
    maxTradeSizeBps: 500, // 5% of pool
  };

  const { diamond, facets } = await deployDiamond(deployer.address, facetNames, initArgs);

  // ── Step 2: Deploy Periphery contracts ──
  console.log('\nDeploying Periphery...\n');

  const PositionDescriptor = await ethers.getContractFactory('PositionDescriptor');
  const positionDescriptor = await PositionDescriptor.deploy(diamond.target);
  await positionDescriptor.waitForDeployment();
  console.log(`  PositionDescriptor: ${positionDescriptor.target}`);

  const PositionManager = await ethers.getContractFactory('PositionManager');
  const positionManager = await PositionManager.deploy(diamond.target, positionDescriptor.target);
  await positionManager.waitForDeployment();
  console.log(`  PositionManager:    ${positionManager.target}`);

  const Router = await ethers.getContractFactory('Router');
  const router = await Router.deploy(diamond.target);
  await router.waitForDeployment();
  console.log(`  Router:             ${router.target}`);

  const Quoter = await ethers.getContractFactory('Quoter');
  const quoter = await Quoter.deploy(diamond.target);
  await quoter.waitForDeployment();
  console.log(`  Quoter:             ${quoter.target}`);

  const OrderManager = await ethers.getContractFactory('OrderManager');
  const orderManager = await OrderManager.deploy(diamond.target);
  await orderManager.waitForDeployment();
  console.log(`  OrderManager:       ${orderManager.target}`);

  // ── Step 3: Save deployment addresses ──
  const deployment = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: Number((await ethers.provider.getNetwork()).chainId),
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      Diamond: diamond.target,
      ...Object.fromEntries(
        Object.entries(facets).map(([name, contract]) => [name, contract.target]),
      ),
      PositionDescriptor: positionDescriptor.target,
      PositionManager: positionManager.target,
      Router: router.target,
      Quoter: quoter.target,
      OrderManager: orderManager.target,
    },
    initArgs,
  };

  const deployDir = path.join(__dirname, '..', 'deployments');
  if (!fs.existsSync(deployDir)) fs.mkdirSync(deployDir, { recursive: true });

  const filename = `${deployment.network}-${deployment.chainId}.json`;
  fs.writeFileSync(
    path.join(deployDir, filename),
    JSON.stringify(deployment, (_, v) => (typeof v === 'bigint' ? v.toString() : v), 2),
  );

  console.log('\n' + '='.repeat(60));
  console.log('Deployment Complete!');
  console.log('='.repeat(60));
  console.log(`\nAddresses saved to: deployments/${filename}`);
  console.log(`\nDiamond: ${diamond.target}`);
  console.log(`Router:  ${router.target}`);
  console.log(`Quoter:  ${quoter.target}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
