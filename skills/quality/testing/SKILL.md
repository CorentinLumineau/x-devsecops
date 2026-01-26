---
name: testing
description: |
  Testing pyramid and TDD patterns. 70% unit, 20% integration, 10% E2E distribution.
  Activate when writing tests, fixing test failures, verifying code changes, or reviewing coverage.
  Triggers: test, tdd, unit test, integration test, e2e, coverage, jest, vitest.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Testing

Comprehensive test strategy following the testing pyramid.

## Testing Pyramid (70/20/10)

| Type | Percentage | Focus | Speed |
|------|------------|-------|-------|
| Unit | 70% | Business logic, pure functions | Fast |
| Integration | 20% | Service interactions, APIs | Medium |
| E2E | 10% | Critical user flows | Slow |

## Unit Tests (70%)

**What to test**:
- Pure functions
- Business logic
- Data transformations
- Edge cases
- Error handling

**Characteristics**:
- Fast (<10ms each)
- Isolated (no external dependencies)
- Deterministic (same input = same output)

## Integration Tests (20%)

**What to test**:
- API endpoints
- Database operations
- Service interactions
- External integrations (mocked)

**Characteristics**:
- Test real component interactions
- Use test databases
- Mock external services

## E2E Tests (10%)

**What to test**:
- Critical user journeys
- Happy paths
- Payment flows
- Authentication

**Characteristics**:
- Slow but high confidence
- Cover complete flows
- Real browser/environment

## TDD Cycle (Red-Green-Refactor)

```
1. RED: Write failing test
2. GREEN: Write minimal code to pass
3. REFACTOR: Improve code, keep tests green
4. REPEAT
```

## Iterative Fix Loop

When tests fail:
1. Run test suite
2. Classify errors by type/root cause
3. Fix error group (start with root cause)
4. Re-run tests
5. Repeat until 100% passing

## Test Quality Checklist

- [ ] Tests follow 70/20/10 distribution
- [ ] Each test has single assertion focus
- [ ] Tests are independent (no shared state)
- [ ] Test names describe behavior
- [ ] No test.skip() in codebase
- [ ] Regression tests for fixed bugs
- [ ] Coverage targets met (80%+)

## Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| Testing implementation | Test behavior |
| Skipping tests | Fix or remove |
| Shared test state | Isolate tests |
| Testing trivial code | Focus on logic |
| No assertions | Add meaningful checks |

## When to Load References

- **For TDD patterns**: See `references/tdd-patterns.md`
- **For coverage strategies**: See `references/coverage.md`
- **For mocking patterns**: See `references/mocking.md`
