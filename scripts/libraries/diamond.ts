import { ethers } from 'hardhat';
import { Contract, ContractFactory } from 'ethers';

export interface FacetCut {
  facetAddress: string;
  action: number; // 0=Add, 1=Replace, 2=Remove
  functionSelectors: string[];
}

export const FacetCutAction = {
  Add: 0,
  Replace: 1,
  Remove: 2,
};

/**
 * Get all function selectors from a contract's ABI
 */
export function getSelectors(contract: Contract): string[] {
  const selectors: string[] = [];
  const fragments = contract.interface.fragments;

  for (const fragment of fragments) {
    if (fragment.type === 'function') {
      const selector = contract.interface.getFunction(fragment.name)?.selector;
      if (selector) {
        selectors.push(selector);
      }
    }
  }

  return selectors;
}

/**
 * Get selectors excluding specific function names
 */
export function getSelectorsExcept(contract: Contract, excludeNames: string[]): string[] {
  const selectors: string[] = [];
  const fragments = contract.interface.fragments;

  for (const fragment of fragments) {
    if (fragment.type === 'function' && !excludeNames.includes(fragment.name)) {
      const selector = contract.interface.getFunction(fragment.name)?.selector;
      if (selector) {
        selectors.push(selector);
      }
    }
  }

  return selectors;
}

/**
 * Build FacetCut array for adding facets to the Diamond
 */
export function buildFacetCuts(facets: { name: string; contract: Contract }[]): FacetCut[] {
  return facets.map((facet) => ({
    facetAddress: facet.contract.target as string,
    action: FacetCutAction.Add,
    functionSelectors: getSelectors(facet.contract),
  }));
}

/**
 * Deploy the Diamond with all facets
 */
export async function deployDiamond(
  owner: string,
  facetNames: string[],
  initArgs: {
    treasury: string;
    flashLoanFeeBps: number;
    maxOrdersPerPool: number;
    defaultOrderTTL: number;
    minOrderSize: bigint;
    keeperBountyBps: number;
    epochDuration: number;
    minSwapsForRebate: number;
    maxTradeSizeBps: number;
  },
): Promise<{
  diamond: Contract;
  facets: Record<string, Contract>;
}> {
  console.log('Deploying Diamond...\n');

  // Deploy DiamondCutFacet first
  const DiamondCutFacet = await ethers.getContractFactory('DiamondCutFacet');
  const diamondCutFacet = await DiamondCutFacet.deploy();
  await diamondCutFacet.waitForDeployment();
  console.log(`  DiamondCutFacet deployed: ${diamondCutFacet.target}`);

  // Deploy Diamond
  const Diamond = await ethers.getContractFactory('Diamond');
  const diamond = await Diamond.deploy(owner, diamondCutFacet.target);
  await diamond.waitForDeployment();
  console.log(`  Diamond deployed: ${diamond.target}`);

  // Deploy remaining facets
  const facets: Record<string, Contract> = {
    DiamondCutFacet: diamondCutFacet,
  };
  const facetCuts: FacetCut[] = [];

  for (const facetName of facetNames) {
    if (facetName === 'DiamondCutFacet') continue; // Already deployed

    const FacetFactory = await ethers.getContractFactory(facetName);
    const facet = await FacetFactory.deploy();
    await facet.waitForDeployment();
    console.log(`  ${facetName} deployed: ${facet.target}`);

    facets[facetName] = facet;

    facetCuts.push({
      facetAddress: facet.target as string,
      action: FacetCutAction.Add,
      functionSelectors: getSelectors(facet),
    });
  }

  // Deploy InitDiamond
  const InitDiamond = await ethers.getContractFactory('InitDiamond');
  const initDiamond = await InitDiamond.deploy();
  await initDiamond.waitForDeployment();
  console.log(`  InitDiamond deployed: ${initDiamond.target}`);

  // Execute diamond cut with initialization
  const diamondCut = await ethers.getContractAt('IDiamondCut', diamond.target as string);

  const initCalldata = initDiamond.interface.encodeFunctionData('init', [initArgs]);

  const tx = await diamondCut.diamondCut(facetCuts, initDiamond.target, initCalldata);
  await tx.wait();
  console.log(`\n  Diamond cut executed (${facetCuts.length} facets added)`);

  return { diamond, facets };
}
