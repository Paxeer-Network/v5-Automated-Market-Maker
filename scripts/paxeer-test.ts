import { ethers } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Paxeer Live Test — tests against the ALREADY-DEPLOYED Diamond.
 * Deploys mock tokens, creates a pool, adds liquidity, swaps, verifies fees.
 *
 * Usage: npx hardhat run scripts/paxeer-test.ts --network paxeer-network
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  // Load existing deployment
  const deployFile = path.join(
    __dirname,
    '..',
    'deployments',
    `paxeer-network-${Number(network.chainId)}.json`,
  );
  if (!fs.existsSync(deployFile)) {
    console.error('No deployment found. Run deploy.ts first.');
    process.exit(1);
  }
  const deployment = JSON.parse(fs.readFileSync(deployFile, 'utf8'));
  const diamondAddr = deployment.contracts.Diamond;

  console.log('═'.repeat(60));
  console.log('  v5-ASAMM Paxeer Live Test (existing deployment)');
  console.log('═'.repeat(60));
  console.log(`  Network:   ${network.name} (chainId: ${network.chainId})`);
  console.log(`  Deployer:  ${deployer.address}`);
  console.log(`  Diamond:   ${diamondAddr}`);
  console.log(
    `  Balance:   ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`,
  );
  console.log('');

  let passed = 0;
  let failed = 0;

  function check(name: string, condition: boolean) {
    if (condition) {
      console.log(`  ✅ ${name}`);
      passed++;
    } else {
      console.log(`  ❌ ${name}`);
      failed++;
    }
  }

  // Get facet interfaces on existing Diamond
  const pool = await ethers.getContractAt('PoolFacet', diamondAddr);
  const swap = await ethers.getContractAt('SwapFacet', diamondAddr);
  const liq = await ethers.getContractAt('LiquidityFacet', diamondAddr);
  const fee = await ethers.getContractAt('FeeFacet', diamondAddr);
  const loupe = await ethers.getContractAt('IDiamondLoupe', diamondAddr);

  // ── Step 1: Verify Diamond ──
  console.log('─── Step 1: Verify Diamond ───\n');

  const facetAddresses = await loupe.facetAddresses();
  check(`Diamond has ${facetAddresses.length} facets`, facetAddresses.length === 12);

  const ownership = await ethers.getContractAt('OwnershipFacet', diamondAddr);
  check('Owner is deployer', (await ownership.owner()) === deployer.address);

  const poolCountBefore = await pool.getPoolCount();
  console.log(`  Existing pools: ${poolCountBefore}`);

  // ── Step 2: Deploy Mock Tokens ──
  console.log('\n─── Step 2: Deploy Mock Tokens ───\n');

  const MockERC20 = await ethers.getContractFactory('MockERC20');
  const tokenA = await MockERC20.deploy('Test USDC', 'tUSDC', 18);
  const tokenB = await MockERC20.deploy('Test WETH', 'tWETH', 18);
  await tokenA.waitForDeployment();
  await tokenB.waitForDeployment();

  // Sort tokens
  const [t0, t1] =
    BigInt(tokenA.target as string) < BigInt(tokenB.target as string)
      ? [tokenA, tokenB]
      : [tokenB, tokenA];

  console.log(`  Token0: ${t0.target}`);
  console.log(`  Token1: ${t1.target}`);

  // Mint & approve
  const mintAmt = ethers.parseEther('50000');
  await (await t0.mint(deployer.address, mintAmt)).wait();
  await (await t1.mint(deployer.address, mintAmt)).wait();
  await (await t0.approve(diamondAddr, ethers.MaxUint256)).wait();
  await (await t1.approve(diamondAddr, ethers.MaxUint256)).wait();
  check('Tokens minted and approved', true);

  // ── Step 3: Create Pool (permissionless) ──
  console.log('\n─── Step 3: Create Pool ───\n');

  const tickSpacing = 60;
  try {
    const tx = await pool.createPool(
      {
        token0: t0.target,
        token1: t1.target,
        poolType: 0,
        tickSpacing,
        sigmoidAlpha: ethers.parseUnits('1', 38),
        sigmoidK: ethers.parseUnits('5', 37),
        baseFee: 30,
        maxImpactFee: 100,
      },
      { gasLimit: 1000000 },
    );
    await tx.wait();
    console.log(`  createPool tx confirmed`);
  } catch (e: any) {
    console.log(`  createPool error: ${e.message?.slice(0, 200)}`);
  }

  const poolId = await pool.computePoolId(t0.target, t1.target, tickSpacing);
  const exists = await pool.poolExists(poolId);
  check('Pool created', exists);
  if (!exists) {
    console.log('  FATAL: Pool not created. Aborting.');
    process.exit(1);
  }

  check('Pool creator is deployer', (await pool.getPoolCreator(poolId)) === deployer.address);

  const poolCountAfter = await pool.getPoolCount();
  check('Pool count incremented', poolCountAfter > poolCountBefore);

  // Initialize pool at 1:1
  const sqrtPriceX96 = 79228162514264337593543950336n;
  try {
    const tx = await pool.initializePool(poolId, sqrtPriceX96, { gasLimit: 300000 });
    await tx.wait();
  } catch (e: any) {
    console.log(`  initializePool error: ${e.message?.slice(0, 200)}`);
  }

  const stateInit = await pool.getPoolState(poolId);
  check(
    'Pool initialized at 1:1',
    stateInit.initialized && stateInit.sqrtPriceX96 === sqrtPriceX96,
  );

  // ── Step 4: Add Liquidity ──
  console.log('\n─── Step 4: Add Liquidity ───\n');

  const deadline = Math.floor(Date.now() / 1000) + 3600;
  try {
    const tx = await liq.addLiquidity(
      {
        poolId,
        tickLower: -6000,
        tickUpper: 6000,
        amount0Desired: ethers.parseEther('1000'),
        amount1Desired: ethers.parseEther('1000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: deployer.address,
        deadline,
      },
      { gasLimit: 500000 },
    );
    await tx.wait();
  } catch (e: any) {
    console.log(`  addLiquidity error: ${e.message?.slice(0, 200)}`);
  }

  const stateLP = await pool.getPoolState(poolId);
  check('Liquidity > 0', stateLP.liquidity > 0n);
  check('Reserve0 > 0', stateLP.reserve0 > 0n);
  check('Reserve1 > 0', stateLP.reserve1 > 0n);
  console.log(`  Liquidity: ${stateLP.liquidity}`);
  console.log(`  Reserve0:  ${ethers.formatEther(stateLP.reserve0)}`);
  console.log(`  Reserve1:  ${ethers.formatEther(stateLP.reserve1)}`);

  // ── Step 5: Swap token0 -> token1 ──
  console.log('\n─── Step 5: Swap token0 → token1 ───\n');

  const bal1Before = await t1.balanceOf(deployer.address);
  try {
    const tx = await swap.swap(
      {
        poolId,
        zeroForOne: true,
        amountSpecified: ethers.parseEther('5'),
        sqrtPriceLimitX96: 0,
        recipient: deployer.address,
        deadline,
      },
      { gasLimit: 500000 },
    );
    await tx.wait();
  } catch (e: any) {
    console.log(`  swap error: ${e.message?.slice(0, 200)}`);
  }

  const bal1After = await t1.balanceOf(deployer.address);
  const received1 = bal1After - bal1Before;
  check('Received token1', received1 > 0n);
  console.log(`  Received: ${ethers.formatEther(received1)} token1`);

  const stateAfterSwap = await pool.getPoolState(poolId);
  check('Price decreased (zeroForOne)', stateAfterSwap.sqrtPriceX96 < sqrtPriceX96);

  // ── Step 6: Swap token1 -> token0 ──
  console.log('\n─── Step 6: Swap token1 → token0 ───\n');

  const bal0Before = await t0.balanceOf(deployer.address);
  try {
    const tx = await swap.swap(
      {
        poolId,
        zeroForOne: false,
        amountSpecified: ethers.parseEther('5'),
        sqrtPriceLimitX96: 0,
        recipient: deployer.address,
        deadline,
      },
      { gasLimit: 500000 },
    );
    await tx.wait();
  } catch (e: any) {
    console.log(`  swap error: ${e.message?.slice(0, 200)}`);
  }

  const bal0After = await t0.balanceOf(deployer.address);
  const received0 = bal0After - bal0Before;
  check('Received token0', received0 > 0n);
  console.log(`  Received: ${ethers.formatEther(received0)} token0`);

  // ── Step 7: Verify Fees ──
  console.log('\n─── Step 7: Verify Fees ───\n');

  const stateAfterSwaps = await pool.getPoolState(poolId);
  check('Fee growth global0 > 0', stateAfterSwaps.feeGrowthGlobal0X128 > 0n);
  check('Fee growth global1 > 0', stateAfterSwaps.feeGrowthGlobal1X128 > 0n);
  check('Protocol fees0 accumulated', stateAfterSwaps.protocolFees0 > 0n);
  check('Protocol fees1 accumulated', stateAfterSwaps.protocolFees1 > 0n);

  const feeConfig = await fee.getFeeConfig(poolId);
  check('Fee config LP share = 7000', feeConfig.lpShareBps === 7000n);

  // ── Step 8: Remove Liquidity ──
  console.log('\n─── Step 8: Remove Liquidity ───\n');

  const pos = await liq.getPosition(1);
  if (pos.liquidity > 0n) {
    check('Position has liquidity', true);
    const halfLiq = pos.liquidity / 2n;

    try {
      const tx = await liq.removeLiquidity(
        {
          poolId,
          positionId: 1,
          liquidityAmount: halfLiq,
          amount0Min: 0,
          amount1Min: 0,
          recipient: deployer.address,
          deadline,
        },
        { gasLimit: 500000 },
      );
      await tx.wait();
      check('Removed half liquidity', true);
    } catch (e: any) {
      console.log(`  removeLiquidity error: ${e.message?.slice(0, 200)}`);
      check('Removed half liquidity', false);
    }
  }

  // ── Step 9: Collect Protocol Fees ──
  console.log('\n─── Step 9: Collect Protocol Fees ───\n');

  const treasuryBal0Before = await t0.balanceOf(deployer.address);
  try {
    const tx = await fee.collectProtocolFees(poolId, deployer.address, { gasLimit: 300000 });
    await tx.wait();
    const treasuryBal0After = await t0.balanceOf(deployer.address);
    check('Protocol fees collected', treasuryBal0After > treasuryBal0Before);
  } catch (e: any) {
    console.log(`  collectProtocolFees error: ${e.message?.slice(0, 200)}`);
    check('Protocol fees collected', false);
  }

  // ── Step 10: Verify EventEmitter ──
  console.log('\n─── Step 10: Verify EventEmitter ───\n');

  if (deployment.contracts.EventEmitter) {
    const emitter = await ethers.getContractAt('EventEmitter', deployment.contracts.EventEmitter);
    const emitterPoolCount = await emitter.getPoolCount();
    console.log(`  EventEmitter tracked pools: ${emitterPoolCount}`);
    check('EventEmitter has pools', emitterPoolCount > 0n);

    if (emitterPoolCount > 0n) {
      const info = await emitter.getPoolInfo(poolId);
      check('EventEmitter has pool info', info.token0 !== ethers.ZeroAddress);
      console.log(`  Pool creator: ${info.creator}`);
      console.log(`  Total swaps:  ${info.totalSwaps}`);
    }
  } else {
    console.log('  EventEmitter not deployed, skipping');
  }

  // ── Results ──
  console.log('\n' + '═'.repeat(60));
  console.log(`  RESULTS: ${passed} passed, ${failed} failed`);
  console.log('═'.repeat(60));

  // Save results
  const results = {
    network: network.name,
    chainId: Number(network.chainId),
    timestamp: new Date().toISOString(),
    diamond: diamondAddr,
    poolId,
    tokens: { token0: t0.target, token1: t1.target },
    passed,
    failed,
    total: passed + failed,
  };

  const outDir = path.join(__dirname, '..', 'deployments');
  fs.writeFileSync(
    path.join(outDir, `paxeer-live-test-results.json`),
    JSON.stringify(results, (_, v) => (typeof v === 'bigint' ? v.toString() : v), 2),
  );
  console.log(`\n  Results saved to: deployments/paxeer-live-test-results.json`);

  if (failed > 0) process.exit(1);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
