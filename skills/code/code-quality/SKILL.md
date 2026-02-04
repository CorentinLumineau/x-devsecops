---
name: code-quality
description: Enforces SOLID, DRY, KISS, YAGNI principles when writing or reviewing code.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# Code Quality

Autonomous enforcement of development best practices for maintainable, scalable software.

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

## When to Load References

- **For detailed SOLID examples**: See `references/solid-examples.md`
- **For anti-patterns catalog**: See `references/anti-patterns.md`
