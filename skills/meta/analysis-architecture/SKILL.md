---
name: analysis-architecture
description: Pareto analysis, prioritization frameworks, decision records (ADRs/RFCs), trade-off analysis, and software architecture patterns.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "2.0.0"
  category: meta
---

# Analysis & Architecture

Prioritization frameworks, decision-making processes, and software architecture patterns.

## Quick Reference (80/20)

| Domain | Key Concepts | When to Apply |
|--------|-------------|---------------|
| Pareto 80/20 | Impact ranking, effort-to-value ratio, quick wins | Any planning, analysis, or prioritization task |
| Priority Matrix | P1-P4 classification by impact and effort | Backlog grooming, sprint planning |
| ADRs | Status, context, decision, consequences | Architecture changes, technology choices |
| RFCs | Problem, proposal, alternatives, risks | Large changes needing broad input (>2 weeks or cross-team) |
| Trade-off Analysis | Dimensions, options scoring, weighted criteria | Technology evaluation, build vs buy |
| Microservices | Service decomposition, sagas, contracts | Large teams, independent deployment needs |
| Event-Driven | Events, producers, consumers, event sourcing | Async workflows, decoupling, audit trails |
| Clean Architecture | Entities, use cases, adapters, frameworks | Long-lived apps needing testability and adaptability |
| CQRS | Separate read/write models | Read/write asymmetry (>10:1 ratio) |
| Hexagonal | Ports and adapters, driving/driven sides | Infrastructure swappability, testability |

## Enforcement Criteria

Pareto violations that workflow agents must detect and flag:

| ID | Violation | Severity | Example |
|----|-----------|----------|---------|
| V-PARETO-01 | Over-engineered solution | HIGH | >3x complexity for marginal improvement |
| V-PARETO-02 | Missing prioritization in output | MEDIUM | Analysis without impact ranking |
| V-PARETO-03 | Scope creep beyond 80/20 focus | MEDIUM | Implementing low-value items before high-value |

### Anti-Patterns
- Exhaustive analysis when focused analysis suffices
- Equal treatment of all items without impact ranking
- Building comprehensive solutions when targeted ones would deliver 80% of value
- Comprehensive documentation of rarely-used features over core flows

### Pareto-Compliant Output
Analysis and planning outputs SHOULD include:
- Impact ranking (Critical > High > Medium > Low)
- Effort-to-value ratio for each item
- Clear "Quick Wins" identification (high impact, low effort)
- Explicit deprioritization of low-value items

## Priority Matrix

| Priority | Impact | Effort | Action |
|----------|--------|--------|--------|
| P1 | High | Low | Do first |
| P2 | High | High | Plan carefully |
| P3 | Low | Low | Quick wins |
| P4 | Low | High | Deprioritize |

## Decision Frameworks

### When to Document Decisions

| Scenario | Documentation |
|----------|---------------|
| Architecture change | ADR required |
| Technology choice | ADR recommended |
| Large cross-team change | RFC required |
| Process change | RFC or ADR |
| Bug fix | None needed |
| Feature implementation | Context in PR |

### ADR (Architecture Decision Record)

```markdown
# ADR-001: [Title]

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
What is the issue motivating this decision?

## Decision
What is the change being proposed?

## Consequences
What becomes easier or harder?
```

**Best Practices**: One decision per ADR, number sequentially, keep in version control, link related ADRs, update status when superseded.

### RFC (Request for Comments)

Use for larger changes needing broad input (>2 weeks work or cross-team impact).

```markdown
# RFC: [Title]

## Summary
One paragraph overview.

## Motivation
Why should we do this?

## Detailed Design
How will this work?

## Drawbacks
Why might we not do this?

## Alternatives
What other approaches were considered?

## Unresolved Questions
What needs more discussion?
```

**Timeline**: 1 week draft, 2 weeks review, 1 week final comment. Approval requires 2+ reviewers with no blocking concerns.

### Decision Criteria Matrix

| Criterion | Weight | Option A | Option B |
|-----------|--------|----------|----------|
| Performance | 3 | 4/5 | 3/5 |
| Maintainability | 2 | 3/5 | 4/5 |
| Learning curve | 1 | 2/5 | 5/5 |
| **Total** | | **26** | **27** |

### Decision Anti-Patterns

| Anti-pattern | Better Approach |
|--------------|-----------------|
| Analysis paralysis | Time-box decisions |
| HIPPO (highest paid opinion) | Data-driven criteria |
| Resume-driven | Business needs first |
| Golden hammer | Right tool for job |

### Reversibility

| Reversibility | Approach |
|---------------|----------|
| Easy to reverse | Decide quickly, iterate |
| Hard to reverse | Take time, gather input |
| One-way door | Extensive analysis, approval |

## Trade-off Analysis

| Dimension | Trade-off |
|-----------|-----------|
| Speed vs Quality | Ship fast vs polish |
| Build vs Buy | Control vs time-to-market |
| Flexibility vs Simplicity | Generic vs specific |
| Consistency vs Innovation | Standard vs new approach |

## Architecture Patterns

### Pattern Selection Decision Tree

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

### Architecture Decision Matrix

| Factor | Monolith | Microservices | Event-Driven |
|--------|----------|---------------|-------------|
| Deployment | Simple | Complex | Medium |
| Data consistency | Strong (ACID) | Eventual | Eventual |
| Latency | Low (in-process) | Higher (network) | Variable |
| Scaling | Vertical | Horizontal per service | Horizontal |
| Debugging | Easy | Hard (distributed) | Hard (async) |
| Team autonomy | Low | High | Medium |

### Pattern Quick Reference

| Pattern | Best For | Complexity | Team Size |
|---------|----------|-----------|-----------|
| Modular Monolith | Most startups, small teams | Low | 1-10 |
| Microservices | Large orgs, independent deployment | High | 10+ per service |
| Event-Driven | Async workflows, decoupling | Medium-high | 5+ |
| CQRS | Read/write asymmetry | Medium | 5+ |
| Hexagonal | Testability, port swapping | Medium | 3+ |
| Clean Architecture | Long-lived enterprise apps | Medium | 5+ |

### DDD Strategic Patterns

| Pattern | Purpose |
|---------|---------|
| Bounded Context | Define model boundaries |
| Context Map | Show relationships between contexts |
| Ubiquitous Language | Shared vocabulary per context |
| Anti-Corruption Layer | Protect from external model changes |
| Shared Kernel | Small shared model between contexts |

## Analysis Framework

### 1. Define the Problem
- What exactly needs to be solved?
- Who is affected?
- What is the impact of not solving it?

### 2. Gather Data
- Current metrics
- User feedback
- Technical constraints

### 3. Identify Options
- List all approaches
- Include "do nothing"

### 4. Evaluate Trade-offs

| Option | Pros | Cons | Risk |
|--------|------|------|------|
| A | ... | ... | ... |
| B | ... | ... | ... |

### 5. Decide and Document
- Clear recommendation
- Reasoning documented
- Rollback plan

## Prioritization Frameworks

| Framework | Best For |
|-----------|----------|
| RICE | Product features |
| MoSCoW | Requirements |
| Eisenhower | Time management |
| WSJF | Agile planning |
| Value vs Effort | Quick decisions |

## Technology Evaluation

| Factor | Questions |
|--------|-----------|
| Maturity | How long in production use? |
| Community | Size, activity, responsiveness? |
| Documentation | Quality, completeness? |
| Ecosystem | Plugins, integrations? |
| Team expertise | Learning curve? |
| Maintenance | Long-term commitment? |

## Quick Wins Identification

Criteria for quick wins:
- [ ] Low implementation effort
- [ ] High user impact
- [ ] Low risk of regression
- [ ] Independent of other work
- [ ] Clear success criteria

## Checklist

- [ ] Problem clearly defined
- [ ] Stakeholders identified
- [ ] Options listed (including "do nothing")
- [ ] Trade-offs evaluated with weighted criteria
- [ ] Decision documented (ADR/RFC as appropriate)
- [ ] Success criteria defined
- [ ] Architecture matches team size and skills
- [ ] Boundaries align with business domains
- [ ] Communication patterns defined
- [ ] Failure modes analyzed

## Related Skills

- `@skills/code-code-quality` - SOLID principles for code-level design
- `@skills/code-design-patterns` - Implementation-level patterns (Factory, Strategy, Observer)
- `@skills/code-api-design` - API design and versioning
- `@skills/data-database` - Database selection and optimization
- `@skills/delivery-ci-cd` - CI/CD for architecture deployment
- `@skills/operations-incident-response` - Incident handling for distributed systems

## When to Load References

- **For ADR templates and formats**: See `references/adr-template.md`
- **For real-world ADR examples** (database, API, auth, infrastructure): See `references/adr-examples.md`
- **For prioritization frameworks** (RICE, MoSCoW, WSJF, Eisenhower): See `references/prioritization.md`
- **For RFC process and lifecycle**: See `references/rfc-process.md`
- **For clean architecture layers and dependency rules**: See `references/clean-architecture.md`
- **For event-driven patterns** (event sourcing, CQRS, pub/sub, DLQ): See `references/event-driven.md`
- **For microservices patterns** (decomposition, sagas, service mesh, contract testing): See `references/microservices.md`
