import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  const diamondAddr = "0x9595a92d63884d2D9924e0002D45C34d717DB291";

  const pool = await ethers.getContractAt("PoolFacet", diamondAddr);

  // Check if pool facet responds at all
  console.log("1. Pool count:", await pool.getPoolCount());
  
  // Check ownership
  const own = await ethers.getContractAt("OwnershipFacet", diamondAddr);
  console.log("2. Owner:", await own.owner());

  // Deploy tokens
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const tA = await MockERC20.deploy("A", "A", 18);
  const tB = await MockERC20.deploy("B", "B", 18);
  await tA.waitForDeployment();
  await tB.waitForDeployment();

  const t0 = BigInt(tA.target as string) < BigInt(tB.target as string) ? tA : tB;
  const t1 = BigInt(tA.target as string) < BigInt(tB.target as string) ? tB : tA;
  console.log("3. Token0:", t0.target, "Token1:", t1.target);

  // Try static call first to get revert reason
  try {
    const result = await pool.createPool.staticCall({
      token0: t0.target,
      token1: t1.target,
      poolType: 0,
      tickSpacing: 60,
      sigmoidAlpha: ethers.parseUnits("1", 38),
      sigmoidK: ethers.parseUnits("5", 37),
      baseFee: 30,
      maxImpactFee: 100,
    });
    console.log("4. staticCall succeeded, poolId:", result);
  } catch (e: any) {
    console.log("4. staticCall reverted:", e.message?.slice(0, 500));
    if (e.data) console.log("   Revert data:", e.data);
  }

  // Try actual tx with explicit gas
  try {
    const tx = await pool.createPool({
      token0: t0.target,
      token1: t1.target,
      poolType: 0,
      tickSpacing: 60,
      sigmoidAlpha: ethers.parseUnits("1", 38),
      sigmoidK: ethers.parseUnits("5", 37),
      baseFee: 30,
      maxImpactFee: 100,
    }, { gasLimit: 1000000 });
    console.log("5. Tx sent:", tx.hash);
    const receipt = await tx.wait();
    console.log("6. Tx confirmed, status:", receipt?.status);
  } catch (e: any) {
    console.log("5. Tx failed:", e.message?.slice(0, 500));
  }
}

main().catch(console.error);
