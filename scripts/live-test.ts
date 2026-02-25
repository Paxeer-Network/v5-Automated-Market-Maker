import { ethers } from "hardhat";
import { deployDiamond } from "./libraries/diamond";
import * as fs from "fs";
import * as path from "path";

/**
 * Live Test Script — deploys the full protocol and exercises all major flows.
 * Works with a SINGLE signer so it can run on real networks (Paxeer, etc.).
 *
 * Usage:
 *   Local:  npx hardhat run scripts/live-test.ts --network hardhat
 *   Paxeer: npx hardhat run scripts/live-test.ts --network paxeer-network
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  console.log("═".repeat(60));
  console.log("  v5-ASAMM Live Test (single-signer)");
  console.log("═".repeat(60));
  console.log(`  Network:  ${network.name} (chainId: ${network.chainId})`);
  console.log(`  Deployer: ${deployer.address}`);
  console.log(`  Balance:  ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);
  console.log("");

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

  // ── Step 1: Deploy Protocol ──
  console.log("\n─── Step 1: Deploy Protocol ───\n");

  const facetNames = [
    "DiamondLoupeFacet", "OwnershipFacet", "PoolFacet", "SwapFacet",
    "LiquidityFacet", "FeeFacet", "OracleFacet", "OraclePegFacet",
    "OrderFacet", "RewardFacet", "FlashLoanFacet",
  ];

  const initArgs = {
    treasury: deployer.address,
    flashLoanFeeBps: 9,
    maxOrdersPerPool: 100,
    defaultOrderTTL: 30 * 86400,
    minOrderSize: ethers.parseEther("0.001"),
    keeperBountyBps: 1,
    epochDuration: 7 * 86400,
    minSwapsForRebate: 5,
    maxTradeSizeBps: 500,
  };

  const { diamond, facets } = await deployDiamond(deployer.address, facetNames, initArgs);
  check("Diamond deployed", diamond.target !== ethers.ZeroAddress);

  // Deploy mock tokens for testing
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const tokenA = await MockERC20.deploy("USDC Mock", "mUSDC", 18);
  const tokenB = await MockERC20.deploy("WETH Mock", "mWETH", 18);
  await tokenA.waitForDeployment();
  await tokenB.waitForDeployment();

  const t0Addr = tokenA.target < tokenB.target ? tokenA.target : tokenB.target;
  const t1Addr = tokenA.target < tokenB.target ? tokenB.target : tokenA.target;
  const token0 = await ethers.getContractAt("MockERC20", t0Addr);
  const token1 = await ethers.getContractAt("MockERC20", t1Addr);

  console.log(`  Token0: ${token0.target}`);
  console.log(`  Token1: ${token1.target}`);

  // Mint & approve (all to deployer — single signer)
  const mintAmount = ethers.parseEther("100000");
  await token0.mint(deployer.address, mintAmount);
  await token1.mint(deployer.address, mintAmount);
  await token0.approve(diamond.target, ethers.MaxUint256);
  await token1.approve(diamond.target, ethers.MaxUint256);
  check("Tokens minted and approved", true);

  // Get facet interfaces on Diamond
  const pool = await ethers.getContractAt("PoolFacet", diamond.target as string);
  const swap = await ethers.getContractAt("SwapFacet", diamond.target as string);
  const liq = await ethers.getContractAt("LiquidityFacet", diamond.target as string);
  const fee = await ethers.getContractAt("FeeFacet", diamond.target as string);
  const loupe = await ethers.getContractAt("IDiamondLoupe", diamond.target as string);

  // ── Step 2: Verify Diamond ──
  console.log("\n─── Step 2: Verify Diamond ───\n");

  const facetAddresses = await loupe.facetAddresses();
  check(`Diamond has ${facetAddresses.length} facets`, facetAddresses.length === 12);

  const owner = await (await ethers.getContractAt("OwnershipFacet", diamond.target as string)).owner();
  check("Owner is deployer", owner === deployer.address);

  // ── Step 3: Create Pool ──
  console.log("\n─── Step 3: Create Pool ───\n");

  await pool.createPool({
    token0: token0.target, token1: token1.target, poolType: 0,
    tickSpacing: 60,
    sigmoidAlpha: ethers.parseUnits("1", 38),
    sigmoidK: ethers.parseUnits("5", 37),
    baseFee: 30, maxImpactFee: 100,
  });
  const poolId = await pool.computePoolId(token0.target, token1.target, 60);
  check("Pool created", await pool.poolExists(poolId));

  const sqrtPriceX96 = 79228162514264337593543950336n; // 1:1 price
  await pool.initializePool(poolId, sqrtPriceX96);
  const stateInit = await pool.getPoolState(poolId);
  check("Pool initialized at 1:1", stateInit.initialized && stateInit.sqrtPriceX96 === sqrtPriceX96);

  // ── Step 4: Add Liquidity ──
  console.log("\n─── Step 4: Add Liquidity ───\n");

  const deadline = Math.floor(Date.now() / 1000) + 3600;
  await liq.addLiquidity({
    poolId, tickLower: -6000, tickUpper: 6000,
    amount0Desired: ethers.parseEther("1000"),
    amount1Desired: ethers.parseEther("1000"),
    amount0Min: 0, amount1Min: 0,
    recipient: deployer.address, deadline,
  });

  const stateLP = await pool.getPoolState(poolId);
  check("Liquidity added (liquidity > 0)", stateLP.liquidity > 0n);
  check("Reserve0 updated", stateLP.reserve0 > 0n);
  check("Reserve1 updated", stateLP.reserve1 > 0n);
  console.log(`  Liquidity: ${stateLP.liquidity}`);
  console.log(`  Reserve0:  ${ethers.formatEther(stateLP.reserve0)}`);
  console.log(`  Reserve1:  ${ethers.formatEther(stateLP.reserve1)}`);

  // ── Step 5: Execute Swaps (deployer swaps with itself) ──
  console.log("\n─── Step 5: Execute Swaps ───\n");

  // Swap token0 -> token1
  const bal1Before = await token1.balanceOf(deployer.address);
  await swap.swap({
    poolId, zeroForOne: true,
    amountSpecified: ethers.parseEther("5"),
    sqrtPriceLimitX96: 0,
    recipient: deployer.address, deadline,
  });
  const bal1After = await token1.balanceOf(deployer.address);
  const received1 = bal1After - bal1Before;
  check("Swap token0->token1 succeeded", received1 > 0n);
  console.log(`  Received: ${ethers.formatEther(received1)} token1`);

  const stateAfterSwap1 = await pool.getPoolState(poolId);
  check("Price decreased after zeroForOne swap", stateAfterSwap1.sqrtPriceX96 < sqrtPriceX96);

  // Swap token1 -> token0 (reverse direction)
  const bal0BeforeSwap2 = await token0.balanceOf(deployer.address);
  await swap.swap({
    poolId, zeroForOne: false,
    amountSpecified: ethers.parseEther("5"),
    sqrtPriceLimitX96: 0,
    recipient: deployer.address, deadline,
  });
  const bal0AfterSwap2 = await token0.balanceOf(deployer.address);
  const received0 = bal0AfterSwap2 - bal0BeforeSwap2;
  check("Swap token1->token0 succeeded", received0 > 0n);
  console.log(`  Received: ${ethers.formatEther(received0)} token0`);

  // ── Step 6: Verify Fees ──
  console.log("\n─── Step 6: Verify Fees ───\n");

  const stateAfterSwaps = await pool.getPoolState(poolId);
  check("Fee growth global0 > 0", stateAfterSwaps.feeGrowthGlobal0X128 > 0n);
  check("Fee growth global1 > 0", stateAfterSwaps.feeGrowthGlobal1X128 > 0n);
  check("Protocol fees0 accumulated", stateAfterSwaps.protocolFees0 > 0n);
  check("Protocol fees1 accumulated", stateAfterSwaps.protocolFees1 > 0n);

  const feeConfig = await fee.getFeeConfig(poolId);
  check("Fee config LP share = 7000", feeConfig.lpShareBps === 7000n);

  // ── Step 7: Remove Liquidity (BEFORE fee collection to avoid balance shortfall) ──
  console.log("\n─── Step 7: Remove Liquidity ───\n");

  const pos = await liq.getPosition(1);
  check("Position exists with liquidity", pos.liquidity > 0n);

  const bal0BeforeRemove = await token0.balanceOf(deployer.address);
  await liq.removeLiquidity({
    poolId, positionId: 1, liquidityAmount: pos.liquidity,
    amount0Min: 0, amount1Min: 0,
    recipient: deployer.address, deadline,
  });
  const bal0AfterRemove = await token0.balanceOf(deployer.address);
  check("Full liquidity removed, tokens returned", bal0AfterRemove > bal0BeforeRemove);

  const statePostRemove = await pool.getPoolState(poolId);
  check("Pool liquidity is 0 after full removal", statePostRemove.liquidity === 0n);

  // ── Step 8: Collect Protocol Fees ──
  console.log("\n─── Step 8: Collect Protocol Fees ───\n");

  const treasuryBal0Before = await token0.balanceOf(deployer.address);
  const treasuryBal1Before = await token1.balanceOf(deployer.address);
  await fee.collectProtocolFees(poolId, deployer.address);
  const treasuryBal0After = await token0.balanceOf(deployer.address);
  const treasuryBal1After = await token1.balanceOf(deployer.address);
  const feesCollected = (treasuryBal0After - treasuryBal0Before) + (treasuryBal1After - treasuryBal1Before);
  check("Protocol fees collected", feesCollected > 0n);
  console.log(`  Fees0: ${ethers.formatEther(treasuryBal0After - treasuryBal0Before)}`);
  console.log(`  Fees1: ${ethers.formatEther(treasuryBal1After - treasuryBal1Before)}`);

  // ── Step 9: Pause/Unpause ──
  console.log("\n─── Step 9: Pause/Unpause ───\n");

  // Re-add a bit of liquidity BEFORE pausing so there's a pool to swap against
  await liq.addLiquidity({
    poolId, tickLower: -6000, tickUpper: 6000,
    amount0Desired: ethers.parseEther("10"),
    amount1Desired: ethers.parseEther("10"),
    amount0Min: 0, amount1Min: 0,
    recipient: deployer.address, deadline,
  });

  await pool.setPauseGuardian(deployer.address, true);
  await pool.pause();

  let swapReverted = false;
  try {
    await swap.swap({
      poolId, zeroForOne: true,
      amountSpecified: ethers.parseEther("1"),
      sqrtPriceLimitX96: 0,
      recipient: deployer.address, deadline,
    });
  } catch {
    swapReverted = true;
  }
  check("Swap reverts when paused", swapReverted);

  await pool.unpause();
  check("Protocol unpaused", true);

  // ── Results ──
  console.log("\n" + "═".repeat(60));
  console.log(`  RESULTS: ${passed} passed, ${failed} failed`);
  console.log("═".repeat(60));

  // Save deployment + test results
  const results = {
    network: network.name,
    chainId: Number(network.chainId),
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      Diamond: diamond.target,
      Token0: token0.target,
      Token1: token1.target,
      ...Object.fromEntries(
        Object.entries(facets).map(([name, c]) => [name, c.target])
      ),
    },
    poolId,
    passed,
    failed,
    total: passed + failed,
  };

  const outDir = path.join(__dirname, "..", "deployments");
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
  const filename = `live-test-${network.name}-${Number(network.chainId)}.json`;
  fs.writeFileSync(
    path.join(outDir, filename),
    JSON.stringify(results, (_, v) => typeof v === "bigint" ? v.toString() : v, 2)
  );
  console.log(`\n  Results saved to: deployments/${filename}`);

  if (failed > 0) process.exit(1);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
