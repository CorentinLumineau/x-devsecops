---
name: analysis-architecture
description: Use when making architectural decisions, prioritizing work, or creating ADRs/RFCs. Covers Pareto analysis, trade-off frameworks, and software architecture patterns.
version: "1.0.0"
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
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

For architecture pattern matrices, DDD patterns, and detailed comparisons, see `references/decision-matrices.md`.

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

**Best Practices**: One decision per ADR, number sequentially, keep in version control, link related ADRs.

### RFC (Request for Comments)

Use for larger changes needing broad input (>2 weeks work or cross-team impact).

**Timeline**: 1 week draft, 2 weeks review, 1 week final comment. Approval requires 2+ reviewers with no blocking concerns.

## Trade-off Analysis

| Dimension | Trade-off |
|-----------|-----------|
| Speed vs Quality | Ship fast vs polish |
| Build vs Buy | Control vs time-to-market |
| Flexibility vs Simplicity | Generic vs specific |
| Consistency vs Innovation | Standard vs new approach |

## Architecture Patterns (Summary)

| Pattern | Best For | Team Size |
|---------|----------|-----------|
| Modular Monolith | Most startups, small teams | 1-10 |
| Microservices | Large orgs, independent deployment | 10+ per service |
| Event-Driven | Async workflows, decoupling | 5+ |
| CQRS | Read/write asymmetry (>10:1 ratio) | 5+ |
| Hexagonal | Testability, port swapping | 3+ |
| Clean Architecture | Long-lived enterprise apps | 5+ |

**Default**: Start with Modular Monolith, extract later.

For full decision trees, comparison matrices, and DDD patterns, see `references/decision-matrices.md`.

## Analysis Framework

1. **Define the Problem** - What exactly needs to be solved? Who is affected?
2. **Gather Data** - Current metrics, user feedback, technical constraints
3. **Identify Options** - List all approaches, include "do nothing"
4. **Evaluate Trade-offs** - Pros, cons, risk for each option
5. **Decide and Document** - Clear recommendation, reasoning, rollback plan

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
- [ ] Architecture matches team size and skills

## When to Load References

- **For ADR templates and formats**: See `references/adr-template.md`
- **For real-world ADR examples**: See `references/adr-examples.md`
- **For prioritization frameworks** (RICE, MoSCoW, WSJF): See `references/prioritization.md`
- **For RFC process and lifecycle**: See `references/rfc-process.md`
- **For clean architecture layers**: See `references/clean-architecture.md`
- **For event-driven patterns**: See `references/event-driven.md`
- **For microservices patterns**: See `references/microservices.md`
- **For decision matrices and pattern comparisons**: See `references/decision-matrices.md`

## Related Skills

- `@skills/code-code-quality` - SOLID principles for code-level design
- `@skills/code-design-patterns` - Implementation-level patterns (Factory, Strategy, Observer)
- `@skills/code-api-design` - API design and versioning
- `@skills/data-data-persistence` - Database selection and optimization
- `@skills/delivery-ci-cd-delivery` - CI/CD for architecture deployment
- `@skills/operations-sre-operations` - Incident handling for distributed systems
- `data/messaging` - Event-driven implementation patterns (Kafka, RabbitMQ, message design)
