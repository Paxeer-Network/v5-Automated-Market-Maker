import 'dotenv/config';
import http from 'http';
import { parse as parseUrl } from 'url';
import { ApolloServer } from '@apollo/server';
import { ApolloServerPluginDrainHttpServer } from '@apollo/server/plugin/drainHttpServer';
import { ApolloServerPluginLandingPageLocalDefault } from '@apollo/server/plugin/landingPage/default';
import { typeDefs } from './resolvers/schema';
import { resolvers } from './resolvers/resolvers';
import { migrate } from './utils/migrate';
import { connectAll, disconnectAll } from './utils/redis';
import { getPool } from './utils/db';
import { Indexer } from './services/indexer';

const PORT = parseInt(process.env.PORT || '4000', 10);

// Embedded GraphQL Playground HTML (uses GraphiQL via CDN)
const PLAYGROUND_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>v5-ASAMM Indexer — GraphQL Playground</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⚡</text></svg>">
  <style>body{margin:0;overflow:hidden;height:100vh}#graphiql{height:100vh}</style>
  <link rel="stylesheet" href="https://unpkg.com/graphiql@3/graphiql.min.css" />
</head>
<body>
  <div id="graphiql"></div>
  <script src="https://unpkg.com/react@18/umd/react.production.min.js" crossorigin></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js" crossorigin></script>
  <script src="https://unpkg.com/graphiql@3/graphiql.min.js" crossorigin></script>
  <script>
    const fetcher = GraphiQL.createFetcher({ url: window.location.origin + '/graphql' });
    const root = ReactDOM.createRoot(document.getElementById('graphiql'));
    root.render(
      React.createElement(GraphiQL, {
        fetcher,
        defaultQuery: \`# v5-ASAMM Protocol Indexer
#
# Example queries:

# Get all pools
query GetPools {
  pools(limit: 10) {
    poolId
    token0
    token1
    totalSwaps
    reserve0
    reserve1
    liquidity
    initialized
  }
}

# Indexer status
# query Status {
#   indexerStatus {
#     lastIndexedBlock
#     latestBlock
#     behind
#     poolCount
#     totalSwaps
#   }
# }

# Recent swaps
# query RecentSwaps {
#   recentSwaps(limit: 10) {
#     poolId
#     sender
#     amount0
#     amount1
#     feeAmount
#     timestamp
#     txHash
#   }
# }

# Pool stats with 24h analytics
# query Stats {
#   poolStats(poolId: "0x...") {
#     totalSwaps
#     totalVolume0
#     uniqueTraders
#     swaps24h
#     volume0_24h
#   }
# }
\`,
      })
    );
  </script>
</body>
</html>`;

async function main() {
  console.log('='.repeat(50));
  console.log('  v5-ASAMM Protocol Indexer');
  console.log('='.repeat(50));

  // 1. Run migrations
  console.log('[Boot] Running database migrations...');
  await migrate();

  // 2. Connect Redis
  console.log('[Boot] Connecting to Redis...');
  try {
    await connectAll();
  } catch (err: any) {
    console.warn(`[Boot] Redis not available (${err.message}), continuing without cache`);
  }

  // 3. Start the indexer
  const indexer = new Indexer({
    rpcUrl: process.env.RPC_URL || 'https://public-rpc.paxeer.app/rpc',
    eventEmitterAddress: process.env.EVENT_EMITTER_ADDRESS || '0x3FCa66c12B99e395619EE4d0aeabC2339F97E1FF',
    pollIntervalMs: parseInt(process.env.POLL_INTERVAL_MS || '3000', 10),
    batchSize: parseInt(process.env.BATCH_SIZE || '1000', 10),
  });

  // Start indexer in background
  indexer.start().catch((err) => {
    console.error('[Indexer] Fatal error:', err);
  });

  // 4. Start Apollo GraphQL server
  const httpServer = http.createServer();
  const server = new ApolloServer({
    typeDefs,
    resolvers,
    plugins: [
      ApolloServerPluginDrainHttpServer({ httpServer }),
      ApolloServerPluginLandingPageLocalDefault({ embed: true, footer: false }),
    ],
    introspection: true,
  });

  await server.start();

  httpServer.on('request', async (req, res) => {
    const url = parseUrl(req.url || '/', true);
    const pathname = url.pathname || '/';

    // CORS headers on every response
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Apollo-Require-Preflight');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    // Health check
    if (pathname === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      try {
        const status = await indexer.getStatus();
        res.end(JSON.stringify({ status: 'ok', ...status }));
      } catch {
        res.end(JSON.stringify({ status: 'ok' }));
      }
      return;
    }

    // GraphiQL playground on GET /graphql or GET /
    if (req.method === 'GET' && (pathname === '/graphql' || pathname === '/')) {
      const accept = (req.headers.accept || '').toLowerCase();
      // If browser is requesting HTML, serve the playground
      if (accept.includes('text/html')) {
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(PLAYGROUND_HTML);
        return;
      }
    }

    // GraphQL POST endpoint
    if (pathname === '/graphql' || pathname === '/') {
      if (req.method === 'POST') {
        let body = '';
        req.on('data', (chunk) => { body += chunk; });
        req.on('end', async () => {
          try {
            const parsed = JSON.parse(body || '{}');
            const { query: gqlQuery, variables, operationName } = parsed;

            if (!gqlQuery) {
              res.writeHead(400, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ errors: [{ message: 'Missing query in request body' }] }));
              return;
            }

            const result = await server.executeOperation(
              { query: gqlQuery, variables, operationName },
              { contextValue: { indexer } }
            );

            res.writeHead(200, { 'Content-Type': 'application/json' });
            if (result.body.kind === 'single') {
              res.end(JSON.stringify(result.body.singleResult));
            } else {
              res.end(JSON.stringify({ errors: [{ message: 'Incremental delivery not supported' }] }));
            }
          } catch (err: any) {
            res.writeHead(400, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ errors: [{ message: err.message }] }));
          }
        });
        return;
      }

      // GET with no HTML accept header — return schema info
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        name: 'v5-ASAMM Protocol Indexer',
        version: '0.1.0',
        graphql: '/graphql',
        playground: 'Open /graphql in a browser for GraphiQL',
        health: '/health',
      }));
      return;
    }

    res.writeHead(404);
    res.end('Not Found');
  });

  httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`[Server] GraphQL API running at http://0.0.0.0:${PORT}/graphql`);
    console.log(`[Server] GraphiQL Playground at http://0.0.0.0:${PORT}/graphql (open in browser)`);
    console.log(`[Server] Health check at http://0.0.0.0:${PORT}/health`);
  });

  // Graceful shutdown
  const shutdown = async () => {
    console.log('\n[Shutdown] Graceful shutdown initiated...');
    indexer.stop();
    await server.stop();
    httpServer.close();
    await disconnectAll();
    await getPool().end();
    console.log('[Shutdown] Complete');
    process.exit(0);
  };

  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}

main().catch((err) => {
  console.error('[Fatal]', err);
  process.exit(1);
});
