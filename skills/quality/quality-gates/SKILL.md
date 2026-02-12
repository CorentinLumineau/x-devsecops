---
name: quality-gates
description: Quality gate checks for code validation. Types, lint, build, tests, coverage.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Quality Gates

Automated validation checks ensuring code quality standards.

## Gate Categories

| Category | Checks | Blocking |
|----------|--------|----------|
| Standard | Types, lint, build | Yes |
| Extended | Tests, coverage, SOLID | Yes |
| Documentation | Doc sync, changelog | Warning |

## Standard Gates (Always Run)

| Gate | Command Example | Fail Condition |
|------|-----------------|----------------|
| Type check | `tsc --noEmit` | Type errors |
| Lint | `eslint .` | Lint violations |
| Build | `npm run build` | Build failure |

## Extended Gates (Implementation)

| Gate | Command Example | Fail Condition |
|------|-----------------|----------------|
| Unit tests | `npm test` | Test failures |
| Coverage | `npm run coverage` | Below threshold (80%) |
| SOLID audit | Manual review | Violations detected |

## Execution Order

```
1. Type check (fast fail)
2. Lint (fast fail)
3. Build (validates compilation)
4. Tests (validates functionality)
5. Coverage (validates completeness)
```

## Gate Configuration

### TypeScript
```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "noUnusedLocals": true
  }
}
```

### ESLint
```json
{
  "extends": ["eslint:recommended"],
  "rules": {
    "no-unused-vars": "error",
    "no-console": "warn"
  }
}
```

## Coverage Thresholds

| Level | Lines | Branches | Functions |
|-------|-------|----------|-----------|
| Minimum | 70% | 60% | 70% |
| Target | 80% | 70% | 80% |
| Strict | 90% | 85% | 90% |

## Pre-Commit Gates

Run before every commit:
- [ ] Format check (prettier)
- [ ] Lint check
- [ ] Type check
- [ ] Affected tests

## CI/CD Gates

Run on every PR:
- [ ] All standard gates
- [ ] Full test suite
- [ ] Coverage threshold
- [ ] Security scan
- [ ] Build artifact creation

## Gate Checklist

- [ ] Type check passes
- [ ] No lint errors
- [ ] Build succeeds
- [ ] All tests pass
- [ ] Coverage above threshold
- [ ] No security vulnerabilities

## When to Load References

- **For CI configuration**: See `references/ci-config.md`
- **For coverage setup**: See `references/coverage-setup.md`
- **For pre-commit hooks**: See `references/pre-commit.md`
