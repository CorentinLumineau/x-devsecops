# Caching Patterns

Detailed caching strategy implementations including cache-aside, invalidation, stampede prevention, and multi-tier caching.

## Strategy Selection

| Pattern | When to Use | Complexity |
|---------|-------------|------------|
| Cache-Aside | Default choice for most scenarios | Low |
| Read-Through | Simple read-heavy workloads | Low |
| Write-Through | Cache must always be consistent | Medium |
| Write-Behind | High write throughput needed | High |

## Cache-Aside (Default)

```typescript
async function getUser(id: string): Promise<User> {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  const user = await db.users.findById(id);
  await redis.setex(`user:${id}`, 3600, JSON.stringify(user));
  return user;
}
```

## Cache Invalidation Strategies

| Strategy | Use Case | Trade-off |
|----------|----------|-----------|
| TTL-based | Time-sensitive data | Simple but stale window |
| Event-based | Write-heavy, consistency needed | Complex but fresh |
| Tag-based | Related cache groups | Flexible but overhead |

```typescript
// Event-based invalidation
async function updateUser(id: string, data: UserData) {
  await db.users.update(id, data);
  await redis.del(`user:${id}`);    // Invalidate specific
  await redis.del(`user_list`);      // Invalidate related
}
```

## Cache Stampede Prevention

```typescript
// Mutex/Lock pattern
async function getWithLock(key: string) {
  const cached = await redis.get(key);
  if (cached) return JSON.parse(cached);

  const locked = await redis.set(`lock:${key}`, '1', 'NX', 'EX', 30);
  if (!locked) {
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

```
{entity}:{id}            -- user:123
{entity}:{qualifier}:{id} -- user:profile:123
{namespace}:{entity}:{id} -- app1:user:123
```

| Factor | Recommendation |
|--------|----------------|
| Length | Keep short (<100 chars) |
| Separators | Use `:` consistently |
| Versioning | Include for schema changes |
| Case | Use lowercase |

## Multi-Tier Caching

```
[Request]
    |
[L1: In-Memory] -- Fastest, limited size
    | miss
[L2: Redis]     -- Shared, larger capacity
    | miss
[L3: Database]  -- Source of truth
```

## Key Metrics

| Metric | Target | Action if Off |
|--------|--------|---------------|
| Hit Rate | >80% | Increase TTL, review keys |
| Miss Rate | <20% | Pre-warm cache |
| Latency | <5ms | Check network, payload size |
| Memory | <80% | Review eviction policy |
