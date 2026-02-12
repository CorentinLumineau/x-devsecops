---
name: performance
description: Performance optimization patterns. Profiling, caching, database optimization.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Performance

Optimization patterns and profiling strategies.

## Performance Budget

| Metric | Target | Poor |
|--------|--------|------|
| API Response | <200ms | >500ms |
| Page Load (LCP) | <2.5s | >4s |
| Time to Interactive | <3.8s | >7.3s |
| First Contentful Paint | <1.8s | >3s |

## Optimization Hierarchy

Optimize in this order (highest impact first):

```
1. Algorithm complexity (O(n²) → O(n log n))
2. Database queries (N+1, missing indexes)
3. Caching (expensive computations, API calls)
4. Code optimization (micro-optimizations)
```

## Database Optimization

| Issue | Solution |
|-------|----------|
| N+1 queries | Use JOINs or batch loading |
| Missing indexes | Add indexes on query columns |
| Large scans | Add WHERE clauses, pagination |
| Slow writes | Batch operations, async |

### Index Strategy
```sql
-- Add index for frequently queried columns
CREATE INDEX idx_users_email ON users(email);

-- Composite index for multi-column queries
CREATE INDEX idx_posts_user_created ON posts(user_id, created_at);
```

## Caching Patterns

| Pattern | Use Case | TTL |
|---------|----------|-----|
| Cache-aside | Read-heavy data | Minutes |
| Write-through | Consistent data | N/A |
| Cache invalidation | Dynamic data | On change |

```
Cache Decision:
- Frequently accessed? → Cache
- Expensive to compute? → Cache
- Changes rarely? → Cache (longer TTL)
- User-specific? → Consider user-keyed cache
```

## Profiling Checklist

- [ ] Identify bottleneck (profile before optimizing)
- [ ] Measure baseline performance
- [ ] Apply single optimization
- [ ] Measure improvement
- [ ] Document change and impact

## Common Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| Premature optimization | Profile first |
| Caching everything | Cache selectively |
| Ignoring cold starts | Warm up caches |
| Blocking I/O | Use async operations |
| Large payloads | Pagination, compression |

## Web Performance

| Technique | Benefit |
|-----------|---------|
| Code splitting | Smaller initial bundle |
| Lazy loading | Load on demand |
| Image optimization | Smaller files |
| CDN | Geographic distribution |
| Compression | Smaller transfers |

## When to Load References

- **For database tuning**: See `references/database-optimization.md`
- **For caching setup**: See `references/caching-patterns.md`
- **For frontend perf**: See `references/web-performance.md`
