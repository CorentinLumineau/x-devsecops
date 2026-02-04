---
name: database
description: Database design and optimization. Schema design, migrations, query optimization.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: data
---

# Database

Database design and optimization patterns.

## Schema Design Principles

| Principle | Description |
|-----------|-------------|
| Normalization | Reduce redundancy (3NF baseline) |
| Appropriate types | Use correct data types |
| Constraints | Enforce data integrity |
| Indexes | Optimize common queries |

## Common Patterns

### One-to-Many
```sql
CREATE TABLE users (id SERIAL PRIMARY KEY);
CREATE TABLE posts (
  id SERIAL PRIMARY KEY,
  user_id INT REFERENCES users(id)
);
```

### Many-to-Many
```sql
CREATE TABLE user_roles (
  user_id INT REFERENCES users(id),
  role_id INT REFERENCES roles(id),
  PRIMARY KEY (user_id, role_id)
);
```

## Index Strategy

| Query Pattern | Index Type |
|---------------|------------|
| Equality (=) | B-tree (default) |
| Range (<, >) | B-tree |
| Full text | GIN or GiST |
| JSON fields | GIN |

### When to Index
```
✅ Foreign keys
✅ Frequently filtered columns
✅ ORDER BY columns
❌ Low cardinality columns (booleans)
❌ Rarely queried columns
```

## Migration Best Practices

| Practice | Why |
|----------|-----|
| Small migrations | Easy to review, rollback |
| Forward-only | Avoid data loss |
| Test in staging | Catch issues early |
| Backup before | Safety net |

### Migration Template
```sql
-- Migration: add_email_verified
-- Date: 2026-01-23

-- Up
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT false;

-- Down (document but avoid using)
-- ALTER TABLE users DROP COLUMN email_verified;
```

## Query Optimization

| Issue | Solution |
|-------|----------|
| N+1 queries | Use JOINs or batch loading |
| Missing index | Add index on filtered columns |
| Large scans | Add WHERE, use pagination |
| SELECT * | Select only needed columns |

### EXPLAIN ANALYZE
```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'test@example.com';
```

Look for:
- Seq Scan (may need index)
- High cost/rows
- Nested loops (may need JOIN optimization)

## Connection Management

| Practice | Implementation |
|----------|----------------|
| Connection pooling | PgBouncer, built-in pools |
| Timeouts | Statement and connection |
| Max connections | Based on workload |

## Checklist

- [ ] Schema normalized appropriately
- [ ] Foreign keys with constraints
- [ ] Indexes on filtered/joined columns
- [ ] Migrations tested in staging
- [ ] Queries use EXPLAIN ANALYZE
- [ ] Connection pooling configured
- [ ] Backups verified

## When to Load References

- **For PostgreSQL specifics**: See `references/postgresql.md`
- **For migration tools**: See `references/migrations.md`
- **For performance tuning**: See `references/tuning.md`
