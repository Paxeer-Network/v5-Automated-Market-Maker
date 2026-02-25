import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('FixedPointMath', function () {
  async function deployFixture() {
    const Factory = await ethers.getContractFactory('FixedPointMathTest');
    const contract = await Factory.deploy();
    return { contract };
  }

  const Q128 = 1n << 128n;

  describe('Q128 conversions', function () {
    it('should convert integer to Q128.128', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.toQ128(1)).to.equal(Q128);
      expect(await contract.toQ128(5)).to.equal(5n * Q128);
    });

    it('should convert Q128.128 to integer', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.fromQ128(Q128)).to.equal(1);
      expect(await contract.fromQ128(5n * Q128)).to.equal(5);
    });
  });

  describe('mulQ128', function () {
    it('should multiply Q128 values correctly', async function () {
      const { contract } = await loadFixture(deployFixture);
      // 0.5 * 0.5 = 0.25
      const half = Q128 / 2n;
      const result = await contract.mulQ128(half, half);
      // 0.25 in Q128 = Q128/4
      expect(result).to.equal(Q128 / 4n);
    });

    it('should handle 1.0 * 0.5 = 0.5', async function () {
      const { contract } = await loadFixture(deployFixture);
      const half = Q128 / 2n;
      expect(await contract.mulQ128(Q128, half)).to.equal(half);
    });
  });

  describe('divQ128', function () {
    it('should divide Q128 values correctly', async function () {
      const { contract } = await loadFixture(deployFixture);
      // (Q128/4) / (Q128/2) = 0.25 / 0.5 = 0.5 → Q128/2
      const quarter = Q128 / 4n;
      const half = Q128 / 2n;
      const result = await contract.divQ128(quarter, half);
      expect(result).to.equal(half);
    });

    it('should handle x / 1.0 = x for small values', async function () {
      const { contract } = await loadFixture(deployFixture);
      const x = Q128 / 10n; // 0.1 in Q128
      expect(await contract.divQ128(x, Q128)).to.equal(x);
    });
  });

  describe('tanh (lookup table)', function () {
    it('should return 0 for input 0', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.tanh(0)).to.equal(0);
    });

    it('should clamp for x >= 4.0', async function () {
      const { contract } = await loadFixture(deployFixture);
      const result4 = await contract.tanh(4n * Q128);
      const result10 = await contract.tanh(10n * Q128);
      // Both should return the same clamped value (tanh(4) ≈ 0.99933)
      expect(result4).to.equal(result10);
      // Should be very close to Q128 (within 0.1%)
      expect(result4).to.be.gt((Q128 * 999n) / 1000n);
    });

    it('should return near-linear for small input', async function () {
      const { contract } = await loadFixture(deployFixture);
      // tanh(0.01) ≈ 0.01 for small x
      const smallX = Q128 / 100n;
      const result = await contract.tanh(smallX);
      expect(result).to.be.gt(0n);
      expect(result).to.be.lt(Q128);
      // Should be approximately equal to input (within 1%)
      const diff = result > smallX ? result - smallX : smallX - result;
      expect(diff).to.be.lt(smallX / 50n);
    });

    it('should return ~0.462 for x = 0.5', async function () {
      const { contract } = await loadFixture(deployFixture);
      const result = await contract.tanh(Q128 / 2n);
      // tanh(0.5) ≈ 0.4621, so result ≈ 0.4621 * Q128
      const expected = (Q128 * 4621n) / 10000n;
      const diff = result > expected ? result - expected : expected - result;
      // Within 1% tolerance
      expect(diff).to.be.lt(expected / 100n);
    });

    it('should return ~0.762 for x = 1.0', async function () {
      const { contract } = await loadFixture(deployFixture);
      const result = await contract.tanh(Q128);
      const expected = (Q128 * 7616n) / 10000n;
      const diff = result > expected ? result - expected : expected - result;
      expect(diff).to.be.lt(expected / 100n);
    });

    it('should return ~0.964 for x = 2.0', async function () {
      const { contract } = await loadFixture(deployFixture);
      const result = await contract.tanh(2n * Q128);
      const expected = (Q128 * 9640n) / 10000n;
      const diff = result > expected ? result - expected : expected - result;
      expect(diff).to.be.lt(expected / 100n);
    });

    it('should be monotonically increasing across full range', async function () {
      const { contract } = await loadFixture(deployFixture);
      const r1 = await contract.tanh(Q128 / 100n); // 0.01
      const r2 = await contract.tanh(Q128 / 4n); // 0.25
      const r3 = await contract.tanh(Q128 / 2n); // 0.5
      const r4 = await contract.tanh(Q128); // 1.0
      const r5 = await contract.tanh(2n * Q128); // 2.0
      const r6 = await contract.tanh(3n * Q128); // 3.0
      expect(r1).to.be.lt(r2);
      expect(r2).to.be.lt(r3);
      expect(r3).to.be.lt(r4);
      expect(r4).to.be.lt(r5);
      expect(r5).to.be.lt(r6);
    });

    it('should handle exact table boundary (x = 0.125)', async function () {
      const { contract } = await loadFixture(deployFixture);
      const result = await contract.tanh(Q128 / 8n); // exactly 0.125
      // tanh(0.125) ≈ 0.1244, result should be positive
      expect(result).to.be.gt(0n);
      expect(result).to.be.lt(Q128 / 4n); // < 0.25 * Q128
    });

    it('should handle very large input without reverting', async function () {
      const { contract } = await loadFixture(deployFixture);
      // Should not revert even for huge values
      const result = await contract.tanh(100n * Q128);
      expect(result).to.be.gt(0n);
      expect(result).to.be.lt(Q128);
    });
  });

  describe('sqrt', function () {
    it('should compute sqrt(0) = 0', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.sqrt(0)).to.equal(0);
    });

    it('should compute sqrt(4) = 2', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.sqrt(4)).to.equal(2);
    });

    it('should compute sqrt(100) = 10', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.sqrt(100)).to.equal(10);
    });

    it('should floor for non-perfect squares', async function () {
      const { contract } = await loadFixture(deployFixture);
      // sqrt(10) = 3.16... → floor = 3
      expect(await contract.sqrt(10)).to.equal(3);
    });
  });
});
