---
title: Agent Usage in Knowledge Skills
type: meta
version: "1.0.0"
---

# Agent Usage in Knowledge Skills

> x-devsecops provides domain knowledge, not workflow execution

## Overview

x-devsecops is a **knowledge-focused** plugin. Its skills:
- Provide domain expertise (security, quality, code patterns)
- Are referenced by workflow skills (from x-workflows)
- Do not typically execute agents directly
- Supply the knowledge that workflow agents use

For comprehensive agent patterns, see [x-workflows/agents.md](https://github.com/your-org/x-workflows/blob/main/agents.md).

## Quick Reference (80/20)

| Skill Category | Agent Usage | Primary Consumer |
|----------------|-------------|------------------|
| Security | Rarely (knowledge provider) | x-review, x-implement |
| Quality | Sometimes (testing triggers) | x-review, x-troubleshoot |
| Code | Rarely (pattern reference) | x-implement, x-refactor |
| Delivery | Never (process guidance) | Human/CI orchestration |
| Operations | Never (runbook reference) | Human operators |
| Meta | Never (methodology) | Planning workflows |
| Data | Rarely (query patterns) | x-implement |

## When Knowledge Skills Suggest Agents

In rare cases, knowledge skills may suggest exploration:

```markdown
## Exploring Patterns

If using an agent-capable tool:
- Use an explorer agent to find similar patterns in your codebase
- Use a review agent to validate SOLID compliance against these principles
```

These are **suggestions**, not requirements. The skill provides knowledge; workflow tools provide execution.

## Knowledge Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    User Request                              │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│               x-workflows (Execution)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  x-review   │  │  x-fix      │  │ x-implement │  ...    │
│  │   Agent     │  │   Agent     │  │   Agent     │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
└─────────┼────────────────┼────────────────┼─────────────────┘
          │                │                │
          │    References  │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────┐
│              x-devsecops (Knowledge)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Testing    │  │  Security   │  │  Patterns   │  ...    │
│  │  Knowledge  │  │  Knowledge  │  │  Knowledge  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Integration with Workflow Agents

Workflow agents (x-workflows) consume knowledge from x-devsecops:

| Workflow Agent | x-devsecops Knowledge Used |
|----------------|----------------------------|
| Testing Agent | quality/testing/*, testing pyramid |
| Review Agent | security/*, code/code-quality/* |
| Refactor Agent | code/design-patterns/*, SOLID |
| Debug Agent | quality/debugging/*, error handling |

## Example: Testing Agent Using Knowledge

When a Testing Agent runs, it may reference:

```markdown
# From x-devsecops/skills/quality/testing/references/pyramid.md
- Unit tests: 70% (fast, isolated)
- Integration tests: 20% (component interaction)
- E2E tests: 10% (full system validation)
```

The Testing Agent **executes** tests; x-devsecops **informs** how.

## Creating Knowledge References

When adding new knowledge to x-devsecops:

1. **Focus on patterns and principles**, not execution steps
2. **Provide examples** that any tool can adapt
3. **Reference authoritative sources** (OWASP, NIST, etc.)
4. **Keep agent-agnostic** - describe what, not which tool

## Cross-References

- [x-workflows/agents.md](../x-workflows/agents.md) - Full agent pattern definitions
- [quality/testing/SKILL.md](skills/quality/testing/SKILL.md) - Testing knowledge
- [security/owasp/SKILL.md](skills/security/owasp/SKILL.md) - Security knowledge
- [code/design-patterns/SKILL.md](skills/code/design-patterns/SKILL.md) - Pattern knowledge

---

**Version**: 1.0.0
**Role**: Knowledge provider (not agent executor)
