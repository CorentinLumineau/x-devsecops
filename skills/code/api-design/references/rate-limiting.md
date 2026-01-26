---
title: Rate Limiting Implementation Reference
category: code
type: reference
version: "1.0.0"
---

# Rate Limiting Implementation

> Part of the code/api-design knowledge skill

## Overview

Rate limiting protects APIs from abuse, ensures fair usage, and maintains service stability. This reference covers rate limiting algorithms, implementation patterns, and best practices for distributed systems.

## Quick Reference (80/20)

| Algorithm | Best For |
|-----------|----------|
| Token Bucket | Allows bursts, smooth rate |
| Sliding Window | Accurate rate limiting |
| Fixed Window | Simple implementation |
| Leaky Bucket | Strict rate enforcement |

| Header | Purpose |
|--------|---------|
| X-RateLimit-Limit | Maximum requests per window |
| X-RateLimit-Remaining | Remaining requests in window |
| X-RateLimit-Reset | Unix timestamp when limit resets |
| Retry-After | Seconds to wait before retry |

## Patterns

### Pattern 1: Token Bucket Algorithm

**When to Use**: Allowing burst traffic while maintaining average rate

**Example**:
```typescript
interface TokenBucket {
  tokens: number;
  lastRefill: number;
  capacity: number;
  refillRate: number; // tokens per second
}

class TokenBucketRateLimiter {
  private buckets: Map<string, TokenBucket> = new Map();

  constructor(
    private capacity: number = 100,
    private refillRate: number = 10 // 10 tokens per second
  ) {}

  async isAllowed(key: string, tokensRequired: number = 1): Promise<RateLimitResult> {
    const now = Date.now();
    let bucket = this.buckets.get(key);

    if (!bucket) {
      bucket = {
        tokens: this.capacity,
        lastRefill: now,
        capacity: this.capacity,
        refillRate: this.refillRate
      };
      this.buckets.set(key, bucket);
    }

    // Refill tokens based on time elapsed
    const timePassed = (now - bucket.lastRefill) / 1000;
    const tokensToAdd = timePassed * bucket.refillRate;
    bucket.tokens = Math.min(bucket.capacity, bucket.tokens + tokensToAdd);
    bucket.lastRefill = now;

    // Check if request is allowed
    if (bucket.tokens >= tokensRequired) {
      bucket.tokens -= tokensRequired;
      return {
        allowed: true,
        remaining: Math.floor(bucket.tokens),
        limit: bucket.capacity,
        resetAt: now + ((bucket.capacity - bucket.tokens) / bucket.refillRate) * 1000
      };
    }

    // Calculate retry time
    const tokensNeeded = tokensRequired - bucket.tokens;
    const retryAfter = Math.ceil(tokensNeeded / bucket.refillRate);

    return {
      allowed: false,
      remaining: 0,
      limit: bucket.capacity,
      resetAt: now + retryAfter * 1000,
      retryAfter
    };
  }
}

// Express middleware
function rateLimitMiddleware(limiter: TokenBucketRateLimiter) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const key = req.ip || req.headers['x-forwarded-for'] as string;
    const result = await limiter.isAllowed(key);

    // Set rate limit headers
    res.setHeader('X-RateLimit-Limit', result.limit);
    res.setHeader('X-RateLimit-Remaining', result.remaining);
    res.setHeader('X-RateLimit-Reset', Math.floor(result.resetAt / 1000));

    if (!result.allowed) {
      res.setHeader('Retry-After', result.retryAfter!);
      return res.status(429).json({
        error: 'Too Many Requests',
        message: `Rate limit exceeded. Retry after ${result.retryAfter} seconds.`,
        retryAfter: result.retryAfter
      });
    }

    next();
  };
}
```

**Anti-Pattern**: Not refilling tokens based on actual time elapsed.

### Pattern 2: Sliding Window Log

**When to Use**: Accurate rate limiting with precise windows

**Example**:
```typescript
interface SlidingWindowConfig {
  windowSize: number; // in milliseconds
  maxRequests: number;
}

class SlidingWindowRateLimiter {
  private requests: Map<string, number[]> = new Map();

  constructor(private config: SlidingWindowConfig) {}

  async isAllowed(key: string): Promise<RateLimitResult> {
    const now = Date.now();
    const windowStart = now - this.config.windowSize;

    // Get request timestamps for this key
    let timestamps = this.requests.get(key) || [];

    // Remove timestamps outside the window
    timestamps = timestamps.filter(ts => ts > windowStart);

    const requestCount = timestamps.length;

    if (requestCount < this.config.maxRequests) {
      // Add current request
      timestamps.push(now);
      this.requests.set(key, timestamps);

      return {
        allowed: true,
        remaining: this.config.maxRequests - requestCount - 1,
        limit: this.config.maxRequests,
        resetAt: timestamps[0] + this.config.windowSize
      };
    }

    // Calculate when the oldest request will expire
    const oldestTimestamp = timestamps[0];
    const retryAfter = Math.ceil((oldestTimestamp + this.config.windowSize - now) / 1000);

    return {
      allowed: false,
      remaining: 0,
      limit: this.config.maxRequests,
      resetAt: oldestTimestamp + this.config.windowSize,
      retryAfter
    };
  }

  // Cleanup old entries periodically
  cleanup(): void {
    const now = Date.now();
    const windowStart = now - this.config.windowSize;

    for (const [key, timestamps] of this.requests.entries()) {
      const filtered = timestamps.filter(ts => ts > windowStart);
      if (filtered.length === 0) {
        this.requests.delete(key);
      } else {
        this.requests.set(key, filtered);
      }
    }
  }
}

// Usage
const limiter = new SlidingWindowRateLimiter({
  windowSize: 60 * 1000, // 1 minute
  maxRequests: 100 // 100 requests per minute
});

// Cleanup every 5 minutes
setInterval(() => limiter.cleanup(), 5 * 60 * 1000);
```

**Anti-Pattern**: Storing all timestamps without cleanup, causing memory leaks.

### Pattern 3: Redis-based Distributed Rate Limiting

**When to Use**: Rate limiting across multiple service instances

**Example**:
```typescript
import Redis from 'ioredis';

interface DistributedRateLimiterConfig {
  windowSize: number;
  maxRequests: number;
  keyPrefix: string;
}

class RedisRateLimiter {
  private redis: Redis;

  constructor(
    redisClient: Redis,
    private config: DistributedRateLimiterConfig
  ) {
    this.redis = redisClient;
  }

  // Sliding window counter using Redis sorted sets
  async isAllowed(identifier: string): Promise<RateLimitResult> {
    const key = `${this.config.keyPrefix}:${identifier}`;
    const now = Date.now();
    const windowStart = now - this.config.windowSize;

    // Use Redis transaction for atomic operations
    const pipeline = this.redis.pipeline();

    // Remove old entries
    pipeline.zremrangebyscore(key, 0, windowStart);

    // Count current entries
    pipeline.zcard(key);

    // Add current request with score = timestamp
    pipeline.zadd(key, now, `${now}:${Math.random()}`);

    // Set expiry
    pipeline.expire(key, Math.ceil(this.config.windowSize / 1000));

    const results = await pipeline.exec();
    const currentCount = results![1][1] as number;

    if (currentCount < this.config.maxRequests) {
      return {
        allowed: true,
        remaining: this.config.maxRequests - currentCount - 1,
        limit: this.config.maxRequests,
        resetAt: now + this.config.windowSize
      };
    }

    // Get oldest entry to calculate retry time
    const oldest = await this.redis.zrange(key, 0, 0, 'WITHSCORES');
    const oldestTimestamp = oldest.length > 1 ? parseInt(oldest[1]) : now;
    const retryAfter = Math.ceil((oldestTimestamp + this.config.windowSize - now) / 1000);

    // Remove the request we just added since it wasn't allowed
    await this.redis.zremrangebyscore(key, now, now);

    return {
      allowed: false,
      remaining: 0,
      limit: this.config.maxRequests,
      resetAt: oldestTimestamp + this.config.windowSize,
      retryAfter
    };
  }

  // Lua script for atomic token bucket
  private tokenBucketScript = `
    local key = KEYS[1]
    local capacity = tonumber(ARGV[1])
    local refillRate = tonumber(ARGV[2])
    local requested = tonumber(ARGV[3])
    local now = tonumber(ARGV[4])

    local bucket = redis.call('HMGET', key, 'tokens', 'lastRefill')
    local tokens = tonumber(bucket[1]) or capacity
    local lastRefill = tonumber(bucket[2]) or now

    -- Refill tokens
    local elapsed = (now - lastRefill) / 1000
    tokens = math.min(capacity, tokens + elapsed * refillRate)

    local allowed = 0
    if tokens >= requested then
      tokens = tokens - requested
      allowed = 1
    end

    redis.call('HMSET', key, 'tokens', tokens, 'lastRefill', now)
    redis.call('EXPIRE', key, math.ceil(capacity / refillRate) + 1)

    return {allowed, math.floor(tokens), capacity}
  `;

  async tokenBucket(
    identifier: string,
    capacity: number,
    refillRate: number,
    requested: number = 1
  ): Promise<RateLimitResult> {
    const key = `${this.config.keyPrefix}:bucket:${identifier}`;
    const now = Date.now();

    const result = await this.redis.eval(
      this.tokenBucketScript,
      1,
      key,
      capacity,
      refillRate,
      requested,
      now
    ) as [number, number, number];

    const [allowed, remaining, limit] = result;

    return {
      allowed: allowed === 1,
      remaining,
      limit,
      resetAt: now + ((limit - remaining) / refillRate) * 1000,
      retryAfter: allowed ? undefined : Math.ceil((requested - remaining) / refillRate)
    };
  }
}

// Usage with Redis cluster
const redis = new Redis.Cluster([
  { host: 'redis-1', port: 6379 },
  { host: 'redis-2', port: 6379 },
  { host: 'redis-3', port: 6379 }
]);

const limiter = new RedisRateLimiter(redis, {
  windowSize: 60 * 1000,
  maxRequests: 1000,
  keyPrefix: 'ratelimit'
});
```

**Anti-Pattern**: Using separate Redis commands instead of atomic transactions.

### Pattern 4: Tiered Rate Limiting

**When to Use**: Different limits for different user types or endpoints

**Example**:
```typescript
interface RateLimitTier {
  name: string;
  requestsPerMinute: number;
  requestsPerHour: number;
  requestsPerDay: number;
  burstCapacity: number;
}

const tiers: Record<string, RateLimitTier> = {
  free: {
    name: 'Free',
    requestsPerMinute: 10,
    requestsPerHour: 100,
    requestsPerDay: 1000,
    burstCapacity: 20
  },
  basic: {
    name: 'Basic',
    requestsPerMinute: 60,
    requestsPerHour: 1000,
    requestsPerDay: 10000,
    burstCapacity: 100
  },
  premium: {
    name: 'Premium',
    requestsPerMinute: 300,
    requestsPerHour: 10000,
    requestsPerDay: 100000,
    burstCapacity: 500
  },
  enterprise: {
    name: 'Enterprise',
    requestsPerMinute: 1000,
    requestsPerHour: 50000,
    requestsPerDay: 500000,
    burstCapacity: 2000
  }
};

class TieredRateLimiter {
  private limiters: Map<string, RedisRateLimiter> = new Map();

  constructor(private redis: Redis) {}

  async isAllowed(
    userId: string,
    userTier: string,
    endpoint?: string
  ): Promise<RateLimitResult & { tier: string }> {
    const tier = tiers[userTier] || tiers.free;

    // Check multiple windows
    const checks = await Promise.all([
      this.checkWindow(userId, 'minute', tier.requestsPerMinute, 60 * 1000),
      this.checkWindow(userId, 'hour', tier.requestsPerHour, 60 * 60 * 1000),
      this.checkWindow(userId, 'day', tier.requestsPerDay, 24 * 60 * 60 * 1000)
    ]);

    // Find the most restrictive result
    const denied = checks.find(c => !c.allowed);

    if (denied) {
      return {
        ...denied,
        tier: tier.name
      };
    }

    // All checks passed, return the result with lowest remaining
    const mostRestrictive = checks.reduce((min, check) =>
      check.remaining < min.remaining ? check : min
    );

    return {
      ...mostRestrictive,
      tier: tier.name
    };
  }

  private async checkWindow(
    userId: string,
    window: string,
    limit: number,
    windowSize: number
  ): Promise<RateLimitResult> {
    const key = `ratelimit:${userId}:${window}`;
    // Implementation using Redis sliding window
    // ... (similar to previous pattern)
    return { allowed: true, remaining: limit, limit, resetAt: Date.now() + windowSize };
  }
}

// Middleware with tier detection
function tieredRateLimitMiddleware(limiter: TieredRateLimiter) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const userId = req.user?.id || req.ip;
    const userTier = req.user?.subscriptionTier || 'free';

    const result = await limiter.isAllowed(userId, userTier, req.path);

    // Set headers
    res.setHeader('X-RateLimit-Limit', result.limit);
    res.setHeader('X-RateLimit-Remaining', result.remaining);
    res.setHeader('X-RateLimit-Reset', Math.floor(result.resetAt / 1000));
    res.setHeader('X-RateLimit-Tier', result.tier);

    if (!result.allowed) {
      res.setHeader('Retry-After', result.retryAfter!);
      return res.status(429).json({
        error: 'Too Many Requests',
        message: `Rate limit exceeded for ${result.tier} tier`,
        retryAfter: result.retryAfter,
        upgradeUrl: '/pricing'
      });
    }

    next();
  };
}
```

**Anti-Pattern**: Using the same rate limits for all users regardless of plan.

### Pattern 5: Endpoint-specific Rate Limiting

**When to Use**: Different limits for different operations

**Example**:
```typescript
interface EndpointConfig {
  pattern: RegExp;
  method?: string;
  limit: number;
  windowSize: number;
  cost?: number; // For weighted rate limiting
}

const endpointConfigs: EndpointConfig[] = [
  // Expensive operations
  { pattern: /^\/api\/export/, method: 'POST', limit: 5, windowSize: 60000, cost: 10 },
  { pattern: /^\/api\/reports/, method: 'POST', limit: 10, windowSize: 60000, cost: 5 },

  // Write operations
  { pattern: /^\/api\/.*/, method: 'POST', limit: 100, windowSize: 60000, cost: 2 },
  { pattern: /^\/api\/.*/, method: 'PUT', limit: 100, windowSize: 60000, cost: 2 },
  { pattern: /^\/api\/.*/, method: 'DELETE', limit: 50, windowSize: 60000, cost: 2 },

  // Read operations (default)
  { pattern: /^\/api\/.*/, method: 'GET', limit: 500, windowSize: 60000, cost: 1 }
];

class EndpointRateLimiter {
  constructor(private redis: Redis) {}

  private findConfig(path: string, method: string): EndpointConfig | null {
    return endpointConfigs.find(config => {
      if (config.method && config.method !== method) return false;
      return config.pattern.test(path);
    }) || null;
  }

  async isAllowed(
    userId: string,
    path: string,
    method: string
  ): Promise<RateLimitResult & { endpoint: string }> {
    const config = this.findConfig(path, method);

    if (!config) {
      // No rate limit configured
      return {
        allowed: true,
        remaining: Infinity,
        limit: Infinity,
        resetAt: 0,
        endpoint: 'unlimited'
      };
    }

    const key = `ratelimit:${userId}:${config.pattern.source}:${method}`;
    const cost = config.cost || 1;

    // Use token bucket for weighted rate limiting
    const result = await this.tokenBucket(
      key,
      config.limit,
      config.limit / (config.windowSize / 1000),
      cost
    );

    return {
      ...result,
      endpoint: `${method} ${config.pattern.source}`
    };
  }

  private async tokenBucket(
    key: string,
    capacity: number,
    refillRate: number,
    cost: number
  ): Promise<RateLimitResult> {
    // Implementation
    return { allowed: true, remaining: capacity, limit: capacity, resetAt: Date.now() };
  }
}

// GraphQL-specific rate limiting
class GraphQLRateLimiter {
  private operationCosts: Record<string, number> = {
    // Queries
    'users': 1,
    'user': 1,
    'orders': 2,
    'searchProducts': 5,
    'generateReport': 50,

    // Mutations
    'createUser': 5,
    'updateUser': 2,
    'deleteUser': 5,
    'createOrder': 10
  };

  calculateQueryCost(query: string, variables: any): number {
    // Parse query and calculate cost based on operations
    // This is a simplified version
    let totalCost = 0;

    for (const [operation, cost] of Object.entries(this.operationCosts)) {
      if (query.includes(operation)) {
        totalCost += cost;
      }
    }

    // Add cost for pagination
    if (variables?.first) {
      totalCost += Math.ceil(variables.first / 10);
    }

    return Math.max(1, totalCost);
  }
}
```

**Anti-Pattern**: Applying uniform rate limits to all endpoints regardless of cost.

### Pattern 6: Rate Limit Response Handling

**When to Use**: Client-side rate limit handling

**Example**:
```typescript
// Server-side: Consistent response format
interface RateLimitResponse {
  error: {
    code: 'RATE_LIMIT_EXCEEDED';
    message: string;
    details: {
      limit: number;
      remaining: number;
      resetAt: string; // ISO timestamp
      retryAfter: number; // seconds
      tier?: string;
      endpoint?: string;
    };
  };
}

function sendRateLimitResponse(res: Response, result: RateLimitResult): void {
  res.status(429).json({
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'You have exceeded the rate limit. Please try again later.',
      details: {
        limit: result.limit,
        remaining: result.remaining,
        resetAt: new Date(result.resetAt).toISOString(),
        retryAfter: result.retryAfter
      }
    }
  });
}

// Client-side: Automatic retry with exponential backoff
class RateLimitAwareClient {
  private maxRetries = 3;
  private baseDelay = 1000;

  async request<T>(
    url: string,
    options: RequestInit = {}
  ): Promise<T> {
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        const response = await fetch(url, options);

        // Store rate limit info for monitoring
        this.updateRateLimitInfo(response.headers);

        if (response.status === 429) {
          const retryAfter = this.getRetryAfter(response);

          if (attempt < this.maxRetries) {
            await this.delay(retryAfter * 1000);
            continue;
          }

          throw new RateLimitError('Rate limit exceeded', retryAfter);
        }

        if (!response.ok) {
          throw new ApiError(`HTTP ${response.status}`, response.status);
        }

        return await response.json();
      } catch (error) {
        lastError = error as Error;

        if (error instanceof RateLimitError && attempt < this.maxRetries) {
          await this.delay(error.retryAfter * 1000);
          continue;
        }

        throw error;
      }
    }

    throw lastError || new Error('Request failed');
  }

  private getRetryAfter(response: Response): number {
    const retryAfter = response.headers.get('Retry-After');
    if (retryAfter) {
      const seconds = parseInt(retryAfter);
      if (!isNaN(seconds)) return seconds;
    }

    // Fallback: use Reset header
    const reset = response.headers.get('X-RateLimit-Reset');
    if (reset) {
      const resetTime = parseInt(reset) * 1000;
      return Math.ceil((resetTime - Date.now()) / 1000);
    }

    // Default exponential backoff
    return this.baseDelay / 1000;
  }

  private updateRateLimitInfo(headers: Headers): void {
    const info = {
      limit: parseInt(headers.get('X-RateLimit-Limit') || '0'),
      remaining: parseInt(headers.get('X-RateLimit-Remaining') || '0'),
      reset: parseInt(headers.get('X-RateLimit-Reset') || '0')
    };

    // Emit event for monitoring
    this.emit('rateLimitUpdate', info);

    // Warn if getting close to limit
    if (info.remaining < info.limit * 0.1) {
      console.warn(`Rate limit warning: ${info.remaining}/${info.limit} remaining`);
    }
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

class RateLimitError extends Error {
  constructor(message: string, public retryAfter: number) {
    super(message);
    this.name = 'RateLimitError';
  }
}
```

**Anti-Pattern**: Ignoring rate limit headers and blindly retrying.

## Checklist

- [ ] Rate limiting algorithm chosen based on requirements
- [ ] Distributed rate limiting for multi-instance deployments
- [ ] Standard headers (X-RateLimit-*) included in responses
- [ ] Retry-After header provided on 429 responses
- [ ] Different limits for different user tiers
- [ ] Endpoint-specific limits for expensive operations
- [ ] Graceful degradation when rate limit service is unavailable
- [ ] Monitoring and alerting on rate limit hits
- [ ] Client SDK handles rate limits automatically
- [ ] Documentation clearly explains rate limits

## References

- [IETF Rate Limiting Headers](https://datatracker.ietf.org/doc/draft-ietf-httpapi-ratelimit-headers/)
- [Token Bucket Algorithm](https://en.wikipedia.org/wiki/Token_bucket)
- [Redis Rate Limiting](https://redis.io/commands/incr#pattern-rate-limiter)
- [Stripe Rate Limiting](https://stripe.com/docs/rate-limits)
