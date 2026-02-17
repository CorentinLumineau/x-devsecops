---
name: debugging-performance
description: Systematic debugging methodology and performance optimization with profiling, caching, and database tuning.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Debugging & Performance

Systematic root cause analysis and performance optimization patterns.

## Quick Reference (80/20)

| Area | Key Focus | Impact |
|------|-----------|--------|
| Hypothesis-driven debugging | Form theory before fixing | Prevents random code changes |
| Root cause analysis | Fix cause, not symptoms | Prevents recurring bugs |
| Performance hierarchy | Algorithm > DB > Cache > Micro | Maximizes optimization ROI |
| Profiling first | Measure before optimizing | Prevents premature optimization |
| N+1 detection | JOINs or batch loading | Eliminates most DB bottlenecks |
| Caching strategy | Cache-aside with TTL | Reduces load on data stores |

## Debugging Methodology

### Three-Tier Approach

| Tier | Complexity | Use Case |
|------|------------|----------|
| Quick Fix | Low | Clear errors, obvious causes |
| Debug | Medium | Moderate bugs, code understanding needed |
| Troubleshoot | High | Complex issues, performance, intermittent |

### Hypothesis-Driven Debugging

```
1. OBSERVE: Gather evidence (logs, stack traces, behavior)
2. HYPOTHESIZE: Form theory about root cause
3. TEST: Validate hypothesis with targeted investigation
4. FIX: Apply minimal fix addressing root cause
5. VERIFY: Ensure fix resolves issue without regression
```

### Root Cause Focus

**Always fix the root cause, not symptoms:**

| Root Cause Fix | Band-aid (Avoid) |
|----------------|------------------|
| Fix null check in validation | Add try-catch to hide error |
| Optimize N+1 query | Increase timeout |
| Fix race condition | Add retry loop |
| Fix data corruption source | Add data cleanup job |

### Common Bug Categories

| Category | Investigation Focus |
|----------|---------------------|
| Null/undefined | Call stack, data flow |
| Type errors | Input validation, API contracts |
| State bugs | Mutation points, race conditions |
| Integration | API calls, response handling |
| Performance | Profiling, query analysis |

### Binary Search Debugging

For intermittent issues:
1. Find last known good state
2. Find first bad state
3. Binary search between them
4. Identify change that broke behavior

## Performance Optimization

### Performance Budget

| Metric | Target | Poor |
|--------|--------|------|
| API Response | <200ms | >500ms |
| Page Load (LCP) | <2.5s | >4s |
| Time to Interactive | <3.8s | >7.3s |
| First Contentful Paint | <1.8s | >3s |

### Optimization Hierarchy

Optimize in this order (highest impact first):

```
1. Algorithm complexity (O(n^2) -> O(n log n))
2. Database queries (N+1, missing indexes)
3. Caching (expensive computations, API calls)
4. Code optimization (micro-optimizations)
```

### Database Optimization

| Issue | Solution |
|-------|----------|
| N+1 queries | Use JOINs or batch loading |
| Missing indexes | Add indexes on query columns |
| Large scans | Add WHERE clauses, pagination |
| Slow writes | Batch operations, async |

### Caching Patterns

| Pattern | Use Case | TTL |
|---------|----------|-----|
| Cache-aside | Read-heavy data | Minutes |
| Write-through | Consistent data | N/A |
| Cache invalidation | Dynamic data | On change |

```
Cache Decision:
- Frequently accessed? -> Cache
- Expensive to compute? -> Cache
- Changes rarely? -> Cache (longer TTL)
- User-specific? -> Consider user-keyed cache
```

### Web Performance

| Technique | Benefit |
|-----------|---------|
| Code splitting | Smaller initial bundle |
| Lazy loading | Load on demand |
| Image optimization | Smaller files |
| CDN | Geographic distribution |
| Compression | Smaller transfers |

### Profiling Checklist

- [ ] Identify bottleneck (profile before optimizing)
- [ ] Measure baseline performance
- [ ] Apply single optimization
- [ ] Measure improvement
- [ ] Document change and impact

## Introspection Markers

Expose thinking process during debugging:

| Phase | Description |
|-------|-------------|
| Analyzing | Gathering info, parsing errors |
| Hypothesis | Root cause theory |
| Testing | Reproducing, applying fixes |
| Data | Measurements, impact assessment |
| Insight | Pattern recognition, resolution |

## Debugging Checklist

- [ ] Error message and stack trace captured
- [ ] Hypothesis formed before fixing
- [ ] Root cause identified (not just symptoms)
- [ ] Minimal fix applied
- [ ] Regression test added
- [ ] No new issues introduced
- [ ] Fix documented if significant

## Performance Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| Premature optimization | Profile first |
| Caching everything | Cache selectively |
| Ignoring cold starts | Warm up caches |
| Blocking I/O | Use async operations |
| Large payloads | Pagination, compression |
| Random code changes | Hypothesis-driven debugging |

## When to Load References

- **For debugging strategies**: See `references/strategies.md`
- **For performance profiling**: See `references/debugging-performance-profiling.md`
- **For introspection markers**: See `references/markers.md`
- **For caching patterns**: See `references/caching-patterns.md`
- **For database optimization**: See `references/database-optimization.md`
- **For web performance**: See `references/web-performance.md`

## Related Skills

- **Testing**: See `quality/testing` for test-driven bug prevention
- **Observability**: See `quality/observability` for production debugging with logs/traces
- **Database**: See `data/database` for advanced query optimization
- **Data Persistence**: See `data/data-persistence` for caching strategies and database design patterns
