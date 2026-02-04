---
name: decision-making
description: Technical decision frameworks. ADRs, RFC patterns, evaluating alternatives.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: meta
---

# Decision Making

Frameworks for technical decisions and documentation.

## When to Document Decisions

| Scenario | Documentation |
|----------|---------------|
| Architecture change | ADR required |
| Technology choice | ADR recommended |
| Process change | RFC or ADR |
| Bug fix | None needed |
| Feature implementation | Context in PR |

## ADR (Architecture Decision Record)

### Template
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

### ADR Best Practices
- One decision per ADR
- Number sequentially
- Keep in version control
- Link related ADRs
- Update status when superseded

## RFC (Request for Comments)

Use for larger changes needing broad input.

### RFC Template
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

## Decision Criteria Matrix

| Criterion | Weight | Option A | Option B |
|-----------|--------|----------|----------|
| Performance | 3 | 4/5 | 3/5 |
| Maintainability | 2 | 3/5 | 4/5 |
| Learning curve | 1 | 2/5 | 5/5 |
| **Total** | | **26** | **27** |

## Technology Evaluation

| Factor | Questions |
|--------|-----------|
| Maturity | How long in production use? |
| Community | Size, activity, responsiveness? |
| Documentation | Quality, completeness? |
| Ecosystem | Plugins, integrations? |
| Team expertise | Learning curve? |
| Maintenance | Long-term commitment? |

## Decision Anti-Patterns

| Anti-pattern | Better Approach |
|--------------|-----------------|
| Analysis paralysis | Time-box decisions |
| HIPPO (highest paid opinion) | Data-driven criteria |
| Resume-driven | Business needs first |
| Golden hammer | Right tool for job |

## Reversibility

| Reversibility | Approach |
|---------------|----------|
| Easy to reverse | Decide quickly, iterate |
| Hard to reverse | Take time, gather input |
| One-way door | Extensive analysis, approval |

## Checklist

- [ ] Problem clearly stated
- [ ] Options evaluated fairly
- [ ] Criteria defined and weighted
- [ ] Trade-offs documented
- [ ] Decision recorded (ADR/RFC)
- [ ] Stakeholders informed
- [ ] Implementation plan exists

## When to Load References

- **For ADR examples**: See `references/adr-examples.md`
- **For RFC process**: See `references/rfc-process.md`
