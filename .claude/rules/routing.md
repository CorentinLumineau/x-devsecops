# x-devsecops Routing Rules

## What Does NOT Belong Here

| Component | Correct Repository | Why |
|-----------|-------------------|-----|
| Workflow skills (x-*) | → `x-workflows/skills/` | Execution steps, not knowledge |
| Commands (/commit) | → `ccsetup/commands/` | Claude Code specific |
| Agents (x-tester) | → `ccsetup/agents/` | Orchestration layer |
| Execution steps | → `x-workflows` | HOW vs WHAT distinction |
| Plugin configuration | → `ccsetup/.claude-plugin/` | Plugin metadata |

---

## Category Decision Tree

```
New knowledge component needed?
│
├─ Topic about authentication, authorization, vulnerabilities, secrets?
│  └─ → security/
│
├─ Topic about testing, debugging, performance, quality checks?
│  └─ → quality/
│
├─ Topic about SOLID, design patterns, APIs, error handling, code style?
│  └─ → code/
│
├─ Topic about CI/CD, releases, infrastructure, feature flags?
│  └─ → delivery/
│
├─ Topic about incidents, monitoring, runbooks, alerting?
│  └─ → operations/
│
├─ Topic about decisions, analysis, prioritization, ADRs?
│  └─ → meta/
│
└─ Topic about databases, SQL, migrations, data modeling?
   └─ → data/
```

---

## Knowledge vs Execution Distinction

| Knowledge (x-devsecops) | Execution (x-workflows) |
|-------------------------|------------------------|
| WHAT is OWASP Top 10? | HOW to run security scan |
| WHAT is TDD? | HOW to implement feature with TDD |
| WHAT is SOLID? | HOW to refactor for SOLID |
| WHAT are JWT best practices? | HOW to implement auth flow |

**Rule**: If it contains action steps, it belongs in x-workflows.
