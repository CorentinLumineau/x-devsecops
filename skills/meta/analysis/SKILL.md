---
name: analysis
description: Pareto 80/20 analysis and prioritization frameworks. Decision making, trade-offs.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.1.0"
  category: meta
---

# Analysis

Prioritization and decision-making frameworks.

## Pareto Principle (80/20)

**20% of effort produces 80% of value**

| Application | Focus On |
|-------------|----------|
| Features | High-impact functionality |
| Bugs | Most reported issues |
| Tests | Critical paths |
| Performance | Biggest bottlenecks |

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

## Analysis Framework

### 1. Define the Problem
- What exactly needs to be solved?
- Who is affected?
- What's the impact of not solving it?

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

## Trade-off Analysis

| Dimension | Trade-off |
|-----------|-----------|
| Speed vs Quality | Ship fast vs polish |
| Build vs Buy | Control vs time-to-market |
| Flexibility vs Simplicity | Generic vs specific |
| Consistency vs Innovation | Standard vs new approach |

## Quick Wins Identification

Criteria for quick wins:
- [ ] Low implementation effort
- [ ] High user impact
- [ ] Low risk of regression
- [ ] Independent of other work
- [ ] Clear success criteria

## Decision Documentation

```markdown
# Decision: [Title]

## Context
What's the situation requiring a decision?

## Options Considered
1. Option A - description
2. Option B - description

## Decision
We chose [option] because [reasoning].

## Consequences
- Positive: [benefits]
- Negative: [costs/risks]
- Neutral: [observations]
```

## Checklist

- [ ] Problem clearly defined
- [ ] Stakeholders identified
- [ ] Options listed (including "do nothing")
- [ ] Trade-offs evaluated
- [ ] Decision documented
- [ ] Success criteria defined

## When to Load References

- **For ADR templates**: See `references/adr-template.md`
- **For prioritization frameworks**: See `references/prioritization.md`
