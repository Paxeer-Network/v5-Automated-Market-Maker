import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('FullMath', function () {
  async function deployFixture() {
    // Deploy a wrapper contract to test the library
    const Factory = await ethers.getContractFactory('FullMathTest');
    const contract = await Factory.deploy();
    return { contract };
  }

  describe('mulDiv', function () {
    it('should return 0 for 0 * x / d', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.mulDiv(0, 100, 1)).to.equal(0);
    });

    it('should compute simple multiplication and division', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.mulDiv(10, 20, 5)).to.equal(40);
    });

    it('should handle large numbers without overflow', async function () {
      const { contract } = await loadFixture(deployFixture);
      const large = ethers.MaxUint256 / 2n;
      const result = await contract.mulDiv(large, 2, 1);
      expect(result).to.equal(large * 2n);
    });

    it('should revert on division by zero', async function () {
      const { contract } = await loadFixture(deployFixture);
      await expect(contract.mulDiv(1, 1, 0)).to.be.reverted;
    });

    it('should handle Q128 precision correctly', async function () {
      const { contract } = await loadFixture(deployFixture);
      const Q128 = 1n << 128n;
      // Use smaller values to avoid 512-bit overflow: (Q128/2 * 2) / 1 = Q128
      const result = await contract.mulDiv(Q128 / 2n, 2, 1);
      expect(result).to.equal(Q128);
    });
  });

  describe('mulDivRoundingUp', function () {
    it('should round up when there is a remainder', async function () {
      const { contract } = await loadFixture(deployFixture);
      // 10 * 3 / 4 = 7.5, rounds up to 8
      expect(await contract.mulDivRoundingUp(10, 3, 4)).to.equal(8);
    });

    it('should not round when exact', async function () {
      const { contract } = await loadFixture(deployFixture);
      expect(await contract.mulDivRoundingUp(10, 4, 4)).to.equal(10);
    });
  });
});
