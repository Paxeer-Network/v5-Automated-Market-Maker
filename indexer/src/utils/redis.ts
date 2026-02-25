import Redis from 'ioredis';

let redis: Redis | null = null;
let publisher: Redis | null = null;

export function getRedis(): Redis {
  if (!redis) {
    redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
      maxRetriesPerRequest: 3,
      retryStrategy(times) {
        const delay = Math.min(times * 200, 5000);
        return delay;
      },
      lazyConnect: true,
    });
    redis.on('error', (err) => {
      console.error('[Redis] Connection error:', err.message);
    });
    redis.on('connect', () => {
      console.log('[Redis] Connected');
    });
  }
  return redis;
}

export function getPublisher(): Redis {
  if (!publisher) {
    publisher = new Redis(process.env.REDIS_URL || 'redis://localhost:6379', {
      maxRetriesPerRequest: 3,
      lazyConnect: true,
    });
  }
  return publisher;
}

// Cache helpers with TTL
export async function cacheGet<T>(key: string): Promise<T | null> {
  const r = getRedis();
  const val = await r.get(key);
  return val ? JSON.parse(val) : null;
}

export async function cacheSet(key: string, value: any, ttlSeconds = 10): Promise<void> {
  const r = getRedis();
  await r.set(key, JSON.stringify(value), 'EX', ttlSeconds);
}

export async function cacheInvalidate(pattern: string): Promise<void> {
  const r = getRedis();
  const keys = await r.keys(pattern);
  if (keys.length > 0) {
    await r.del(...keys);
  }
}

// Pub/Sub for real-time events
export async function publish(channel: string, data: any): Promise<void> {
  const pub = getPublisher();
  await pub.publish(channel, JSON.stringify(data));
}

export async function connectAll(): Promise<void> {
  await getRedis().connect();
  await getPublisher().connect();
}

export async function disconnectAll(): Promise<void> {
  if (redis) await redis.quit();
  if (publisher) await publisher.quit();
}
