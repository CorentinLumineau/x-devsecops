---
name: testing
description: Use when writing tests, improving coverage, or setting up quality gates. Covers testing pyramid, TDD patterns, and quality gate checks for comprehensive validation.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Testing

Comprehensive test strategy following the testing pyramid, with integrated quality gate validation.

## Enforcement Definitions

Violation IDs used by workflow skills (x-implement, x-verify, x-review, git-commit) to enforce testing standards.

**Severity Model**: CRITICAL/HIGH = BLOCK (must fix), MEDIUM = WARN (flag to user), LOW = INFO (note).

### Testing Violations

| ID | Violation | Severity | Detection |
|----|-----------|----------|-----------|
| V-TEST-01 | No tests for new production code | CRITICAL | New functions/classes/modules without corresponding test files |
| V-TEST-02 | Tests written after production code (TDD violation) | HIGH | Production code committed before test code in same changeset |
| V-TEST-03 | Coverage below 80% on changed files | HIGH | Line coverage on modified/new files under threshold |
| V-TEST-04 | Pyramid imbalance (unit tests <60% of new tests) | MEDIUM | Disproportionate integration/E2E tests vs unit tests |
| V-TEST-05 | Test without assertions | CRITICAL | Test functions with no assert/expect/verify calls |
| V-TEST-06 | Flaky test introduced | CRITICAL | Non-deterministic test (passes/fails inconsistently) |
| V-TEST-07 | Mocking internal implementation details | MEDIUM | Mocking private methods, testing implementation not behavior |

### TDD Mandate

**TDD is MANDATORY.** The Red-Green-Refactor cycle is non-negotiable for all new code.

```
RED -> GREEN -> REFACTOR
```

Skipping TDD = V-TEST-02 (HIGH -> BLOCK). Write the failing test FIRST, then make it pass.

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

## Quality Gates

> See [references/quality-gates.md](references/quality-gates.md) for gate categories, execution order, coverage thresholds, and pre-commit/CI/CD gate checklists.

## Test Quality Checklist

- [ ] Tests follow 70/20/10 distribution
- [ ] Each test has single assertion focus
- [ ] Tests are independent (no shared state)
- [ ] Test names describe behavior
- [ ] No test.skip() in codebase
- [ ] Regression tests for fixed bugs
- [ ] Coverage targets met (80%+)
- [ ] Type check passes
- [ ] No lint errors
- [ ] Build succeeds

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
- **For testing pyramid details**: See `references/pyramid.md`
- **For quality gates**: See `references/quality-gates.md`
- **For quality gate protocol**: See `references/quality-gate-protocol.md`

## Related Skills

- **Code quality**: See `code/code-quality` for SOLID principles validated by gates
- **Debugging**: See `quality/debugging-performance` for fixing test failures
- **CI/CD**: See `delivery/ci-cd` for pipeline gate integration
