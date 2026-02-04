---
name: design-patterns
description: Gang of Four design patterns for object-oriented software. Creational, structural, behavioral.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# Design Patterns

Reusable solutions to common software design problems.

## Pattern Categories

| Category | Purpose | Examples |
|----------|---------|----------|
| Creational | Object creation | Factory, Singleton, Builder |
| Structural | Object composition | Adapter, Decorator, Repository |
| Behavioral | Object interaction | Strategy, Observer, Command |

## Most Used Patterns (80/20)

### Factory Pattern
**Use when**: Creating objects without specifying exact class.

```
Client → Factory.create(type) → ConcreteProduct
```

### Repository Pattern
**Use when**: Abstracting data access logic.

```
Service → Repository.find(criteria) → Entity
```

### Strategy Pattern
**Use when**: Algorithms need to be interchangeable.

```
Context → Strategy.execute() → Different implementations
```

### Observer Pattern
**Use when**: Objects need to be notified of changes.

```
Subject → notify() → Observer1, Observer2, ...
```

## Pattern Selection Guide

| Need | Pattern |
|------|---------|
| Create objects flexibly | Factory |
| Abstract data access | Repository |
| Swap algorithms | Strategy |
| React to events | Observer |
| Add behavior dynamically | Decorator |
| Convert interfaces | Adapter |
| Build complex objects | Builder |
| Single instance | Singleton (rarely) |

## When to Use Each

### Factory
- Multiple product types
- Creation logic is complex
- Decoupling client from implementation

### Repository
- Multiple data sources
- Complex queries
- Testing with mocks

### Strategy
- Multiple algorithms for same task
- Algorithm selection at runtime
- Avoiding conditional complexity

### Observer
- Event-driven systems
- Loose coupling between components
- One-to-many dependencies

## Anti-Patterns

| Anti-pattern | Issue | Fix |
|--------------|-------|-----|
| Singleton abuse | Global state | Dependency injection |
| Pattern overuse | Over-engineering | KISS, start simple |
| Wrong pattern | Mismatch | Understand problem first |

## Pattern Checklist

Before applying a pattern:
- [ ] Problem clearly understood
- [ ] Pattern addresses actual need
- [ ] Simpler solution doesn't exist
- [ ] Team understands the pattern

## When to Load References

- **For creational patterns**: See `references/creational.md`
- **For structural patterns**: See `references/structural.md`
- **For behavioral patterns**: See `references/behavioral.md`
