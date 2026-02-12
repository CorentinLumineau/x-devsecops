---
name: architecture-patterns
description: Software architecture patterns including microservices, event-driven, CQRS, hexagonal, and clean architecture.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: meta
---

# Architecture Patterns

High-level software architecture patterns and their trade-offs.

## Quick Reference (80/20)

| Pattern | Best For | Complexity | Team Size |
|---------|----------|-----------|-----------|
| Modular Monolith | Most startups, small teams | Low | 1-10 |
| Microservices | Large orgs, independent deployment | High | 10+ per service |
| Event-Driven | Async workflows, decoupling | Medium-high | 5+ |
| CQRS | Read/write asymmetry | Medium | 5+ |
| Hexagonal | Testability, port swapping | Medium | 3+ |
| Clean Architecture | Long-lived enterprise apps | Medium | 5+ |

## Architecture Decision Matrix

| Factor | Monolith | Microservices | Event-Driven |
|--------|----------|---------------|-------------|
| Deployment | Simple | Complex | Medium |
| Data consistency | Strong (ACID) | Eventual | Eventual |
| Latency | Low (in-process) | Higher (network) | Variable |
| Scaling | Vertical | Horizontal per service | Horizontal |
| Debugging | Easy | Hard (distributed) | Hard (async) |
| Team autonomy | Low | High | Medium |

## When to Choose What

```
Team < 5 engineers?
  → Modular Monolith

Need independent deployment per team?
  → Microservices

Heavy async processing?
  → Event-Driven

Read/write ratio > 10:1?
  → Consider CQRS

Need to swap infrastructure easily?
  → Hexagonal Architecture

Long-lived enterprise system?
  → Clean Architecture

Uncertain? → Start with Modular Monolith, extract later
```

## DDD Strategic Patterns

| Pattern | Purpose |
|---------|---------|
| Bounded Context | Define model boundaries |
| Context Map | Show relationships between contexts |
| Ubiquitous Language | Shared vocabulary per context |
| Anti-Corruption Layer | Protect from external model changes |
| Shared Kernel | Small shared model between contexts |

## Checklist

- [ ] Architecture matches team size and skills
- [ ] Trade-offs documented (ADR)
- [ ] Boundaries align with business domains
- [ ] Data ownership clear per component
- [ ] Communication patterns defined
- [ ] Failure modes analyzed

## When to Load References

- **For microservices**: See `references/microservices.md`
- **For event-driven**: See `references/event-driven.md`
- **For clean architecture**: See `references/clean-architecture.md`
