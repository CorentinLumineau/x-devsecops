---
name: caching
description: |
  Caching patterns, Redis, cache invalidation, and distributed caching strategies.
  Activate when implementing caching, optimizing performance, or handling cache invalidation.
  Triggers: cache, redis, memcached, ttl, invalidation, cdn, session, distributed.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: data
---

# Caching

Caching patterns and distributed cache strategies.

## 80/20 Focus

Master these patterns (covers 80% of caching needs):

| Pattern | When to Use | Complexity |
|---------|-------------|------------|
| Cache-Aside | Default choice | Low |
| TTL-based | Time-sensitive data | Low |
| Cache Invalidation | Write-heavy | Medium |
| Read-Through | Simple reads | Low |

## Cache Strategies

### Cache-Aside (Lazy Loading)

```
Read:
1. Check cache
2. If miss: fetch from DB, store in cache
3. Return data

Write:
1. Update DB
2. Invalidate cache (delete key)
```

```typescript
async function getUser(id: string): Promise<User> {
  // 1. Check cache
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  // 2. Cache miss: fetch from DB
  const user = await db.users.findById(id);

  // 3. Store in cache with TTL
  await redis.setex(`user:${id}`, 3600, JSON.stringify(user));

  return user;
}
```

### Write-Through

```
Write:
1. Write to cache
2. Cache writes to DB (synchronously)

Read:
1. Always read from cache
```

**Pros**: Cache always consistent
**Cons**: Write latency

### Write-Behind (Write-Back)

```
Write:
1. Write to cache
2. Async batch write to DB

Read:
1. Always read from cache
```

**Pros**: Fast writes
**Cons**: Data loss risk, complexity

### Read-Through

```
Read:
1. Read from cache
2. Cache fetches from DB on miss (cache handles it)
```

## Cache Invalidation

### Time-Based (TTL)

```typescript
// Short TTL for frequently changing data
redis.setex('stock_price:AAPL', 60, price);  // 1 minute

// Long TTL for stable data
redis.setex('user_profile:123', 86400, profile);  // 24 hours
```

### Event-Based

```typescript
// On user update
async function updateUser(id: string, data: UserData) {
  await db.users.update(id, data);
  await redis.del(`user:${id}`);  // Invalidate
  await redis.del(`user_list`);    // Related caches
}
```

### Tag-Based

```typescript
// Group related cache entries
async function setWithTags(key: string, value: any, tags: string[]) {
  await redis.set(key, JSON.stringify(value));
  for (const tag of tags) {
    await redis.sadd(`tag:${tag}`, key);
  }
}

// Invalidate by tag
async function invalidateTag(tag: string) {
  const keys = await redis.smembers(`tag:${tag}`);
  await redis.del(...keys, `tag:${tag}`);
}
```

## Redis Patterns

### Basic Operations

```typescript
// String
await redis.set('key', 'value');
await redis.get('key');
await redis.setex('key', 3600, 'value');  // With TTL

// Hash
await redis.hset('user:123', 'name', 'John');
await redis.hget('user:123', 'name');
await redis.hgetall('user:123');

// List
await redis.lpush('queue', 'task1');
await redis.rpop('queue');

// Set
await redis.sadd('tags', 'redis', 'cache');
await redis.smembers('tags');

// Sorted Set
await redis.zadd('leaderboard', 100, 'player1');
await redis.zrange('leaderboard', 0, 9);  // Top 10
```

### Pub/Sub for Cache Invalidation

```typescript
// Publisher (on update)
await redis.publish('cache:invalidate', JSON.stringify({
  keys: ['user:123', 'user_list']
}));

// Subscriber (all app instances)
redis.subscribe('cache:invalidate', (message) => {
  const { keys } = JSON.parse(message);
  localCache.delete(...keys);
});
```

## Distributed Caching

### Multi-Tier Caching

```
[Request]
    ↓
[L1: In-Memory] ← Fastest, limited size
    ↓ miss
[L2: Redis] ← Shared, larger capacity
    ↓ miss
[L3: Database] ← Source of truth
```

### Consistency Patterns

| Pattern | Consistency | Performance |
|---------|-------------|-------------|
| Strong (no cache) | Perfect | Slow |
| Eventual (TTL) | Eventual | Fast |
| Write-through | Strong | Medium |

### Cache Stampede Prevention

```typescript
// Mutex/Lock pattern
async function getWithLock(key: string) {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);

  // Try to acquire lock
  const locked = await redis.set(`lock:${key}`, '1', 'NX', 'EX', 30);
  if (!locked) {
    // Wait and retry
    await sleep(100);
    return getWithLock(key);
  }

  try {
    const data = await fetchFromDB();
    await redis.setex(key, 3600, JSON.stringify(data));
    return data;
  } finally {
    await redis.del(`lock:${key}`);
  }
}
```

## Cache Key Design

### Naming Convention

```
{entity}:{id}:{version}
user:123:v1
product:456:v2

{entity}:{qualifier}:{id}
user:profile:123
user:settings:123

{namespace}:{entity}:{id}
app1:user:123
```

### Key Considerations

| Factor | Recommendation |
|--------|----------------|
| Length | Keep short (<100 chars) |
| Separators | Use `:` consistently |
| Versioning | Include for schema changes |
| Case | Use lowercase |

## Metrics & Monitoring

### Key Metrics

| Metric | Target | Action if Off |
|--------|--------|---------------|
| Hit Rate | >80% | Increase TTL, review keys |
| Miss Rate | <20% | Pre-warm cache |
| Latency | <5ms | Check network, size |
| Memory | <80% | Eviction policy, prune |
| Evictions | Low | Increase memory |

### Monitoring Commands

```bash
# Redis stats
redis-cli INFO stats

# Memory usage
redis-cli INFO memory

# Slow log
redis-cli SLOWLOG GET 10
```

## Checklist

- [ ] Cache strategy selected (cache-aside, write-through)
- [ ] TTL defined for all cached data
- [ ] Invalidation strategy implemented
- [ ] Cache stampede prevention in place
- [ ] Key naming convention established
- [ ] Monitoring configured
- [ ] Fallback for cache failure
- [ ] Memory limits set

## When to Load References

- **For Redis patterns**: See `references/redis-patterns.md`
- **For distributed patterns**: See `references/distributed-caching.md`
- **For invalidation strategies**: See `references/invalidation.md`
