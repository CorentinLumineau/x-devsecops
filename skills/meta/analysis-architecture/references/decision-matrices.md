# Decision Matrices

Architecture decision matrices, pattern selection trees, and detailed comparison tables.

---

## Architecture Decision Matrix

| Factor | Monolith | Microservices | Event-Driven |
|--------|----------|---------------|-------------|
| Deployment | Simple | Complex | Medium |
| Data consistency | Strong (ACID) | Eventual | Eventual |
| Latency | Low (in-process) | Higher (network) | Variable |
| Scaling | Vertical | Horizontal per service | Horizontal |
| Debugging | Easy | Hard (distributed) | Hard (async) |
| Team autonomy | Low | High | Medium |

---

## Pattern Quick Reference

| Pattern | Best For | Complexity | Team Size |
|---------|----------|-----------|-----------|
| Modular Monolith | Most startups, small teams | Low | 1-10 |
| Microservices | Large orgs, independent deployment | High | 10+ per service |
| Event-Driven | Async workflows, decoupling | Medium-high | 5+ |
| CQRS | Read/write asymmetry | Medium | 5+ |
| Hexagonal | Testability, port swapping | Medium | 3+ |
| Clean Architecture | Long-lived enterprise apps | Medium | 5+ |

---

## Pattern Selection Decision Tree

```
Team < 5 engineers?
  -> Modular Monolith

Need independent deployment per team?
  -> Microservices

Heavy async processing?
  -> Event-Driven

Read/write ratio > 10:1?
  -> Consider CQRS

Need to swap infrastructure easily?
  -> Hexagonal Architecture

Long-lived enterprise system?
  -> Clean Architecture

Uncertain? -> Start with Modular Monolith, extract later
```

---

## DDD Strategic Patterns

| Pattern | Purpose |
|---------|---------|
| Bounded Context | Define model boundaries |
| Context Map | Show relationships between contexts |
| Ubiquitous Language | Shared vocabulary per context |
| Anti-Corruption Layer | Protect from external model changes |
| Shared Kernel | Small shared model between contexts |

---

## Decision Criteria Matrix

| Criterion | Weight | Option A | Option B |
|-----------|--------|----------|----------|
| Performance | 3 | 4/5 | 3/5 |
| Maintainability | 2 | 3/5 | 4/5 |
| Learning curve | 1 | 2/5 | 5/5 |
| **Total** | | **26** | **27** |

---

## Decision Anti-Patterns

| Anti-pattern | Better Approach |
|--------------|-----------------|
| Analysis paralysis | Time-box decisions |
| HIPPO (highest paid opinion) | Data-driven criteria |
| Resume-driven | Business needs first |
| Golden hammer | Right tool for job |

---

## Reversibility

| Reversibility | Approach |
|---------------|----------|
| Easy to reverse | Decide quickly, iterate |
| Hard to reverse | Take time, gather input |
| One-way door | Extensive analysis, approval |

---

## Technology Evaluation

| Factor | Questions |
|--------|-----------|
| Maturity | How long in production use? |
| Community | Size, activity, responsiveness? |
| Documentation | Quality, completeness? |
| Ecosystem | Plugins, integrations? |
| Team expertise | Learning curve? |
| Maintenance | Long-term commitment? |

---

## Prioritization Frameworks

| Framework | Best For |
|-----------|----------|
| RICE | Product features |
| MoSCoW | Requirements |
| Eisenhower | Time management |
| WSJF | Agile planning |
| Value vs Effort | Quick decisions |
