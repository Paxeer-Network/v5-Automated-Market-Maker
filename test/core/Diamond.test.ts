import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';

describe('Diamond', function () {
  async function deployDiamondFixture() {
    const [owner, alice] = await ethers.getSigners();

    // Deploy DiamondCutFacet
    const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
    const diamondCutFacet = await DiamondCutFacet.deploy();

    // Deploy Diamond
    const Diamond = await ethers.getContractFactory('Diamond');
    const diamond = await Diamond.deploy(owner.address, diamondCutFacet.target);

    // Deploy DiamondLoupeFacet
    const DiamondLoupeFacet = await ethers.getContractFactory('DiamondLoupeFacet');
    const loupeFacet = await DiamondLoupeFacet.deploy();

    // Deploy OwnershipFacet
    const OwnershipFacet = await ethers.getContractFactory('OwnershipFacet');
    const ownershipFacet = await OwnershipFacet.deploy();

    // Add loupe and ownership facets via diamondCut
    const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.target);

    const loupeSelectors = [
      loupeFacet.interface.getFunction('facets')!.selector,
      loupeFacet.interface.getFunction('facetFunctionSelectors')!.selector,
      loupeFacet.interface.getFunction('facetAddresses')!.selector,
      loupeFacet.interface.getFunction('facetAddress')!.selector,
      loupeFacet.interface.getFunction('supportsInterface')!.selector,
    ];

    const ownershipSelectors = [
      ownershipFacet.interface.getFunction('owner')!.selector,
      ownershipFacet.interface.getFunction('transferOwnership')!.selector,
    ];

    await diamondCut.diamondCut(
      [
        {
          facetAddress: loupeFacet.target,
          action: 0, // Add
          functionSelectors: loupeSelectors,
        },
        {
          facetAddress: ownershipFacet.target,
          action: 0, // Add
          functionSelectors: ownershipSelectors,
        },
      ],
      ethers.ZeroAddress,
      '0x',
    );

    const loupe = await ethers.getContractAt('IDiamondLoupe', diamond.target);
    const ownership = await ethers.getContractAt('OwnershipFacet', diamond.target);

    return {
      diamond,
      diamondCut,
      loupe,
      ownership,
      diamondCutFacet,
      loupeFacet,
      ownershipFacet,
      owner,
      alice,
    };
  }

  describe('Deployment', function () {
    it('should have DiamondCutFacet as first facet', async function () {
      const { loupe, diamondCutFacet } = await loadFixture(deployDiamondFixture);
      const addresses = await loupe.facetAddresses();
      expect(addresses[0]).to.equal(diamondCutFacet.target);
    });

    it('should have three facets after setup', async function () {
      const { loupe } = await loadFixture(deployDiamondFixture);
      const addresses = await loupe.facetAddresses();
      expect(addresses.length).to.equal(3);
    });
  });

  describe('DiamondLoupe', function () {
    it('should return correct selectors for each facet', async function () {
      const { loupe, loupeFacet } = await loadFixture(deployDiamondFixture);
      const selectors = await loupe.facetFunctionSelectors(loupeFacet.target);
      expect(selectors.length).to.equal(5);
    });

    it('should return correct facet for a selector', async function () {
      const { loupe, ownershipFacet } = await loadFixture(deployDiamondFixture);
      const ownerSelector = ownershipFacet.interface.getFunction('owner')!.selector;
      const facetAddr = await loupe.facetAddress(ownerSelector);
      expect(facetAddr).to.equal(ownershipFacet.target);
    });
  });

  describe('Ownership', function () {
    it('should return correct owner', async function () {
      const { ownership, owner } = await loadFixture(deployDiamondFixture);
      expect(await ownership.owner()).to.equal(owner.address);
    });

    it('should transfer ownership', async function () {
      const { ownership, alice } = await loadFixture(deployDiamondFixture);
      await ownership.transferOwnership(alice.address);
      expect(await ownership.owner()).to.equal(alice.address);
    });

    it('should prevent non-owner from transferring', async function () {
      const { ownership, alice } = await loadFixture(deployDiamondFixture);
      await expect(ownership.connect(alice).transferOwnership(alice.address)).to.be.reverted;
    });
  });

  describe('DiamondCut', function () {
    it('should revert when non-owner tries to cut', async function () {
      const { diamondCut, alice, loupeFacet } = await loadFixture(deployDiamondFixture);
      await expect(diamondCut.connect(alice).diamondCut([], ethers.ZeroAddress, '0x')).to.be
        .reverted;
    });
  });

  describe('Fallback', function () {
    it('should revert for unknown function selector', async function () {
      const { diamond } = await loadFixture(deployDiamondFixture);
      // Call a random function selector that doesn't exist
      await expect(
        ethers.provider.call({
          to: diamond.target,
          data: '0xdeadbeef',
        }),
      ).to.be.reverted;
    });
  });
});
