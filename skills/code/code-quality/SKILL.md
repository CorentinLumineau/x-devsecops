---
name: code-quality
description: Enforces SOLID, DRY, KISS, YAGNI principles, refactoring patterns, and code review practices.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# Code Quality

Autonomous enforcement of development best practices for maintainable, scalable software. Includes SOLID principles, refactoring catalog, and code review practices.

## Enforcement Definitions

Violation IDs used by workflow skills (x-implement, x-verify, x-review, git-commit) to enforce code quality.

**Severity Model**: CRITICAL/HIGH = BLOCK (must fix), MEDIUM = WARN (flag to user), LOW = INFO (note).

### SOLID Violations

| ID | Principle | Violation | Severity | Detection |
|----|-----------|-----------|----------|-----------|
| V-SOLID-01 | SRP | Class/module has >1 reason to change (mixed concerns) | CRITICAL | >300 lines with multiple domains, mixed I/O and logic |
| V-SOLID-02 | OCP | Modifying existing code to add new behavior | HIGH | Switch/if-else chains for type dispatch, instanceof checks |
| V-SOLID-03 | LSP | Subtype breaks base type contract | CRITICAL | Overridden methods with different semantics, thrown unexpected errors |
| V-SOLID-04 | ISP | Interface forces unused method implementations | HIGH | Empty/stub method implementations, "god interfaces" |
| V-SOLID-05 | DIP | High-level module depends on concrete implementation | HIGH | `new` in constructors, direct imports of concrete classes |

### DRY Violations

| ID | Violation | Severity | Detection |
|----|-----------|----------|-----------|
| V-DRY-01 | Significant code duplication (>10 lines) | HIGH | Near-identical blocks across files or within same file |
| V-DRY-02 | Minor code duplication (3-10 lines) | MEDIUM | Repeated patterns that should be extracted |
| V-DRY-03 | Magic values repeated in multiple places | MEDIUM | Same literal values (strings, numbers) without named constants |

### KISS Violations

| ID | Violation | Severity | Detection |
|----|-----------|----------|-----------|
| V-KISS-01 | Over-engineered abstraction | MEDIUM | Factory-builder-provider chains, unnecessary indirection layers |
| V-KISS-02 | Unnecessary complexity (>3 nested levels) | HIGH | Deep nesting, convoluted control flow, overly generic solutions |

### YAGNI Violations

| ID | Violation | Severity | Detection |
|----|-----------|----------|-----------|
| V-YAGNI-01 | Speculative feature (not requested) | HIGH | "Just in case" code, unused parameters "for future use" |
| V-YAGNI-02 | Premature optimization | MEDIUM | Performance optimization without measured bottleneck |

### Documentation Violations

| ID | Violation | Severity | Detection |
|----|-----------|----------|-----------|
| V-DOC-01 | Stale API documentation | HIGH | API signatures changed but docs not updated |
| V-DOC-02 | Missing public API documentation | CRITICAL | Public function/class/module with no docs |
| V-DOC-03 | Broken documentation references | MEDIUM | Dead links, references to renamed/removed entities |
| V-DOC-04 | Missing change documentation | HIGH | Behavioral changes not reflected in relevant docs |

## SOLID Principles

| Principle | Check | Violation Signs |
|-----------|-------|-----------------|
| **S**ingle Responsibility | One reason to change per function/class | Class over 300 lines, mixed concerns |
| **O**pen/Closed | Extend without modification | Switch statements for types, instanceof checks |
| **L**iskov Substitution | Subtypes substitute base types | Overridden methods with different behavior |
| **I**nterface Segregation | Small, focused interfaces | Unused method implementations, "god interfaces" |
| **D**ependency Inversion | Depend on abstractions | `new` in constructors, concrete dependencies |

## DRY - Don't Repeat Yourself

**Definition**: Every piece of knowledge has single, unambiguous representation.

**Check For**:
- Duplicated validation logic
- Copy-pasted code blocks
- Magic numbers/strings in multiple places
- Same business rule in different files

**Fix**: Extract to shared utilities, constants, or helper functions.

## KISS - Keep It Simple

**Definition**: Simplicity is a key design goal.

**Check For**:
- Over-engineered solutions (factory-builder-provider chains)
- Unnecessary abstraction layers
- Premature optimization
- Complex code for simple tasks

**Fix**: Start simple, add complexity only when concrete need exists.

## YAGNI - You Aren't Gonna Need It

**Definition**: Don't add functionality until necessary.

**Check For**:
- "Just in case" features
- Speculative APIs
- Unused parameters "for future use"
- Over-generalized solutions

**Fix**: Build only what's required now. Document ideas separately.

## Refactoring Catalog (Fowler's Patterns)

### Quick Reference (80/20)

| Refactoring | When to Use | Risk |
|------------|-------------|------|
| Extract Method | Long method, duplicated logic | Low |
| Extract Class | Class with multiple responsibilities | Medium |
| Move Method | Method uses another class more | Low |
| Rename | Name does not reveal intent | Low |
| Replace Conditional with Polymorphism | Complex switch/if chains | Medium |
| Introduce Parameter Object | Long parameter lists | Low |

### Code Smells to Refactoring Map

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

### Safe Refactoring Workflow

```
1. Ensure tests pass (green)
2. Make one refactoring move
3. Run tests (must stay green)
4. Commit
5. Repeat
```

### Large-Scale Refactoring Strategies

| Strategy | Duration | Risk | Best For |
|----------|----------|------|----------|
| Strangler Fig | Months | Low | Monolith decomposition |
| Branch by Abstraction | Weeks | Low-medium | Swapping implementations |
| Parallel Run | Weeks | Low | Verifying replacement correctness |
| Feature Toggle Migration | Days-weeks | Low | Gradual rollout |

### When NOT to Refactor

| Situation | Instead |
|-----------|---------|
| No tests exist | Write characterization tests first |
| Deadline pressure | Document debt, refactor later |
| Complete rewrite needed | Plan migration, not refactoring |
| Code rarely changes | Leave it alone (Pareto) |

## Code Review Practices

### PR Review Checklist

| Category | Check |
|----------|-------|
| Correctness | Does the code do what it claims? |
| Design | Is the approach appropriate for the problem? |
| Naming | Are variables, functions, classes well-named? |
| Complexity | Is the code as simple as possible? |
| Tests | Are there adequate tests for the changes? |
| Consistency | Does it follow existing codebase patterns? |
| Security | Are there any security implications? |
| Performance | Are there obvious performance concerns? |

### Review Anti-Patterns

| Anti-Pattern | Better Approach |
|--------------|----------------|
| Rubber-stamping (approval without reading) | Allocate dedicated review time |
| Nitpicking style only | Focus on logic, design, correctness first |
| Blocking on preferences | Distinguish preferences from requirements |
| Reviewing too late | Review early, review often (draft PRs) |
| Huge PRs (>500 lines) | Break into focused, reviewable chunks |
| No context in PR description | Require clear description of what and why |

### Effective Feedback Guidelines

| Do | Avoid |
|----|-------|
| Ask questions to understand intent | Assume bad intent |
| Suggest alternatives with reasoning | Dictate without explanation |
| Distinguish "must fix" from "nit" | Treat all feedback as blocking |
| Praise good patterns | Only point out problems |
| Link to relevant standards/docs | Make unsubstantiated claims |

## Quality Checklist

### Before Coding
- [ ] Understand single responsibility for new code
- [ ] Identify interfaces/abstractions to depend on
- [ ] Confirm feature is actually required (YAGNI)

### During Coding
- [ ] Keep functions focused (<50 lines recommended)
- [ ] Extract duplicated logic immediately (DRY)
- [ ] Inject dependencies, don't instantiate (DIP)
- [ ] Use descriptive names over comments (KISS)

### After Coding
- [ ] Each class has single responsibility (SRP)
- [ ] Can extend without modifying existing code (OCP)
- [ ] No unused interface methods implemented (ISP)
- [ ] No speculative features (YAGNI)
- [ ] No code duplication (DRY)
- [ ] Tests pass before and after refactoring

## Quick Reference

| Smell | Principle | Action |
|-------|-----------|--------|
| Large class | SRP | Split by responsibility |
| Type switches | OCP | Use polymorphism |
| Unused methods | ISP | Split interface |
| Direct instantiation | DIP | Inject dependency |
| Copy-pasted code | DRY | Extract function |
| Complex solution | KISS | Simplify |
| "Maybe needed" code | YAGNI | Remove |
| Long method | Refactoring | Extract Method |
| Data clumps | Refactoring | Introduce Parameter Object |
| Feature envy | Refactoring | Move Method |

## When to Load References

- **For detailed SOLID examples**: See `references/solid-examples.md`
- **For anti-patterns catalog**: See `references/anti-patterns.md`
- **For code quality checklist**: See `references/checklist.md`
- **For common refactorings (Fowler's catalog)**: See `references/common-refactorings.md`
- **For large-scale refactoring strategies**: See `references/large-scale-refactoring.md`

## Related Skills

- **@skills/code-design-patterns/** - GoF design patterns for object-oriented design
- **@skills/code-error-handling/** - Error handling patterns and exception management
- **@skills/code-api-design/** - REST API and SDK design best practices
- **@skills/quality-testing/** - Testing strategies and TDD
