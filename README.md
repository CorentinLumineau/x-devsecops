# x-devsecops

Universal DevSecOps knowledge skills for AI-assisted development.

## Overview

x-devsecops provides **domain knowledge** skills - the "WHAT to know" about software development best practices. These skills are agent-agnostic and work with any skills.sh compatible AI agent.

## Architecture

x-devsecops is part of the **ccsetup 3-repository architecture** ("Swiss Watch" design):

| Repository | Role | Description |
|------------|------|-------------|
| **x-devsecops** | WHAT to know | 26 knowledge skills (domain expertise) ← *You are here* |
| **x-workflows** | HOW to work | 19 workflow skills (development processes) |
| **ccsetup** | Orchestration | Commands, agents, hooks |

For complete architectural documentation, see [ccsetup/ARCHITECTURE.md](https://github.com/clmusic/ccsetup/blob/main/ARCHITECTURE.md)

## Skills Catalog

### Code (5 skills)

| Skill | Description |
|-------|-------------|
| `code-quality` | SOLID, DRY, KISS, YAGNI principles |
| `design-patterns` | Factory, Repository, Strategy, Observer |
| `llm-optimization` | LLM-assisted development patterns |
| `error-handling` | Error handling and recovery patterns |
| `api-design` | REST and GraphQL design principles |

### Security (8 skills)

| Skill | Description |
|-------|-------------|
| `authentication` | JWT, OAuth, MFA, session management |
| `authorization` | RBAC, ABAC, ownership patterns |
| `owasp` | OWASP Top 10 vulnerability prevention |
| `input-validation` | Validation and sanitization patterns |
| `secrets` | Secrets management best practices |
| `container-security` | Docker and container security |
| `compliance` | SOC2, GDPR, HIPAA frameworks |
| `supply-chain` | Dependency security, SBOM, SCA |

### Quality (4 skills)

| Skill | Description |
|-------|-------------|
| `testing` | Testing pyramid (70/20/10), TDD patterns |
| `debugging` | Hypothesis-driven debugging methodology |
| `quality-gates` | CI quality checks and validation |
| `performance` | Performance optimization patterns |

### Delivery (4 skills)

| Skill | Description |
|-------|-------------|
| `ci-cd` | Pipeline patterns and best practices |
| `release-management` | SemVer, changelog, safe git operations |
| `infrastructure` | Terraform, Docker Compose, IaC patterns |
| `feature-flags` | Progressive rollouts, A/B testing |

### Operations (2 skills)

| Skill | Description |
|-------|-------------|
| `incident-response` | Runbooks, post-mortems, escalation |
| `monitoring` | Golden signals, SLOs, observability |

### Meta (2 skills)

| Skill | Description |
|-------|-------------|
| `analysis` | Pareto 80/20, prioritization frameworks |
| `decision-making` | ADRs, RFC patterns, evaluation matrices |

### Data (1 skill)

| Skill | Description |
|-------|-------------|
| `database` | Schema design, migrations, query optimization |

## Installation

### With skills.sh

```bash
skills install x-devsecops
```

### Manual

Clone this repository and configure your AI agent to use the skills directory.

## Compatibility

Works with:
- Claude Code
- Cursor
- Cline
- Any skills.sh compatible agent

## Usage

Skills activate automatically based on context triggers defined in each skill's frontmatter. For example, the `testing` skill activates when discussing test strategies, TDD, or coverage.

### Direct Invocation

Reference skills directly when needed:
```
Use the testing skill to review my test coverage.
```

### With Workflow Skills

x-devsecops skills provide domain knowledge that workflow skills (from x-workflows) reference during execution. For example, x-verify references the `testing` and `quality-gates` skills.

## Structure

```
x-devsecops/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── code/
│   │   ├── code-quality/
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   ├── design-patterns/
│   │   ├── llm-optimization/
│   │   ├── error-handling/
│   │   └── api-design/
│   ├── security/
│   │   ├── authentication/
│   │   ├── authorization/
│   │   ├── owasp/
│   │   ├── input-validation/
│   │   ├── secrets/
│   │   ├── container-security/
│   │   ├── compliance/
│   │   └── supply-chain/
│   ├── quality/
│   │   ├── testing/
│   │   ├── debugging/
│   │   ├── quality-gates/
│   │   └── performance/
│   ├── delivery/
│   │   ├── ci-cd/
│   │   ├── release-management/
│   │   ├── infrastructure/
│   │   └── feature-flags/
│   ├── operations/
│   │   ├── incident-response/
│   │   └── monitoring/
│   ├── meta/
│   │   ├── analysis/
│   │   └── decision-making/
│   └── data/
│       └── database/
├── LICENSE
└── README.md
```

## License

Apache-2.0

## Contributing

Contributions welcome! Please follow the skill template format in each SKILL.md file.
