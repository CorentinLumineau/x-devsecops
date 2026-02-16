# Skill Migration Map (v1 → v2)

This document maps old skill names (v1, 39 skills) to new consolidated skill names (v2, 17 skills) for ccsetup sync compatibility.

## Migration Table

| v1 Skill | v1 Category | v2 Skill | v2 Category | Action |
|----------|-------------|----------|-------------|--------|
| `owasp` | security | `secure-coding` | security | Merged |
| `input-validation` | security | `secure-coding` | security | Merged |
| `api-security` | security | `secure-coding` | security | Merged |
| `authentication` | security | `identity-access` | security | Merged |
| `authorization` | security | `identity-access` | security | Merged |
| `compliance` | security | `identity-access` | security | Merged |
| `secrets` | security | `secrets-supply-chain` | security | Merged |
| `supply-chain` | security | `secrets-supply-chain` | security | Merged |
| `container-security` | security | `secrets-supply-chain` | security | Merged |
| `code-quality` | code | `code-quality` | code | Enhanced (absorbed refactoring-patterns) |
| `refactoring-patterns` | code | `code-quality` | code | Absorbed |
| `api-design` | code | `api-design` | code | Enhanced (absorbed sdk-design) |
| `sdk-design` | code | `api-design` | code | Absorbed |
| `design-patterns` | code | `design-patterns` | code | Unchanged |
| `error-handling` | code | `error-handling` | code | Unchanged |
| `llm-optimization` | code | *(removed)* | — | Deleted (LLMs know this natively) |
| `testing` | quality | `testing` | quality | Enhanced (absorbed quality-gates) |
| `quality-gates` | quality | `testing` | quality | Absorbed |
| `debugging` | quality | `debugging-performance` | quality | Merged |
| `performance` | quality | `debugging-performance` | quality | Merged |
| `observability` | quality | `observability` | quality | Enhanced (absorbed load-testing) |
| `load-testing` | quality | `observability` | quality | Absorbed |
| `accessibility-wcag` | quality | *(removed)* | — | Deleted (not DevSecOps core) |
| `ci-cd` | delivery | `ci-cd-delivery` | delivery | Merged |
| `deployment-strategies` | delivery | `ci-cd-delivery` | delivery | Merged |
| `release-management` | delivery | `release-git` | delivery | Merged + NEW git content |
| `infrastructure` | delivery | `infrastructure` | delivery | Enhanced (absorbed feature-flags) |
| `feature-flags` | delivery | `infrastructure` | delivery | Absorbed |
| `incident-response` | operations | `sre-operations` | operations | Merged |
| `monitoring` | operations | `sre-operations` | operations | Merged |
| `sre-practices` | operations | `sre-operations` | operations | Merged |
| `disaster-recovery` | operations | `sre-operations` | operations | Merged |
| `analysis` | meta | `analysis-architecture` | meta | Merged |
| `decision-making` | meta | `analysis-architecture` | meta | Merged |
| `architecture-patterns` | meta | `analysis-architecture` | meta | Merged |
| `database` | data | `data-persistence` | data | Merged |
| `nosql` | data | `data-persistence` | data | Merged |
| `caching` | data | `data-persistence` | data | Merged |
| `message-queues` | data | `messaging` | data | Renamed |

## Summary

| Metric | v1 | v2 |
|--------|----|----|
| Total skills | 39 | 17 |
| Reference files | 105 | 101 |
| Categories | 7 | 7 |
| Deleted skills | — | 2 (llm-optimization, accessibility-wcag) |
| New content | — | git-workflows.md, commit-conventions.md |

## ccsetup Sync Notes

When updating ccsetup to sync v2 skills:

1. Update skill name mappings in sync script
2. Remove references to deleted skills (llm-optimization, accessibility-wcag)
3. Update workflow skills that reference old names:
   - `x-verify`: `quality-gates` → `testing`
   - `x-review`: `owasp` → `secure-coding`
   - `x-troubleshoot`: `debugging` → `debugging-performance`, `incident-response` → `sre-operations`
4. Update agent configurations that reference old skill names
