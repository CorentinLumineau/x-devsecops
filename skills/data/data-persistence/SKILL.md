---
name: data-persistence
description: Database design, NoSQL patterns, caching strategies, and data storage optimization.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: data
---

# Data Persistence

Unified data storage patterns covering relational databases, NoSQL, and caching strategies.

## 80/20 Focus

Master these (covers 80% of data persistence decisions):

| Area | Key Practice | Impact |
|------|-------------|--------|
| SQL vs NoSQL | Choose based on access patterns and consistency needs | Foundational architecture decision |
| Schema design | Normalize for SQL, denormalize for NoSQL | Query performance and data integrity |
| Indexing | Index filtered/joined columns, use EXPLAIN | 10-100x query speedup |
| Caching | Cache-aside with TTL as default strategy | Reduces DB load by 80%+ |
| Connection pooling | Use pgBouncer or built-in pools | 10x connection efficiency |

## SQL vs NoSQL Decision Framework

```
Need complex JOINs?           --> SQL
Need ACID transactions?       --> SQL
Need ad-hoc queries?          --> SQL
Need horizontal scaling?      --> NoSQL
Schema changes frequently?    --> NoSQL
Read pattern is key-based?    --> NoSQL
Need high write throughput?   --> NoSQL
```

| Criteria | Choose SQL | Choose NoSQL |
|----------|-----------|--------------|
| Data model | Relational, normalized | Document, key-value, wide-column |
| Consistency | Strong (ACID) | Eventual (BASE), tunable |
| Scaling | Vertical (read replicas) | Horizontal (sharding) |
| Schema | Fixed, enforced | Flexible, schema-on-read |
| Query | Complex JOINs, aggregations | Key-based lookups, document queries |
| Examples | PostgreSQL, MySQL | MongoDB, DynamoDB, Redis |

## Relational Database Patterns

### Schema Design Principles

| Principle | Description |
|-----------|-------------|
| Normalization | Reduce redundancy (3NF baseline) |
| Appropriate types | Use correct data types for columns |
| Constraints | Enforce data integrity with FKs and checks |
| Indexes | Optimize common query patterns |

### Common Relationships

```sql
-- One-to-Many
CREATE TABLE users (id SERIAL PRIMARY KEY);
CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id)
);

-- Many-to-Many
CREATE TABLE user_roles (
  user_id INT REFERENCES users(id),
  role_id INT REFERENCES roles(id),
  PRIMARY KEY (user_id, role_id)
);
```

### Index Strategy

| Query Pattern | Index Type |
|---------------|------------|
| Equality (=) | B-tree (default) |
| Range (<, >) | B-tree |
| Full text search | GIN or GiST |
| JSON fields | GIN |
| Time-series | BRIN |

```
When to index:
- Foreign keys
- Frequently filtered columns
- ORDER BY columns
- JOIN columns

When NOT to index:
- Low cardinality columns (booleans)
- Rarely queried columns
- Small tables
```

### Migration Best Practices

| Practice | Why |
|----------|-----|
| Small migrations | Easy to review and rollback |
| Forward-only | Avoid data loss |
| Test in staging | Catch issues early |
| Backup before deploy | Safety net |
| Use CONCURRENTLY for indexes | Avoid table locks |

### Query Optimization

| Issue | Solution |
|-------|----------|
| N+1 queries | Use JOINs or batch loading |
| Missing index | Add index on filtered columns |
| Large scans | Add WHERE clauses, use pagination |
| SELECT * | Select only needed columns |
| Deep OFFSET | Use keyset (cursor) pagination |

```sql
-- Always analyze before optimizing
EXPLAIN (ANALYZE, BUFFERS) SELECT ...
```

### Connection Management

| Practice | Implementation |
|----------|----------------|
| Connection pooling | pgBouncer, built-in pools |
| Timeouts | Statement and connection timeouts |
| Max connections | Based on workload + pooler |
| Pool mode | Transaction mode for web apps |

## NoSQL Database Patterns

### MongoDB Document Modeling

| Factor | Embed | Reference |
|--------|-------|-----------|
| Size | <16MB doc limit | No limit |
| Access | Always together | Independent access |
| Updates | Infrequent | Frequent updates |
| Cardinality | 1:1, 1:few | 1:many, many:many |

```javascript
// Embedded (1:1, 1:few)
{
  _id: ObjectId("..."),
  name: "John",
  address: { street: "123 Main St", city: "Boston" }
}

// Referenced (1:many, many:many)
{ _id: ObjectId("user1"), name: "John" }
{ _id: ObjectId("order1"), user_id: ObjectId("user1"), total: 99.99 }
```

### DynamoDB Single Table Design

| Pattern | Use Case |
|---------|----------|
| `TYPE#ID` | Entity lookup |
| `PARENT#CHILD` | Hierarchical data |
| `DATE#ID` | Time-based queries |
| `begins_with` | Range queries on sort key |

```javascript
// Access patterns drive table design
// Get user: PK="USER#123", SK="PROFILE"
// Get user orders: PK="USER#123", SK begins_with "ORDER#"
```

### Schema Versioning

```javascript
{
  _id: ObjectId("..."),
  schemaVersion: 2,
  name: "John",
  preferences: { theme: "dark" }  // Added in v2
}

// Migrate on read
if (doc.schemaVersion < 2) {
  doc.preferences = defaults;
  doc.schemaVersion = 2;
}
```

## Caching Patterns

### Strategy Selection

| Pattern | When to Use | Complexity |
|---------|-------------|------------|
| Cache-Aside | Default choice for most scenarios | Low |
| Read-Through | Simple read-heavy workloads | Low |
| Write-Through | Cache must always be consistent | Medium |
| Write-Behind | High write throughput needed | High |

### Cache-Aside (Default)

```typescript
async function getUser(id: string): Promise<User> {
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  const user = await db.users.findById(id);
  await redis.setex(`user:${id}`, 3600, JSON.stringify(user));
  return user;
}
```

### Cache Invalidation Strategies

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

### Cache Stampede Prevention

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

### Cache Key Design

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

### Multi-Tier Caching

```
[Request]
    |
[L1: In-Memory] -- Fastest, limited size
    | miss
[L2: Redis]     -- Shared, larger capacity
    | miss
[L3: Database]  -- Source of truth
```

### Key Metrics

| Metric | Target | Action if Off |
|--------|--------|---------------|
| Hit Rate | >80% | Increase TTL, review keys |
| Miss Rate | <20% | Pre-warm cache |
| Latency | <5ms | Check network, payload size |
| Memory | <80% | Review eviction policy |

## Quick Reference

| Task | Approach |
|------|----------|
| New project DB choice | Use SQL vs NoSQL decision framework |
| Slow queries | EXPLAIN ANALYZE, add indexes |
| High DB load | Add caching layer (cache-aside + TTL) |
| Schema evolution (SQL) | Small forward-only migrations |
| Schema evolution (NoSQL) | Schema versioning field |
| Connection issues | Connection pooling (pgBouncer) |
| Data consistency | SQL for ACID, event-based invalidation for cache |
| Horizontal scaling | NoSQL (MongoDB sharding, DynamoDB) |

## Checklist

### Database Design
- [ ] SQL vs NoSQL decision documented
- [ ] Schema normalized appropriately (SQL) or access-pattern-driven (NoSQL)
- [ ] Indexes on filtered/joined columns
- [ ] Foreign keys with constraints (SQL)

### Performance
- [ ] Connection pooling configured
- [ ] Queries analyzed with EXPLAIN
- [ ] Caching strategy selected and implemented
- [ ] TTL defined for all cached data
- [ ] Cache stampede prevention in place

### Operations
- [ ] Migrations tested in staging
- [ ] Backups verified and scheduled
- [ ] Monitoring configured (query stats, cache hit ratio)
- [ ] Fallback for cache failure defined

## When to Load References

- **For PostgreSQL specifics**: See `references/postgresql.md`
- **For migration patterns**: See `references/migrations.md`
- **For performance tuning**: See `references/tuning.md`
- **For MongoDB patterns**: See `references/mongodb-patterns.md`
- **For Redis patterns**: See `references/redis-patterns.md`

## Related Skills

- `data/messaging` - Event-driven patterns and message brokers
- `code/api-design` - API design patterns for data access
- `quality/performance` - Performance testing and optimization
- `operations/observability` - Database monitoring and alerting
