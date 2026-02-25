import { ethers } from 'hardhat';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Upgrade Diamond facets on Paxeer with new bytecode.
 * Replaces existing facet selectors and adds new ones.
 *
 * Usage: npx hardhat run scripts/upgrade-facets.ts --network paxeer-network
 */

function getSelectors(contract: any): string[] {
  const selectors: string[] = [];
  for (const fragment of contract.interface.fragments) {
    if (fragment.type === 'function') {
      selectors.push(contract.interface.getFunction(fragment.name)!.selector);
    }
  }
  return selectors;
}

async function main() {
  const [deployer] = await ethers.getSigners();
  const network = await ethers.provider.getNetwork();

  const deployFile = path.join(
    __dirname,
    '..',
    'deployments',
    `paxeer-network-${Number(network.chainId)}.json`,
  );
  if (!fs.existsSync(deployFile)) {
    console.error('No deployment found.');
    process.exit(1);
  }
  const deployment = JSON.parse(fs.readFileSync(deployFile, 'utf8'));
  const diamondAddr = deployment.contracts.Diamond;

  console.log('═'.repeat(60));
  console.log('  Upgrade Diamond Facets');
  console.log('═'.repeat(60));
  console.log(`  Diamond: ${diamondAddr}`);
  console.log('');

  const diamondCut = await ethers.getContractAt('IDiamondCut', diamondAddr);
  const loupe = await ethers.getContractAt('IDiamondLoupe', diamondAddr);

  // Get existing facet addresses for reference
  const existingFacets = await loupe.facetAddresses();
  console.log(`  Existing facets: ${existingFacets.length}`);

  // Deploy new versions of modified facets
  const facetsToUpgrade = ['PoolFacet', 'SwapFacet', 'LiquidityFacet'];
  const cuts: any[] = [];

  for (const facetName of facetsToUpgrade) {
    const oldAddr = deployment.contracts[facetName];
    console.log(`\n  Upgrading ${facetName}...`);
    console.log(`    Old: ${oldAddr}`);

    // Get old selectors
    const oldSelectors = await loupe.facetFunctionSelectors(oldAddr);
    console.log(`    Old selectors: ${oldSelectors.length}`);

    // Deploy new facet
    const Factory = await ethers.getContractFactory(facetName);
    const newFacet = await Factory.deploy();
    await newFacet.waitForDeployment();
    console.log(`    New: ${newFacet.target}`);

    const newSelectors = getSelectors(newFacet);
    console.log(`    New selectors: ${newSelectors.length}`);

    // Find selectors to replace (exist in both old and new)
    const oldSet = new Set(oldSelectors.map((s: string) => s.toLowerCase()));
    const replaceSelectors = newSelectors.filter((s) => oldSet.has(s.toLowerCase()));
    const addSelectors = newSelectors.filter((s) => !oldSet.has(s.toLowerCase()));

    if (replaceSelectors.length > 0) {
      cuts.push({
        facetAddress: newFacet.target,
        action: 1, // Replace
        functionSelectors: replaceSelectors,
      });
      console.log(`    Replace: ${replaceSelectors.length} selectors`);
    }

    if (addSelectors.length > 0) {
      cuts.push({
        facetAddress: newFacet.target,
        action: 0, // Add
        functionSelectors: addSelectors,
      });
      console.log(`    Add: ${addSelectors.length} new selectors`);
    }

    // Update deployment record
    deployment.contracts[facetName] = newFacet.target;
  }

  if (cuts.length === 0) {
    console.log('\n  No changes needed.');
    return;
  }

  // Execute diamond cut
  console.log(`\n  Executing diamond cut (${cuts.length} operations)...`);
  const tx = await diamondCut.diamondCut(cuts, ethers.ZeroAddress, '0x', { gasLimit: 1000000 });
  await tx.wait();
  console.log('  ✅ Diamond cut executed');

  // Verify
  const newFacetCount = (await loupe.facetAddresses()).length;
  console.log(`  Facets after upgrade: ${newFacetCount}`);

  // Save updated deployment
  fs.writeFileSync(
    deployFile,
    JSON.stringify(deployment, (_, v) => (typeof v === 'bigint' ? v.toString() : v), 2),
  );
  console.log('  Deployment file updated');

  console.log('\n' + '═'.repeat(60));
  console.log('  Upgrade Complete!');
  console.log('═'.repeat(60));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
