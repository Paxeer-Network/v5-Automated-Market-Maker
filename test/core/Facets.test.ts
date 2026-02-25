import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

// Selector helper: extract all non-constructor function selectors from a contract
function getSelectors(contract: any): string[] {
  const selectors: string[] = [];
  for (const fragment of contract.interface.fragments) {
    if (fragment.type === 'function') {
      selectors.push(contract.interface.getFunction(fragment.name)!.selector);
    }
  }
  return selectors;
}

describe('Facet Integration Tests', function () {
  // ─── Full Diamond Deployment Fixture ───
  async function deployFullDiamondFixture() {
    const [owner, alice, bob, treasury] = await ethers.getSigners();

    // 1. Deploy MockERC20 tokens
    const MockERC20 = await ethers.getContractFactory('MockERC20');
    const tokenA = await MockERC20.deploy('Token A', 'TKA', 18);
    const tokenB = await MockERC20.deploy('Token B', 'TKB', 18);

    // Ensure token0 < token1 (by address)
    const token0Addr = tokenA.target < tokenB.target ? tokenA.target : tokenB.target;
    const token1Addr = tokenA.target < tokenB.target ? tokenB.target : tokenA.target;
    const token0 = await ethers.getContractAt('MockERC20', token0Addr);
    const token1 = await ethers.getContractAt('MockERC20', token1Addr);

    // Mint tokens
    const mintAmount = ethers.parseEther('1000000');
    await token0.mint(owner.address, mintAmount);
    await token0.mint(alice.address, mintAmount);
    await token1.mint(owner.address, mintAmount);
    await token1.mint(alice.address, mintAmount);

    // 2. Deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
    const diamondCutFacet = await DiamondCutFacet.deploy();

    // 3. Deploy Diamond
    const Diamond = await ethers.getContractFactory('Diamond');
    const diamond = await Diamond.deploy(owner.address, diamondCutFacet.target);

    // 4. Deploy all facets
    const DiamondLoupeFacet = await ethers.getContractFactory('DiamondLoupeFacet');
    const loupeFacet = await DiamondLoupeFacet.deploy();

    const OwnershipFacet = await ethers.getContractFactory('OwnershipFacet');
    const ownershipFacet = await OwnershipFacet.deploy();

    const PoolFacet = await ethers.getContractFactory('PoolFacet');
    const poolFacet = await PoolFacet.deploy();

    const SwapFacet = await ethers.getContractFactory('SwapFacet');
    const swapFacet = await SwapFacet.deploy();

    const LiquidityFacet = await ethers.getContractFactory('LiquidityFacet');
    const liquidityFacet = await LiquidityFacet.deploy();

    const FeeFacet = await ethers.getContractFactory('FeeFacet');
    const feeFacet = await FeeFacet.deploy();

    const OrderFacet = await ethers.getContractFactory('OrderFacet');
    const orderFacet = await OrderFacet.deploy();

    const OracleFacet = await ethers.getContractFactory('OracleFacet');
    const oracleFacet = await OracleFacet.deploy();

    const FlashLoanFacet = await ethers.getContractFactory('FlashLoanFacet');
    const flashLoanFacet = await FlashLoanFacet.deploy();

    const RewardFacet = await ethers.getContractFactory('RewardFacet');
    const rewardFacet = await RewardFacet.deploy();

    // 5. Deploy InitDiamond
    const InitDiamond = await ethers.getContractFactory('InitDiamond');
    const initDiamond = await InitDiamond.deploy();

    // 6. Wire up facets via diamondCut
    const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.target);

    const facetCuts = [
      { facetAddress: loupeFacet.target, action: 0, functionSelectors: getSelectors(loupeFacet) },
      {
        facetAddress: ownershipFacet.target,
        action: 0,
        functionSelectors: getSelectors(ownershipFacet),
      },
      { facetAddress: poolFacet.target, action: 0, functionSelectors: getSelectors(poolFacet) },
      { facetAddress: swapFacet.target, action: 0, functionSelectors: getSelectors(swapFacet) },
      {
        facetAddress: liquidityFacet.target,
        action: 0,
        functionSelectors: getSelectors(liquidityFacet),
      },
      { facetAddress: feeFacet.target, action: 0, functionSelectors: getSelectors(feeFacet) },
      { facetAddress: orderFacet.target, action: 0, functionSelectors: getSelectors(orderFacet) },
      { facetAddress: oracleFacet.target, action: 0, functionSelectors: getSelectors(oracleFacet) },
      {
        facetAddress: flashLoanFacet.target,
        action: 0,
        functionSelectors: getSelectors(flashLoanFacet),
      },
      { facetAddress: rewardFacet.target, action: 0, functionSelectors: getSelectors(rewardFacet) },
    ];

    // Encode InitDiamond.init() calldata
    const initArgs = {
      treasury: treasury.address,
      flashLoanFeeBps: 9,
      maxOrdersPerPool: 1000,
      defaultOrderTTL: 30 * 24 * 3600, // 30 days
      minOrderSize: ethers.parseEther('0.01'),
      keeperBountyBps: 10,
      epochDuration: 7 * 24 * 3600, // 7 days
      minSwapsForRebate: 3,
      maxTradeSizeBps: 500,
    };

    const initCalldata = initDiamond.interface.encodeFunctionData('init', [initArgs]);

    await diamondCut.diamondCut(facetCuts, initDiamond.target, initCalldata);

    // 7. Get facet interfaces on diamond address
    const pool = await ethers.getContractAt('PoolFacet', diamond.target);
    const swap = await ethers.getContractAt('SwapFacet', diamond.target);
    const liquidity = await ethers.getContractAt('LiquidityFacet', diamond.target);
    const fee = await ethers.getContractAt('FeeFacet', diamond.target);
    const order = await ethers.getContractAt('OrderFacet', diamond.target);
    const loupe = await ethers.getContractAt('IDiamondLoupe', diamond.target);

    // Approve diamond for token transfers
    const maxApproval = ethers.MaxUint256;
    await token0.approve(diamond.target, maxApproval);
    await token1.approve(diamond.target, maxApproval);
    await token0.connect(alice).approve(diamond.target, maxApproval);
    await token1.connect(alice).approve(diamond.target, maxApproval);

    return {
      diamond,
      pool,
      swap,
      liquidity,
      fee,
      order,
      loupe,
      token0,
      token1,
      owner,
      alice,
      bob,
      treasury,
      initArgs,
    };
  }

  // ─── Helper: Create and initialize a standard pool ───
  async function createAndInitPool(pool: any, token0Addr: string, token1Addr: string) {
    const config = {
      token0: token0Addr,
      token1: token1Addr,
      poolType: 0, // Standard
      tickSpacing: 60,
      sigmoidAlpha: ethers.parseUnits('1', 38), // ~1.0 in Q128.128
      sigmoidK: ethers.parseUnits('5', 37), // ~0.5 in Q128.128
      baseFee: 30, // 0.30%
      maxImpactFee: 100, // 1.00%
    };
    const tx = await pool.createPool(config);
    const receipt = await tx.wait();

    // Compute poolId
    const poolId = await pool.computePoolId(token0Addr, token1Addr, 60);

    // Initialize at price 1:1 (sqrtPriceX96 = 2^96)
    const sqrtPriceX96 = 79228162514264337593543950336n; // 2^96
    await pool.initializePool(poolId, sqrtPriceX96);

    return { poolId, config, sqrtPriceX96 };
  }

  // ═══════════════════════════════════════════════════
  //                    POOL FACET
  // ═══════════════════════════════════════════════════
  describe('PoolFacet', function () {
    it('should create a pool and emit PoolCreated', async function () {
      const { pool, token0, token1 } = await loadFixture(deployFullDiamondFixture);

      await expect(
        pool.createPool({
          token0: token0.target,
          token1: token1.target,
          poolType: 0,
          tickSpacing: 60,
          sigmoidAlpha: ethers.parseUnits('1', 38),
          sigmoidK: ethers.parseUnits('5', 37),
          baseFee: 30,
          maxImpactFee: 100,
        }),
      ).to.emit(pool, 'PoolCreated');
    });

    it('should initialize a pool and emit PoolInitialized', async function () {
      const { pool, token0, token1 } = await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      const state = await pool.getPoolState(poolId);
      expect(state.initialized).to.be.true;
      expect(state.sqrtPriceX96).to.equal(79228162514264337593543950336n);
    });

    it('should report poolExists correctly', async function () {
      const { pool, token0, token1 } = await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      expect(await pool.poolExists(poolId)).to.be.true;
      expect(await pool.poolExists(ethers.ZeroHash)).to.be.false;
    });

    it('should return correct pool count', async function () {
      const { pool, token0, token1 } = await loadFixture(deployFullDiamondFixture);
      expect(await pool.getPoolCount()).to.equal(0);
      await createAndInitPool(pool, token0.target as string, token1.target as string);
      expect(await pool.getPoolCount()).to.equal(1);
    });

    it('should allow anyone to create a pool (permissionless)', async function () {
      const { pool, token0, token1, alice } = await loadFixture(deployFullDiamondFixture);
      await pool.connect(alice).createPool({
        token0: token0.target,
        token1: token1.target,
        poolType: 0,
        tickSpacing: 60,
        sigmoidAlpha: 0,
        sigmoidK: 0,
        baseFee: 30,
        maxImpactFee: 100,
      });
      const poolId = await pool.computePoolId(token0.target, token1.target, 60);
      expect(await pool.poolExists(poolId)).to.be.true;
      expect(await pool.getPoolCreator(poolId)).to.equal(alice.address);
    });

    it('should pause and unpause', async function () {
      const { pool, token0, token1, owner } = await loadFixture(deployFullDiamondFixture);

      // Set owner as pause guardian first
      await pool.setPauseGuardian(owner.address, true);
      await pool.pause();

      // Creating pool should fail when paused
      await expect(
        pool.createPool({
          token0: token0.target,
          token1: token1.target,
          poolType: 0,
          tickSpacing: 60,
          sigmoidAlpha: 0,
          sigmoidK: 0,
          baseFee: 30,
          maxImpactFee: 100,
        }),
      ).to.be.reverted;

      await pool.unpause();

      // Should work after unpause
      await pool.createPool({
        token0: token0.target,
        token1: token1.target,
        poolType: 0,
        tickSpacing: 60,
        sigmoidAlpha: 0,
        sigmoidK: 0,
        baseFee: 30,
        maxImpactFee: 100,
      });
    });
  });

  // ═══════════════════════════════════════════════════
  //                  LIQUIDITY FACET
  // ═══════════════════════════════════════════════════
  describe('LiquidityFacet', function () {
    it('should add initial liquidity and create position', async function () {
      const { pool, liquidity, token0, token1, owner } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      const amount0 = ethers.parseEther('100');
      const amount1 = ethers.parseEther('100');

      const tx = await liquidity.addLiquidity({
        poolId,
        tickLower: -887220,
        tickUpper: 887220,
        amount0Desired: amount0,
        amount1Desired: amount1,
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      await expect(tx).to.emit(liquidity, 'LiquidityAdded');

      // Verify pool state updated
      const state = await pool.getPoolState(poolId);
      expect(state.liquidity).to.be.gt(0);
      expect(state.reserve0).to.be.gt(0);
      expect(state.reserve1).to.be.gt(0);
    });

    it('should retrieve position info after adding liquidity', async function () {
      const { pool, liquidity, token0, token1, owner } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -887220,
        tickUpper: 887220,
        amount0Desired: ethers.parseEther('100'),
        amount1Desired: ethers.parseEther('100'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const pos = await liquidity.getPosition(1); // First position ID
      expect(pos.poolId).to.equal(poolId);
      expect(pos.owner).to.equal(owner.address);
      expect(pos.liquidity).to.be.gt(0);
    });

    it('should add proportional liquidity on second deposit', async function () {
      const { pool, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      // First deposit
      await liquidity.addLiquidity({
        poolId,
        tickLower: -887220,
        tickUpper: 887220,
        amount0Desired: ethers.parseEther('100'),
        amount1Desired: ethers.parseEther('100'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const stateBefore = await pool.getPoolState(poolId);

      // Second deposit by alice
      await liquidity.connect(alice).addLiquidity({
        poolId,
        tickLower: -887220,
        tickUpper: 887220,
        amount0Desired: ethers.parseEther('50'),
        amount1Desired: ethers.parseEther('50'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: alice.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const stateAfter = await pool.getPoolState(poolId);
      expect(stateAfter.liquidity).to.be.gt(stateBefore.liquidity);
    });

    it('should remove liquidity and return tokens', async function () {
      const { pool, liquidity, token0, token1, owner, diamond } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -887220,
        tickUpper: 887220,
        amount0Desired: ethers.parseEther('100'),
        amount1Desired: ethers.parseEther('100'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const pos = await liquidity.getPosition(1);
      const halfLiquidity = pos.liquidity / 2n;

      const balBefore0 = await token0.balanceOf(owner.address);
      const balBefore1 = await token1.balanceOf(owner.address);

      await liquidity.removeLiquidity({
        poolId,
        positionId: 1,
        liquidityAmount: halfLiquidity,
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const balAfter0 = await token0.balanceOf(owner.address);
      const balAfter1 = await token1.balanceOf(owner.address);

      expect(balAfter0).to.be.gt(balBefore0);
      expect(balAfter1).to.be.gt(balBefore1);
    });

    it('should prevent non-owner from removing liquidity', async function () {
      const { pool, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -887220,
        tickUpper: 887220,
        amount0Desired: ethers.parseEther('100'),
        amount1Desired: ethers.parseEther('100'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      await expect(
        liquidity.connect(alice).removeLiquidity({
          poolId,
          positionId: 1,
          liquidityAmount: 1,
          amount0Min: 0,
          amount1Min: 0,
          recipient: alice.address,
          deadline: Math.floor(Date.now() / 1000) + 3600,
        }),
      ).to.be.revertedWith('LiquidityFacet: not owner');
    });
  });

  // ═══════════════════════════════════════════════════
  //                    SWAP FACET
  // ═══════════════════════════════════════════════════
  describe('SwapFacet', function () {
    it('should execute exact-input swap (token0 -> token1)', async function () {
      const { pool, swap, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      // Add liquidity with narrow range to avoid overflow in getAmount0Delta
      await liquidity.addLiquidity({
        poolId,
        tickLower: -6000,
        tickUpper: 6000,
        amount0Desired: ethers.parseEther('1000'),
        amount1Desired: ethers.parseEther('1000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const balBefore = await token1.balanceOf(alice.address);

      // Alice swaps 1 token0 for token1
      await swap.connect(alice).swap({
        poolId,
        zeroForOne: true,
        amountSpecified: ethers.parseEther('1'),
        sqrtPriceLimitX96: 0,
        recipient: alice.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const balAfter = await token1.balanceOf(alice.address);
      expect(balAfter).to.be.gt(balBefore);
    });

    it('should execute exact-input swap (token1 -> token0)', async function () {
      const { pool, swap, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -6000,
        tickUpper: 6000,
        amount0Desired: ethers.parseEther('1000'),
        amount1Desired: ethers.parseEther('1000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const balBefore = await token0.balanceOf(alice.address);

      await swap.connect(alice).swap({
        poolId,
        zeroForOne: false,
        amountSpecified: ethers.parseEther('1'),
        sqrtPriceLimitX96: 0,
        recipient: alice.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const balAfter = await token0.balanceOf(alice.address);
      expect(balAfter).to.be.gt(balBefore);
    });

    it('should update pool price after swap', async function () {
      const { pool, swap, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId, sqrtPriceX96 } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -6000,
        tickUpper: 6000,
        amount0Desired: ethers.parseEther('1000'),
        amount1Desired: ethers.parseEther('1000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      await swap.connect(alice).swap({
        poolId,
        zeroForOne: true,
        amountSpecified: ethers.parseEther('10'),
        sqrtPriceLimitX96: 0,
        recipient: alice.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const stateAfter = await pool.getPoolState(poolId);
      // Price should have decreased (zeroForOne pushes price down)
      expect(stateAfter.sqrtPriceX96).to.be.lt(sqrtPriceX96);
    });

    it('should emit Swap event', async function () {
      const { pool, swap, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -6000,
        tickUpper: 6000,
        amount0Desired: ethers.parseEther('1000'),
        amount1Desired: ethers.parseEther('1000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      await expect(
        swap.connect(alice).swap({
          poolId,
          zeroForOne: true,
          amountSpecified: ethers.parseEther('1'),
          sqrtPriceLimitX96: 0,
          recipient: alice.address,
          deadline: Math.floor(Date.now() / 1000) + 3600,
        }),
      ).to.emit(swap, 'Swap');
    });

    it('should revert on zero amount', async function () {
      const { pool, swap, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -6000,
        tickUpper: 6000,
        amount0Desired: ethers.parseEther('1000'),
        amount1Desired: ethers.parseEther('1000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      await expect(
        swap.connect(alice).swap({
          poolId,
          zeroForOne: true,
          amountSpecified: 0,
          sqrtPriceLimitX96: 0,
          recipient: alice.address,
          deadline: Math.floor(Date.now() / 1000) + 3600,
        }),
      ).to.be.revertedWith('SwapFacet: zero amount');
    });

    it('should revert on expired deadline', async function () {
      const { pool, swap, liquidity, token0, token1, owner, alice } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await liquidity.addLiquidity({
        poolId,
        tickLower: -6000,
        tickUpper: 6000,
        amount0Desired: ethers.parseEther('1000'),
        amount1Desired: ethers.parseEther('1000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      await expect(
        swap.connect(alice).swap({
          poolId,
          zeroForOne: true,
          amountSpecified: ethers.parseEther('10'),
          sqrtPriceLimitX96: 0,
          recipient: alice.address,
          deadline: 1, // Already expired
        }),
      ).to.be.reverted;
    });
  });

  // ═══════════════════════════════════════════════════
  //                     FEE FACET
  // ═══════════════════════════════════════════════════
  describe('FeeFacet', function () {
    it('should return default fee config after pool creation', async function () {
      const { pool, fee, token0, token1 } = await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      const config = await fee.getFeeConfig(poolId);
      expect(config.lpShareBps).to.equal(7000);
      expect(config.protocolShareBps).to.equal(2000);
      expect(config.traderShareBps).to.equal(1000);
    });

    it('should update fee config (owner only)', async function () {
      const { pool, fee, token0, token1 } = await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await fee.setFeeConfig(poolId, {
        baseFee: 50,
        maxImpactFee: 200,
        lpShareBps: 6000,
        protocolShareBps: 3000,
        traderShareBps: 1000,
      });

      const config = await fee.getFeeConfig(poolId);
      expect(config.baseFee).to.equal(50);
      expect(config.maxImpactFee).to.equal(200);
      expect(config.lpShareBps).to.equal(6000);
    });

    it('should prevent non-owner from setting fee config', async function () {
      const { pool, fee, token0, token1, alice } = await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await expect(
        fee.connect(alice).setFeeConfig(poolId, {
          baseFee: 50,
          maxImpactFee: 200,
          lpShareBps: 7000,
          protocolShareBps: 2000,
          traderShareBps: 1000,
        }),
      ).to.be.reverted;
    });

    it('should reject invalid fee config (shares != 10000)', async function () {
      const { pool, fee, token0, token1 } = await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      await expect(
        fee.setFeeConfig(poolId, {
          baseFee: 50,
          maxImpactFee: 200,
          lpShareBps: 5000,
          protocolShareBps: 3000,
          traderShareBps: 1000, // Sum = 9000 != 10000
        }),
      ).to.be.reverted;
    });

    it('should calculate progressive fee', async function () {
      const { pool, fee, liquidity, token0, token1, owner } =
        await loadFixture(deployFullDiamondFixture);
      const { poolId } = await createAndInitPool(
        pool,
        token0.target as string,
        token1.target as string,
      );

      // Add liquidity first so pool has reserves for fee calc
      await liquidity.addLiquidity({
        poolId,
        tickLower: -887220,
        tickUpper: 887220,
        amount0Desired: ethers.parseEther('10000'),
        amount1Desired: ethers.parseEther('10000'),
        amount0Min: 0,
        amount1Min: 0,
        recipient: owner.address,
        deadline: Math.floor(Date.now() / 1000) + 3600,
      });

      const smallFee = await fee.calculateFee(poolId, ethers.parseEther('1'));
      const largeFee = await fee.calculateFee(poolId, ethers.parseEther('1000'));

      // Larger trades should have higher (or equal) fees
      expect(largeFee).to.be.gte(smallFee);
    });
  });

  // ═══════════════════════════════════════════════════
  //                  DIAMOND LOUPE
  // ═══════════════════════════════════════════════════
  describe('DiamondLoupe Integration', function () {
    it('should have all facets registered', async function () {
      const { loupe } = await loadFixture(deployFullDiamondFixture);
      const addresses = await loupe.facetAddresses();
      // DiamondCut + Loupe + Ownership + Pool + Swap + Liquidity + Fee + Order + Oracle + FlashLoan + Reward = 11
      expect(addresses.length).to.equal(11);
    });
  });
});
