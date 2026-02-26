---
name: persuasion-principles
description: "Use when understanding why agents rationalize rule violations or when designing enforcement gates. Covers influence psychology, Iron Law templates, and anti-rationalization table design."
version: "1.0.0"
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  category: meta
---

# Persuasion Principles

Influence psychology applied to agent behavioral enforcement. Provides the science behind Iron Laws, anti-rationalization tables, and hard gates.

## 80/20 Focus

Master these 3 principles (80% of enforcement impact):

| Priority | Principle | Enforcement Application |
|----------|-----------|------------------------|
| P1 | **Commitment & Consistency** | Iron Laws — once stated, agents follow through |
| P2 | **Authority** | Hard gates with violation codes (V-*) — authoritative rules resist override |
| P3 | **Pre-suasion / Naming** | Anti-rationalization tables — naming excuses before they're used prevents them |

## Quick Reference

| Principle | Mechanism | Enforcement Pattern | Example |
|-----------|-----------|---------------------|---------|
| Commitment | Self-binding statement | Iron Law ("NO X WITHOUT Y") | "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE" |
| Authority | Rule-backed enforcement | Violation codes (V-*) with severity | V-TEST-02 (HIGH) blocks merge |
| Pre-suasion | Pre-emptive framing | Anti-rationalization table | "The code is trivial" → "Trivial code gets trivial tests. Still mandatory." |
| Scarcity | Loss framing | Gate blocking language | "BLOCK — cannot proceed" (loss of progress) |
| Social proof | Ecosystem consistency | Cross-skill references | "See @skills/code-code-quality/references/anti-rationalization.md" |

## Enforcement Definitions

| ID | Violation | Severity | Detection |
|----|-----------|----------|-----------|
| V-PERSUASION-01 | Hard gate without Iron Law statement | MEDIUM | Gate section missing "NO X WITHOUT Y" pattern |
| V-PERSUASION-02 | Hard gate without rationalization table | HIGH | Blocking gate has no excuse/reality pairs |
| V-PERSUASION-03 | Rationalization excuse lacks specificity | MEDIUM | Generic excuses ("it's fine") instead of concrete ones ("the code is trivial") |

## Iron Law Template

Iron Laws are commitment-binding statements that resist rationalization. Use at the top of any hard gate section.

**Pattern**:
```
NO {action} WITHOUT {evidence}
```

**Examples**:
- `NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE`
- `NO PRODUCTION CODE WITHOUT FAILING TEST` (TDD)
- `NO MERGE WITHOUT PASSING QUALITY GATES`

**Design rules**:
1. State what is forbidden (the action agents want to skip)
2. State what is required (the evidence that proves compliance)
3. Use ALL CAPS for the law itself — visual authority signal
4. Place immediately before the gate checklist
5. Follow with a rationalization table to pre-empt objections

## Rationalization Table Design

Anti-rationalization tables name agent excuses before they occur, dramatically reducing shortcut-taking.

### When to Use

| Context | Table Format | Columns |
|---------|-------------|---------|
| **Knowledge skills** (enforcement references) | 3-column | Excuse / Reality / Violation |
| **Behavioral skills** (workflow context) | 2-column | Excuse / Reality |
| **Workflow skills** (inline hard gates) | 2-column | Excuse / Reality |

### Design Principles

1. **Be specific** — "The code is trivial" beats "It's not important"
2. **Mirror real excuses** — Harvest from actual agent failures, not hypotheticals
3. **Reality must be actionable** — Tell the agent what to do, not just why the excuse is wrong
4. **4-8 entries per table** — Enough to cover common cases, not so many they're ignored
5. **Order by frequency** — Most common excuse first

### 3-Column Template (Knowledge Skills)

```markdown
| Excuse | Reality | Violation |
|--------|---------|-----------|
| "{specific excuse}" | {actionable correction} | V-{CODE}-{NN} |
```

### 2-Column Template (Behavioral/Workflow Skills)

```markdown
| Excuse | Reality |
|--------|---------|
| "{specific excuse}" | {actionable correction} |
```

## Research Foundation

| Source | Finding | Application |
|--------|---------|-------------|
| Cialdini 2021 | Commitment/consistency is the strongest self-regulation mechanism | Iron Laws as commitment devices |
| Meincke et al. 2025 (N=28,000) | Pre-naming objections reduces resistance by 40-60% | Anti-rationalization tables |
| Behavioral economics | Loss aversion > gain motivation (2:1 ratio) | BLOCK language in gates |

## Skill Type to Principle Mapping

| Skill Type | Primary Principle | Secondary | Pattern |
|------------|-------------------|-----------|---------|
| **Behavioral** (interview, verification) | Commitment | Pre-suasion | Iron Law + 2-col table |
| **Workflow** (x-implement, x-review) | Authority | Commitment | V-codes + Iron Law |
| **Knowledge** (code-quality, testing) | Authority | Pre-suasion | V-codes + 3-col table |
| **Hard gates** (TDD, coverage) | All three | Scarcity | Iron Law + table + BLOCK |

## When to Load References

*No reference files — this skill is self-contained as a meta-knowledge resource.*

## Related Skills

- `@skills/code-code-quality/` - Primary consumer: anti-rationalization reference (107 lines, 35+ pairs)
- `@skills/meta-analysis-architecture/` - Sibling meta skill (prioritization, ADRs)
- `@skills/quality-testing/` - Consumer: TDD enforcement with V-TEST-* codes
