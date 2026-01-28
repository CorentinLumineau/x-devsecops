# Redis Patterns Reference

Advanced Redis patterns and best practices.

## Data Structures

### Strings
```redis
SET key value
GET key
SETEX key seconds value  # With expiration
SETNX key value          # Only if not exists
INCR counter             # Atomic increment
```

### Hashes
```redis
HSET user:123 name "John" age 30
HGET user:123 name
HGETALL user:123
HINCRBY user:123 visits 1
```

### Lists
```redis
LPUSH queue task1 task2  # Push left
RPOP queue               # Pop right
LRANGE queue 0 -1        # All items
LLEN queue               # Length
```

### Sets
```redis
SADD tags redis cache    # Add members
SMEMBERS tags            # All members
SISMEMBER tags redis     # Check membership
SINTER tags1 tags2       # Intersection
```

### Sorted Sets
```redis
ZADD leaderboard 100 player1 95 player2
ZRANGE leaderboard 0 9 WITHSCORES  # Top 10
ZRANK leaderboard player1          # Rank
ZINCRBY leaderboard 5 player1      # Add score
```

## Patterns

### Distributed Lock

```typescript
async function acquireLock(
  lockKey: string,
  ttl: number = 30000
): Promise<string | null> {
  const lockValue = crypto.randomUUID();

  const acquired = await redis.set(
    lockKey,
    lockValue,
    'NX',
    'PX',
    ttl
  );

  return acquired ? lockValue : null;
}

async function releaseLock(
  lockKey: string,
  lockValue: string
): Promise<boolean> {
  // Lua script for atomic check-and-delete
  const script = `
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    else
      return 0
    end
  `;

  const result = await redis.eval(script, 1, lockKey, lockValue);
  return result === 1;
}
```

### Rate Limiter (Sliding Window)

```typescript
async function isRateLimited(
  key: string,
  limit: number,
  windowMs: number
): Promise<boolean> {
  const now = Date.now();
  const windowStart = now - windowMs;

  const multi = redis.multi();

  // Remove old entries
  multi.zremrangebyscore(key, 0, windowStart);

  // Count requests in window
  multi.zcard(key);

  // Add current request
  multi.zadd(key, now, `${now}:${Math.random()}`);

  // Set expiration
  multi.expire(key, Math.ceil(windowMs / 1000));

  const results = await multi.exec();
  const count = results[1][1] as number;

  return count >= limit;
}
```

### Leaky Bucket

```typescript
async function leakyBucket(
  key: string,
  capacity: number,
  leakRate: number // tokens per second
): Promise<boolean> {
  const now = Date.now();

  const script = `
    local bucket = redis.call("get", KEYS[1])
    local last_update = redis.call("get", KEYS[2])

    local tokens = tonumber(bucket) or ${capacity}
    local last = tonumber(last_update) or ${now}

    -- Leak tokens based on time elapsed
    local elapsed = (${now} - last) / 1000
    tokens = math.min(${capacity}, tokens + elapsed * ${leakRate})

    if tokens >= 1 then
      tokens = tokens - 1
      redis.call("set", KEYS[1], tokens)
      redis.call("set", KEYS[2], ${now})
      return 1
    else
      return 0
    end
  `;

  const result = await redis.eval(
    script, 2,
    `${key}:bucket`, `${key}:last`
  );

  return result === 1;
}
```

### Session Storage

```typescript
interface Session {
  userId: string;
  createdAt: number;
  data: Record<string, unknown>;
}

async function createSession(
  sessionId: string,
  session: Session,
  ttl: number = 86400
): Promise<void> {
  await redis.setex(
    `session:${sessionId}`,
    ttl,
    JSON.stringify(session)
  );
}

async function getSession(sessionId: string): Promise<Session | null> {
  const data = await redis.get(`session:${sessionId}`);
  return data ? JSON.parse(data) : null;
}

async function touchSession(
  sessionId: string,
  ttl: number = 86400
): Promise<void> {
  await redis.expire(`session:${sessionId}`, ttl);
}
```

### Pub/Sub

```typescript
// Publisher
await redis.publish('events', JSON.stringify({
  type: 'user.created',
  data: { userId: '123' }
}));

// Subscriber
const subscriber = redis.duplicate();
await subscriber.subscribe('events');

subscriber.on('message', (channel, message) => {
  const event = JSON.parse(message);
  handleEvent(event);
});
```

## Cluster Considerations

### Key Slots
```typescript
// Use hash tags to co-locate related keys
const userKey = `{user:123}:profile`;
const ordersKey = `{user:123}:orders`;
// Both keys hash to same slot
```

### Cross-Slot Operations
```typescript
// Avoid: Cross-slot pipeline
redis.mget('key1', 'key2');  // May fail in cluster

// Use: Per-key operations or hash tags
redis.get('{app}:key1');
redis.get('{app}:key2');
```

## Monitoring Commands

```bash
# Real-time monitoring
redis-cli MONITOR

# Slow queries
redis-cli SLOWLOG GET 10

# Memory analysis
redis-cli MEMORY DOCTOR
redis-cli MEMORY USAGE key

# Client connections
redis-cli CLIENT LIST
```
