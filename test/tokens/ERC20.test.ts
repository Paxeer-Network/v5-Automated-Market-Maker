import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('ERC20', function () {
  async function deployFixture() {
    const [owner, alice, bob] = await ethers.getSigners();
    const Factory = await ethers.getContractFactory('MockERC20');
    const token = await Factory.deploy('Test Token', 'TEST', 18);
    await token.mint(owner.address, ethers.parseEther('1000000'));
    return { token, owner, alice, bob };
  }

  describe('Deployment', function () {
    it('should set name, symbol, and decimals', async function () {
      const { token } = await loadFixture(deployFixture);
      expect(await token.name()).to.equal('Test Token');
      expect(await token.symbol()).to.equal('TEST');
      expect(await token.decimals()).to.equal(18);
    });

    it('should mint initial supply to owner', async function () {
      const { token, owner } = await loadFixture(deployFixture);
      expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther('1000000'));
      expect(await token.totalSupply()).to.equal(ethers.parseEther('1000000'));
    });
  });

  describe('transfer', function () {
    it('should transfer tokens between accounts', async function () {
      const { token, owner, alice } = await loadFixture(deployFixture);
      await token.transfer(alice.address, ethers.parseEther('100'));
      expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther('100'));
      expect(await token.balanceOf(owner.address)).to.equal(ethers.parseEther('999900'));
    });

    it('should emit Transfer event', async function () {
      const { token, owner, alice } = await loadFixture(deployFixture);
      await expect(token.transfer(alice.address, 100))
        .to.emit(token, 'Transfer')
        .withArgs(owner.address, alice.address, 100);
    });

    it('should revert on insufficient balance', async function () {
      const { token, alice, bob } = await loadFixture(deployFixture);
      await expect(token.connect(alice).transfer(bob.address, 1)).to.be.revertedWithCustomError(
        token,
        'ERC20_InsufficientBalance',
      );
    });

    it('should revert on transfer to zero address', async function () {
      const { token } = await loadFixture(deployFixture);
      await expect(token.transfer(ethers.ZeroAddress, 1)).to.be.revertedWithCustomError(
        token,
        'ERC20_InvalidRecipient',
      );
    });
  });

  describe('approve and transferFrom', function () {
    it('should approve and allow transferFrom', async function () {
      const { token, owner, alice, bob } = await loadFixture(deployFixture);
      await token.approve(alice.address, ethers.parseEther('500'));
      expect(await token.allowance(owner.address, alice.address)).to.equal(
        ethers.parseEther('500'),
      );

      await token.connect(alice).transferFrom(owner.address, bob.address, ethers.parseEther('200'));
      expect(await token.balanceOf(bob.address)).to.equal(ethers.parseEther('200'));
      expect(await token.allowance(owner.address, alice.address)).to.equal(
        ethers.parseEther('300'),
      );
    });

    it('should revert on insufficient allowance', async function () {
      const { token, owner, alice, bob } = await loadFixture(deployFixture);
      await token.approve(alice.address, 50);
      await expect(
        token.connect(alice).transferFrom(owner.address, bob.address, 100),
      ).to.be.revertedWithCustomError(token, 'ERC20_InsufficientAllowance');
    });

    it('should not decrease max uint allowance', async function () {
      const { token, owner, alice, bob } = await loadFixture(deployFixture);
      await token.approve(alice.address, ethers.MaxUint256);
      await token.connect(alice).transferFrom(owner.address, bob.address, 100);
      expect(await token.allowance(owner.address, alice.address)).to.equal(ethers.MaxUint256);
    });
  });

  describe('mint and burn', function () {
    it('should mint new tokens', async function () {
      const { token, alice } = await loadFixture(deployFixture);
      await token.mint(alice.address, ethers.parseEther('500'));
      expect(await token.balanceOf(alice.address)).to.equal(ethers.parseEther('500'));
    });

    it('should burn tokens', async function () {
      const { token, owner } = await loadFixture(deployFixture);
      const before = await token.totalSupply();
      await token.burn(owner.address, ethers.parseEther('100'));
      expect(await token.totalSupply()).to.equal(before - ethers.parseEther('100'));
    });
  });
});
