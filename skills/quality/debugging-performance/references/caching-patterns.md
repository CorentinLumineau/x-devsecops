# Caching Patterns Reference

Application and HTTP caching strategies for performance optimization.

## Application Caching

### Cache-Aside (Lazy Loading)

Most common pattern — application manages cache explicitly:

```typescript
async function getUser(id: string): Promise<User> {
  const cacheKey = `user:${id}`;

  // 1. Check cache
  const cached = await cache.get(cacheKey);
  if (cached) return JSON.parse(cached);

  // 2. Cache miss — load from DB
  const user = await db.users.findById(id);

  // 3. Populate cache
  await cache.set(cacheKey, JSON.stringify(user), 'EX', 3600);

  return user;
}
```

### Write-Through

Write to cache and DB together — ensures consistency:

```typescript
async function updateUser(id: string, data: Partial<User>): Promise<User> {
  // Write to DB
  const user = await db.users.update(id, data);

  // Write to cache immediately
  await cache.set(`user:${id}`, JSON.stringify(user), 'EX', 3600);

  return user;
}
```

### Write-Behind (Write-Back)

Write to cache first, async flush to DB — higher throughput, risk of data loss:

```typescript
async function incrementPageViews(pageId: string): Promise<void> {
  // Write to cache (fast)
  await cache.incr(`views:${pageId}`);

  // Periodic flush to DB (background job)
  // runs every 60 seconds
}

async function flushViewCounts(): Promise<void> {
  const keys = await cache.keys('views:*');
  for (const key of keys) {
    const count = await cache.getdel(key);
    if (count) {
      const pageId = key.replace('views:', '');
      await db.query(
        'UPDATE pages SET views = views + $1 WHERE id = $2',
        [parseInt(count), pageId]
      );
    }
  }
}
```

## Cache Invalidation Strategies

### Time-Based (TTL)

```typescript
// Short TTL for frequently changing data
await cache.set('dashboard:stats', data, 'EX', 60);     // 1 min

// Longer TTL for stable data
await cache.set('config:features', data, 'EX', 3600);   // 1 hour

// Stale-while-revalidate pattern
async function getWithSWR(key: string, fetchFn: () => Promise<any>) {
  const cached = await cache.get(key);
  const ttl = await cache.ttl(key);

  if (cached && ttl > 30) return JSON.parse(cached);

  // Revalidate in background if stale
  if (cached) {
    fetchFn().then(data =>
      cache.set(key, JSON.stringify(data), 'EX', 300)
    );
    return JSON.parse(cached);
  }

  const data = await fetchFn();
  await cache.set(key, JSON.stringify(data), 'EX', 300);
  return data;
}
```

### Event-Based

```typescript
// Invalidate on mutation
async function updateProduct(id: string, data: Partial<Product>) {
  await db.products.update(id, data);

  // Invalidate specific entry
  await cache.del(`product:${id}`);

  // Invalidate related collections
  await cache.del(`products:category:${data.categoryId}`);
  await cache.del('products:featured');
}
```

### Tag-Based

```typescript
// Tag cache entries for bulk invalidation
async function cacheWithTags(
  key: string, value: any, tags: string[], ttl: number
) {
  await cache.set(key, JSON.stringify(value), 'EX', ttl);
  for (const tag of tags) {
    await cache.sadd(`tag:${tag}`, key);
  }
}

async function invalidateTag(tag: string) {
  const keys = await cache.smembers(`tag:${tag}`);
  if (keys.length > 0) {
    await cache.del(...keys);
  }
  await cache.del(`tag:${tag}`);
}
```

## HTTP Caching

### Cache-Control Headers

```typescript
// Static assets — long cache with content hash
app.use('/static', (req, res, next) => {
  res.set('Cache-Control', 'public, max-age=31536000, immutable');
  next();
});

// API responses — short cache, revalidation
app.get('/api/products', (req, res) => {
  res.set('Cache-Control', 'public, max-age=60, stale-while-revalidate=300');
  res.json(products);
});

// Private data — no shared caches
app.get('/api/profile', (req, res) => {
  res.set('Cache-Control', 'private, max-age=0, must-revalidate');
  res.json(profile);
});
```

### ETag Validation

```typescript
app.get('/api/data', (req, res) => {
  const data = getData();
  const etag = crypto.createHash('md5').update(JSON.stringify(data)).digest('hex');

  if (req.headers['if-none-match'] === etag) {
    return res.status(304).end();
  }

  res.set('ETag', etag);
  res.json(data);
});
```

## CDN Strategies

| Content Type | Cache Duration | Invalidation |
|-------------|---------------|--------------|
| Static assets (hashed) | 1 year | Deploy new hash |
| HTML pages | 5 min | Purge API |
| API responses | 1-60 sec | TTL expiry |
| User-specific | No CDN cache | `Cache-Control: private` |

### CDN Cache Keys

```
# Vary header for content negotiation
Vary: Accept-Encoding, Accept-Language

# Custom cache keys for A/B testing
Vary: X-Experiment-Group
```

## Cache Sizing

| Data Type | Recommended TTL | Eviction |
|-----------|----------------|----------|
| Session data | 24h | TTL |
| API responses | 1-5 min | TTL |
| User profiles | 1h | Event + TTL |
| Config/features | 5-15 min | Event + TTL |
| Computed aggregates | 5-60 min | TTL |

## Common Pitfalls

- **Cache stampede**: Many requests hit DB simultaneously on cache miss; use locking or probabilistic early expiry
- **Stale data served indefinitely**: Always set TTL as safety net even with event invalidation
- **Caching errors**: Never cache error responses; check before storing
- **Over-caching**: Not all data benefits from caching; profile first
- **Serialization overhead**: Large objects may be slower to serialize than to recompute
- **Missing cache warming**: Cold start after deploy causes thundering herd; pre-warm critical keys
