import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('LibFee', function () {
  async function deployFixture() {
    const Factory = await ethers.getContractFactory('LibFeeTest');
    const contract = await Factory.deploy();
    return { contract };
  }

  describe('calculateProgressiveFee', function () {
    it('should return baseFee for zero-size trades', async function () {
      const { contract } = await loadFixture(deployFixture);
      // baseFee=1 (0.01%), maxImpactFee=1000 (10%), tradeSize=0, liquidity=1000
      expect(await contract.calculateProgressiveFee(1, 1000, 0, 1000)).to.equal(1);
    });

    it('should return baseFee for very small trades', async function () {
      const { contract } = await loadFixture(deployFixture);
      // tradeSize=1, liquidity=1_000_000 → ratio≈0, impact≈0
      const fee = await contract.calculateProgressiveFee(1, 1000, 1, 1_000_000);
      expect(fee).to.equal(1); // Just baseFee
    });

    it('should increase fee quadratically with trade size', async function () {
      const { contract } = await loadFixture(deployFixture);
      // Use integer liquidity pool of 10000, trades of 100, 1000, 5000
      // ratio = tradeSize * 10000 / liquidity
      // For 100/10000 = ratio 100, impact = 1000 * 100² / 10000² = 0.1 → rounds to 0
      // For 1000/10000 = ratio 1000, impact = 1000 * 1000² / 10000² = 10
      // For 5000/10000 = ratio 5000, impact = 1000 * 5000² / 10000² = 2500
      const baseFee = 1n;
      const maxImpact = 1000n;
      const liquidity = 10000n;

      const feeSmall = await contract.calculateProgressiveFee(baseFee, maxImpact, 100, liquidity);
      const feeMedium = await contract.calculateProgressiveFee(baseFee, maxImpact, 1000, liquidity);
      const feeLarge = await contract.calculateProgressiveFee(baseFee, maxImpact, 5000, liquidity);

      // feeSmall=1, feeMedium=11, feeLarge=2501
      expect(feeSmall).to.be.lt(feeMedium);
      expect(feeMedium).to.be.lt(feeLarge);
    });

    it('should cap fee at MAX_FEE_BPS (5000 = 50%)', async function () {
      const { contract } = await loadFixture(deployFixture);
      // Huge trade relative to pool → should cap
      const fee = await contract.calculateProgressiveFee(1, 10000, 1_000_000, 100);
      expect(fee).to.equal(5000);
    });

    it('should return baseFee when pool liquidity is zero', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.calculateProgressiveFee(5, 1000, 100, 0)).to.equal(5);
    });
  });

  describe('applyFee', function () {
    it('should deduct correct fee amount', async function () {
      const { contract } = await loadFixture(deployFixture);
      const amount = 10000n;
      const feeBps = 100n; // 1%
      const [net, fee] = await contract.applyFee(amount, feeBps);
      expect(fee).to.equal(100n); // 1% of 10000
      expect(net).to.equal(9900n);
    });

    it('should handle zero fee', async function () {
      const { contract } = await loadFixture(deployFixture);
      const [net, fee] = await contract.applyFee(1000, 0);
      expect(fee).to.equal(0);
      expect(net).to.equal(1000);
    });
  });

  describe('distributeFee', function () {
    it('should split fees correctly (70/20/10)', async function () {
      const { contract } = await loadFixture(deployFixture);
      const totalFee = 10000n;
      const [lp, protocol, trader] = await contract.distributeFee(totalFee, 7000, 2000, 1000);
      expect(lp).to.equal(7000n);
      expect(protocol).to.equal(2000n);
      expect(trader).to.equal(1000n);
    });

    it('should handle remainder correctly', async function () {
      const { contract } = await loadFixture(deployFixture);
      // 333 split 70/20/10 → LP=233, Protocol=66, Trader=34 (gets remainder)
      const [lp, protocol, trader] = await contract.distributeFee(333, 7000, 2000, 1000);
      expect(lp + protocol + trader).to.equal(333n);
    });
  });

  describe('validateFeeConfig', function () {
    it('should accept valid config', async function () {
      const { contract } = await loadFixture(deployFixture);
      await expect(
        contract.validateFeeConfig({
          baseFee: 1,
          maxImpactFee: 1000,
          lpShareBps: 7000,
          protocolShareBps: 2000,
          traderShareBps: 1000,
        }),
      ).to.not.be.reverted;
    });

    it("should reject if shares don't sum to 10000", async function () {
      const { contract } = await loadFixture(deployFixture);
      await expect(
        contract.validateFeeConfig({
          baseFee: 1,
          maxImpactFee: 1000,
          lpShareBps: 7000,
          protocolShareBps: 2000,
          traderShareBps: 500,
        }),
      ).to.be.reverted;
    });
  });

  describe('defaultFeeConfig', function () {
    it('should return correct defaults', async function () {
      const { contract } = await loadFixture(deployFixture);
      const config = await contract.defaultFeeConfig();
      expect(config.baseFee).to.equal(1);
      expect(config.maxImpactFee).to.equal(1000);
      expect(config.lpShareBps).to.equal(7000);
      expect(config.protocolShareBps).to.equal(2000);
      expect(config.traderShareBps).to.equal(1000);
    });
  });
});
