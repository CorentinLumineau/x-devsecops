# Quality Gates Protocol

> **Version**: 1.0.0
> **Purpose**: Standardized quality validation for all commands

## Overview

Quality gates are mandatory validation checkpoints that ensure code meets quality standards before proceeding to the next phase.

## Gate Categories

### Standard Gates (All Validation Commands)

Applied to: `/x:verify`, `/x:review`, `/x:commit`, `/x:implement`, `/x:fix`

| Gate | Tool/Command | Threshold | Blocking |
|------|--------------|-----------|----------|
| **Type Checking** | `tsc --noEmit` / `mypy` / `go vet` | 0 errors | Yes |
| **Linting** | `eslint` / `golint` / `ruff` | 0 errors | Yes |
| **Build** | `make build` / `npm run build` | Success | Yes |

### Extended Gates (Implementation Commands)

Applied to: `/x:implement`, `/x:fix`, `/x:improve-*`

| Gate | Tool/Command | Threshold | Blocking |
|------|--------------|-----------|----------|
| **Unit Tests** | `jest` / `pytest` / `go test` | All pass | Yes |
| **Coverage** | Coverage tool | 95%+ changed files | Yes |
| **SOLID Validation** | x-reviewer agent | No critical violations | Yes |

### Testing Pyramid Gates

| Gate | Distribution | Target |
|------|--------------|--------|
| **Unit Tests** | 70% ±10% | Fast, isolated tests |
| **Integration Tests** | 20% ±10% | Service interaction tests |
| **E2E Tests** | 10% ±5% | Full workflow tests |

### Documentation Gates

Applied to: `/x:sync-docs`, `/x:commit`, `/x:review`

| Gate | Check | Threshold | Blocking |
|------|-------|-----------|----------|
| **API Sync** | reference/ updated for public API changes | Matches code | Warning |
| **Architecture Sync** | implementation/ updated for arch changes | Matches changes | Warning |
| **CHANGELOG** | Updated for breaking changes | Entry exists | Warning |

## Execution Order

Gates run in order from fastest to slowest to fail fast:

```
1. Type Checking (fast, catches obvious issues)
   │
   ├─ FAIL → Stop, report type errors
   │
   ▼ PASS
2. Linting (fast, style/quality)
   │
   ├─ FAIL → Stop, report lint errors
   │
   ▼ PASS
3. Build (medium, integration)
   │
   ├─ FAIL → Stop, report build errors
   │
   ▼ PASS
4. Unit Tests (medium, correctness)
   │
   ├─ FAIL → Stop, report test failures
   │
   ▼ PASS
5. Coverage (medium, completeness)
   │
   ├─ FAIL → Warning if <95%, continue
   │
   ▼ PASS
6. SOLID Validation (slower, design quality)
   │
   ├─ FAIL → Warning for non-critical, stop for critical
   │
   ▼ PASS
7. Documentation Sync (fast, check only)
   │
   ├─ WARNING → Log warning, continue
   │
   ▼ COMPLETE
```

## Gate Configuration Per Command

| Command | Standard | Extended | Testing | Documentation |
|---------|----------|----------|---------|---------------|
| `/x:verify` | ✅ All | ✅ All | ✅ All | ✅ Check only |
| `/x:review` | ✅ All | ❌ Skip | ❌ Assumes passed | ✅ Check only |
| `/x:commit` | ✅ All | ❌ Skip | ❌ Assumes passed | ✅ Check only |
| `/x:implement` | ✅ All | ✅ All | ✅ All | ✅ Generate |
| `/x:fix` | ✅ All | ✅ Related | ✅ Related | ❌ Skip |

## Output Format

### Success Output
```
Quality Gates: ALL PASSED ✅

[1/6] Type Checking.......... ✓ PASS (0 errors)
[2/6] Linting................ ✓ PASS (0 errors, 2 warnings)
[3/6] Build.................. ✓ PASS (12.3s)
[4/6] Unit Tests (127)....... ✓ PASS
[5/6] Coverage............... ✓ PASS (96.2%)
[6/6] SOLID Validation....... ✓ PASS (no violations)

Duration: 45.2s
```

### Failure Output
```
Quality Gates: FAILED ❌

[1/6] Type Checking.......... ✗ FAIL (2 errors)
      └─ src/services/UserService.ts:45
         Type 'string' is not assignable to type 'User'
      └─ src/services/UserService.ts:67
         Property 'validate' does not exist on type 'User'

[2/6] Linting................ ⏸ SKIPPED (blocked by type errors)
[3/6] Build.................. ⏸ SKIPPED
[4/6] Unit Tests............. ⏸ SKIPPED
[5/6] Coverage............... ⏸ SKIPPED
[6/6] SOLID Validation....... ⏸ SKIPPED

Fix the 2 type errors and re-run validation.
```

## Invocation from Commands

Commands should NOT implement quality gates inline. Instead, invoke code-quality skill:

### Before (Inline - BAD)
```markdown
## Quality Gates

- [ ] Type Checking - No errors
- [ ] SOLID Principles - All validated
- [ ] Testing Pyramid - 70/20/10 distribution
- [ ] Coverage - 95%+ for changed files
- [ ] Build & Lint - Passing
- [ ] Documentation - Synced
```

### After (Reference - GOOD)
```markdown
3. **Quality Validation** (via code-quality skill)
   - Run standard + extended gates
   - See @skills/code-quality/references/QUALITY-GATES.md
```

## SOLID Validation Details

For SOLID validation, the code-quality skill invokes x-reviewer agent:

### Single Responsibility (SRP)
- [ ] Each class has ONE reason to change
- [ ] File size < 300 lines
- [ ] Method count < 15 per class
- [ ] No mixed concerns

### Open/Closed (OCP)
- [ ] Extension via interfaces, not modification
- [ ] No type-checking conditionals

### Liskov Substitution (LSP)
- [ ] Subclasses can replace parents
- [ ] No "Not Supported" exceptions

### Interface Segregation (ISP)
- [ ] Interfaces have < 5 methods
- [ ] No empty implementations

### Dependency Inversion (DIP)
- [ ] Dependencies injected, not instantiated
- [ ] Business logic uses abstractions

## Failure Handling

| Failure Type | Action |
|--------------|--------|
| Type errors | Stop execution, require fix |
| Lint errors | Stop execution, require fix |
| Build failure | Stop execution, require fix |
| Test failures | Stop execution, require fix |
| Coverage < 95% | Warning, allow continue |
| SOLID violation (critical) | Stop execution, require fix |
| SOLID violation (warning) | Warning, allow continue |
| Doc sync needed | Warning, suggest /x:sync-docs |

## Skip/Override

Gates should NEVER be skipped except:
- `--skip-tests` flag explicitly passed by user
- User explicitly requests skip via AskUserQuestion

## References

- @skills/code-code-quality/ - SOLID principles
- @skills/quality-testing/ - Testing pyramid and coverage strategies

---

**Version**: 1.0.0
**Created**: 2026-01-09
