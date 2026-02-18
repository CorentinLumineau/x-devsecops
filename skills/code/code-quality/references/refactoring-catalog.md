# Refactoring Catalog (Fowler's Patterns)

Comprehensive refactoring reference based on Martin Fowler's catalog.

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

## Large-Scale Refactoring Strategies

| Strategy | Duration | Risk | Best For |
|----------|----------|------|----------|
| Strangler Fig | Months | Low | Monolith decomposition |
| Branch by Abstraction | Weeks | Low-medium | Swapping implementations |
| Parallel Run | Weeks | Low | Verifying replacement correctness |
| Feature Toggle Migration | Days-weeks | Low | Gradual rollout |

## When NOT to Refactor

| Situation | Instead |
|-----------|---------|
| No tests exist | Write characterization tests first |
| Deadline pressure | Document debt, refactor later |
| Complete rewrite needed | Plan migration, not refactoring |
| Code rarely changes | Leave it alone (Pareto) |
