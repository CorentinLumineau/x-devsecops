---
name: debugging
description: Systematic debugging strategies with hypothesis-driven root cause analysis.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Debugging

Systematic root cause analysis with hypothesis-driven investigation.

## Three-Tier Approach

| Tier | Complexity | Use Case |
|------|------------|----------|
| Quick Fix | Low | Clear errors, obvious causes |
| Debug | Medium | Moderate bugs, code understanding needed |
| Troubleshoot | High | Complex issues, performance, intermittent |

## Hypothesis-Driven Debugging

```
1. OBSERVE: Gather evidence (logs, stack traces, behavior)
2. HYPOTHESIZE: Form theory about root cause
3. TEST: Validate hypothesis with targeted investigation
4. FIX: Apply minimal fix addressing root cause
5. VERIFY: Ensure fix resolves issue without regression
```

## Root Cause Focus

**Always fix the root cause, not symptoms:**

| Root Cause Fix | Band-aid (Avoid) |
|----------------|------------------|
| Fix null check in validation | Add try-catch to hide error |
| Optimize N+1 query | Increase timeout |
| Fix race condition | Add retry loop |
| Fix data corruption source | Add data cleanup job |

## Introspection Markers

Expose thinking process:

| Phase | Description |
|-------|-------------|
| Analyzing | Gathering info, parsing errors |
| Hypothesis | Root cause theory |
| Testing | Reproducing, applying fixes |
| Data | Measurements, impact assessment |
| Insight | Pattern recognition, resolution |

## Common Bug Categories

| Category | Investigation Focus |
|----------|---------------------|
| Null/undefined | Call stack, data flow |
| Type errors | Input validation, API contracts |
| State bugs | Mutation points, race conditions |
| Integration | API calls, response handling |
| Performance | Profiling, query analysis |

## Debugging Checklist

- [ ] Error message and stack trace captured
- [ ] Hypothesis formed before fixing
- [ ] Root cause identified (not just symptoms)
- [ ] Minimal fix applied
- [ ] Regression test added
- [ ] No new issues introduced
- [ ] Fix documented if significant

## Binary Search Debugging

For intermittent issues:
1. Find last known good state
2. Find first bad state
3. Binary search between them
4. Identify change that broke behavior

## When to Load References

- **For debugging strategies**: See `references/strategies.md`
- **For performance debugging**: See `references/performance.md`
- **For memory issues**: See `references/memory.md`
