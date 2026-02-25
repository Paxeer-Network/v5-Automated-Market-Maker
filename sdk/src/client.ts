import { ethers } from 'ethers';
import { getAddresses, ChainAddresses } from './addresses';
import {
  DiamondABI,
  PoolFacetABI,
  SwapFacetABI,
  LiquidityFacetABI,
  FeeFacetABI,
  OracleFacetABI,
  OraclePegFacetABI,
  OrderFacetABI,
  RewardFacetABI,
  FlashLoanFacetABI,
  EventEmitterABI,
  RouterABI,
  QuoterABI,
} from './abis';

export interface ASAMMClientConfig {
  diamondAddress?: string;
  signerOrProvider: ethers.Signer | ethers.Provider;
  chainId?: number;
}

export class ASAMMClient {
  readonly diamond: ethers.Contract;
  readonly addresses: ChainAddresses;
  private readonly signerOrProvider: ethers.Signer | ethers.Provider;

  constructor(config: ASAMMClientConfig) {
    if (config.chainId) {
      this.addresses = getAddresses(config.chainId);
    } else if (config.diamondAddress) {
      // Use provided address with Paxeer defaults for other contracts
      this.addresses = { ...getAddresses(125), Diamond: config.diamondAddress };
    } else {
      this.addresses = getAddresses(125);
    }

    this.signerOrProvider = config.signerOrProvider;
    this.diamond = new ethers.Contract(this.addresses.Diamond, DiamondABI, this.signerOrProvider);
  }

  // ── Facet-scoped contract accessors ──

  pool(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, PoolFacetABI, this.signerOrProvider);
  }

  swap(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, SwapFacetABI, this.signerOrProvider);
  }

  liquidity(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, LiquidityFacetABI, this.signerOrProvider);
  }

  fee(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, FeeFacetABI, this.signerOrProvider);
  }

  oracle(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, OracleFacetABI, this.signerOrProvider);
  }

  oraclePeg(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, OraclePegFacetABI, this.signerOrProvider);
  }

  order(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, OrderFacetABI, this.signerOrProvider);
  }

  reward(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, RewardFacetABI, this.signerOrProvider);
  }

  flashLoan(): ethers.Contract {
    return new ethers.Contract(this.addresses.Diamond, FlashLoanFacetABI, this.signerOrProvider);
  }

  // ── Periphery contract accessors ──

  router(): ethers.Contract {
    return new ethers.Contract(this.addresses.Router, RouterABI, this.signerOrProvider);
  }

  quoter(): ethers.Contract {
    return new ethers.Contract(this.addresses.Quoter, QuoterABI, this.signerOrProvider);
  }

  eventEmitter(): ethers.Contract {
    return new ethers.Contract(this.addresses.EventEmitter, EventEmitterABI, this.signerOrProvider);
  }

  // ── Convenience methods ──

  async getPoolState(poolId: string) {
    return this.pool().getPoolState(poolId);
  }

  async computePoolId(token0: string, token1: string, tickSpacing: number): Promise<string> {
    return this.pool().computePoolId(token0, token1, tickSpacing);
  }

  async getPoolCount(): Promise<bigint> {
    return this.pool().getPoolCount();
  }

  async quoteSwap(params: {
    tokenIn: string;
    tokenOut: string;
    tickSpacing: number;
    amountIn: bigint;
    sqrtPriceLimitX96?: bigint;
  }) {
    return this.quoter().quoteExactInputSingle.staticCall({
      tokenIn: params.tokenIn,
      tokenOut: params.tokenOut,
      tickSpacing: params.tickSpacing,
      amountIn: params.amountIn,
      sqrtPriceLimitX96: params.sqrtPriceLimitX96 || 0n,
    });
  }
}
