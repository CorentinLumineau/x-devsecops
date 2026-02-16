# Database Optimization Reference

Techniques for optimizing database performance with focus on the 80/20 patterns that resolve most issues.

## Query Optimization

### EXPLAIN ANALYZE

Always analyze before optimizing:

```sql
-- PostgreSQL
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.name, COUNT(o.id)
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at > '2024-01-01'
GROUP BY u.name;
```

Key metrics to watch:
- **Seq Scan** on large tables = missing index
- **Nested Loop** with high row counts = consider Hash Join
- **Rows estimated vs actual** = stale statistics, run `ANALYZE`
- **Buffers shared read** = data not in cache

### Indexing Strategies

```sql
-- B-tree: Default, equality and range queries
CREATE INDEX idx_users_email ON users (email);

-- Composite: Column order matters (most selective first)
CREATE INDEX idx_orders_user_status ON orders (user_id, status);

-- Partial: Index only relevant rows
CREATE INDEX idx_orders_pending ON orders (created_at)
WHERE status = 'pending';

-- Covering: Include columns to avoid table lookups
CREATE INDEX idx_orders_cover ON orders (user_id)
INCLUDE (total, status);

-- Expression: Index computed values
CREATE INDEX idx_users_lower_email ON users (LOWER(email));
```

### Index Selection Rules

| Query Pattern | Index Type |
|---------------|-----------|
| `WHERE col = value` | B-tree (single column) |
| `WHERE col1 = x AND col2 = y` | Composite B-tree |
| `WHERE col LIKE 'prefix%'` | B-tree |
| `WHERE col @> '{"key": "val"}'` | GIN (JSONB) |
| `WHERE to_tsvector(col) @@ query` | GIN (full-text) |
| Geospatial queries | GiST |

## N+1 Query Detection and Resolution

### The Problem

```typescript
// BAD: N+1 — 1 query for users + N queries for orders
const users = await db.query('SELECT * FROM users LIMIT 100');
for (const user of users) {
  user.orders = await db.query(
    'SELECT * FROM orders WHERE user_id = $1', [user.id]
  );
}
```

### Solutions

```typescript
// GOOD: JOIN
const results = await db.query(`
  SELECT u.*, o.id as order_id, o.total
  FROM users u
  LEFT JOIN orders o ON o.user_id = u.id
  LIMIT 100
`);

// GOOD: Batch loading (DataLoader pattern)
const userIds = users.map(u => u.id);
const orders = await db.query(
  'SELECT * FROM orders WHERE user_id = ANY($1)',
  [userIds]
);
const ordersByUser = groupBy(orders, 'user_id');

// GOOD: ORM eager loading
const users = await User.findAll({
  include: [{ model: Order }],
  limit: 100,
});
```

## Query Plan Analysis Checklist

1. **Sequential scans** on tables > 10K rows — add index
2. **High cost estimates** — simplify query or add indexes
3. **Sort operations** — add index matching ORDER BY
4. **Hash aggregates** with high memory — consider work_mem tuning
5. **Nested loops** on large sets — may need index or rewrite

## Pagination Optimization

```sql
-- BAD: OFFSET for deep pages (scans all skipped rows)
SELECT * FROM orders ORDER BY id LIMIT 20 OFFSET 10000;

-- GOOD: Keyset pagination (cursor-based)
SELECT * FROM orders
WHERE id > :last_seen_id
ORDER BY id
LIMIT 20;
```

## Connection Pooling

```typescript
// Use connection pooling (pgBouncer or application-level)
const pool = new Pool({
  max: 20,              // Max connections
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Always release connections
const client = await pool.connect();
try {
  await client.query('SELECT ...');
} finally {
  client.release();
}
```

## Common Pitfalls

- **Over-indexing**: Each index slows writes; audit unused indexes with `pg_stat_user_indexes`
- **Missing ANALYZE**: Optimizer relies on statistics; schedule regular `ANALYZE`
- **SELECT ***: Fetch only needed columns to reduce I/O
- **Implicit casts**: `WHERE varchar_col = 123` prevents index use
- **Large transactions**: Hold locks briefly; batch large updates
- **No connection pooling**: Exhausted connections under load
