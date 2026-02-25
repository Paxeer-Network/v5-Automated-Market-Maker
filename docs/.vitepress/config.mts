import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'v5-ASAMM Protocol',
  description: 'Adaptive Sigmoid Automated Market Maker - Documentation',
  base: '/',
  ignoreDeadLinks: [
    /\/LICENSE/
  ],
  themeConfig: {
    logo: '/logo.svg',
    nav: [
      { text: 'Guide', link: '/guide/introduction' },
      { text: 'API Reference', link: '/api/pool-facet' },
      { text: 'Math', link: '/math/sigmoid-curve' },
      { text: 'Security', link: '/security/threat-model' },
      { text: 'Deployment', link: '/deployment/local' },
      {
        text: 'Paxscan',
        link: 'https://paxscan.paxeer.app/address/0x9595a92d63884d2D9924e0002D45C34d717DB291'
      }
    ],
    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'Introduction', link: '/guide/introduction' },
            { text: 'Architecture', link: '/guide/architecture' },
            { text: 'SDK Integration', link: '/guide/sdk-integration' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'Core Facets',
          items: [
            { text: 'PoolFacet', link: '/api/pool-facet' },
            { text: 'SwapFacet', link: '/api/swap-facet' },
            { text: 'LiquidityFacet', link: '/api/liquidity-facet' },
            { text: 'FeeFacet', link: '/api/fee-facet' },
            { text: 'OracleFacet', link: '/api/oracle-facet' },
            { text: 'OraclePegFacet', link: '/api/oracle-peg-facet' },
            { text: 'OrderFacet', link: '/api/order-facet' },
            { text: 'RewardFacet', link: '/api/reward-facet' },
            { text: 'FlashLoanFacet', link: '/api/flash-loan-facet' }
          ]
        },
        {
          text: 'External',
          items: [
            { text: 'EventEmitter', link: '/api/event-emitter' }
          ]
        }
      ],
      '/math/': [
        {
          text: 'Mathematics',
          items: [
            { text: 'Sigmoid Bonding Curve', link: '/math/sigmoid-curve' },
            { text: 'Progressive Fees', link: '/math/progressive-fees' },
            { text: 'Fixed-Point Arithmetic', link: '/math/fixed-point-arithmetic' }
          ]
        }
      ],
      '/security/': [
        {
          text: 'Security',
          items: [
            { text: 'Threat Model', link: '/security/threat-model' }
          ]
        }
      ],
      '/deployment/': [
        {
          text: 'Deployment',
          items: [
            { text: 'Local Development', link: '/deployment/local' },
            { text: 'Paxeer Network', link: '/deployment/paxeer' }
          ]
        }
      ]
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/Paxeer-Network/v5-Automated-Market-Maker' }
    ],
    search: {
      provider: 'local'
    },
    footer: {
      message: 'Released under the GPL-3.0 License.',
      copyright: 'Copyright (C) 2026 PaxLabs Inc.'
    },
    outline: {
      level: [2, 3]
    }
  },
  markdown: {
    lineNumbers: true
  }
})
