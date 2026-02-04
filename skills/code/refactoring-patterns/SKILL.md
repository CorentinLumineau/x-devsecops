---
name: refactoring-patterns
description: Fowler's refactoring catalog and safe refactoring techniques.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# Refactoring Patterns

Safe, systematic approaches to improving code structure without changing behavior.

## Quick Reference (80/20)

| Refactoring | When to Use | Risk |
|------------|-------------|------|
| Extract Method | Long method, duplicated logic | Low |
| Extract Class | Class with multiple responsibilities | Medium |
| Move Method | Method uses another class more | Low |
| Rename | Name does not reveal intent | Low |
| Replace Conditional with Polymorphism | Complex switch/if chains | Medium |
| Introduce Parameter Object | Long parameter lists | Low |

## Code Smells to Refactoring Map

| Smell | Primary Refactoring |
|-------|-------------------|
| Long Method | Extract Method |
| Large Class | Extract Class |
| Feature Envy | Move Method |
| Data Clumps | Introduce Parameter Object |
| Primitive Obsession | Replace Primitive with Object |
| Switch Statements | Replace with Polymorphism |
| Parallel Inheritance | Move Method, Collapse Hierarchy |
| Divergent Change | Extract Class |
| Shotgun Surgery | Move Method, Inline Class |

## Safe Refactoring Workflow

```
1. Ensure tests pass (green)
2. Make one refactoring move
3. Run tests (must stay green)
4. Commit
5. Repeat
```

## Strangler Fig Pattern

| Phase | Action | Risk |
|-------|--------|------|
| 1. Identify | Map legacy boundaries | None |
| 2. Intercept | Add facade/proxy | Low |
| 3. Implement | Build new alongside old | Medium |
| 4. Redirect | Route traffic to new | Medium |
| 5. Remove | Decommission old code | Low |

## When NOT to Refactor

| Situation | Instead |
|-----------|---------|
| No tests exist | Write characterization tests first |
| Deadline pressure | Document debt, refactor later |
| Complete rewrite needed | Plan migration, not refactoring |
| Code rarely changes | Leave it alone (Pareto) |

## Checklist

- [ ] Tests exist and pass before starting
- [ ] Single refactoring per commit
- [ ] No behavior changes mixed with refactoring
- [ ] Code review for non-trivial refactoring
- [ ] IDE refactoring tools used where possible
- [ ] Performance not degraded

## When to Load References

- **For common refactorings**: See `references/common-refactorings.md`
- **For large-scale refactoring**: See `references/large-scale-refactoring.md`
