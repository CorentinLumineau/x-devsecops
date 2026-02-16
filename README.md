# x-devsecops

Universal DevSecOps knowledge skills for AI-assisted development.

## Overview

x-devsecops provides **domain knowledge** skills - the "WHAT to know" about software development best practices. These skills are agent-agnostic and work with any skills.sh compatible AI agent.

## Architecture

x-devsecops is part of the **ccsetup 3-repository architecture** ("Swiss Watch" design):

| Repository | Role | Description |
|------------|------|-------------|
| **x-devsecops** | WHAT to know | 17 knowledge skills (domain expertise) ← *You are here* |
| **x-workflows** | HOW to work | 25 workflow skills (development processes) |
| **ccsetup** | Orchestration | Commands, agents, hooks |

For complete architectural documentation, see [ccsetup/ARCHITECTURE.md](https://github.com/CorentinLumineau/ccsetup/blob/main/ARCHITECTURE.md)

## Skills Catalog

### Security (3 skills)

| Skill | Description |
|-------|-------------|
| `secure-coding` | OWASP Top 10, input validation, API security, CORS, security headers |
| `identity-access` | JWT/OAuth/MFA authentication, RBAC/ABAC authorization, SOC2/GDPR compliance |
| `secrets-supply-chain` | Secrets management, vault/rotation, SLSA/SBOM, container security |

### Code (4 skills)

| Skill | Description |
|-------|-------------|
| `code-quality` | SOLID, DRY, KISS, YAGNI principles, refactoring catalog, code review |
| `design-patterns` | Factory, Repository, Strategy, Observer (GoF patterns) |
| `api-design` | REST and GraphQL design, SDK patterns, OpenAPI codegen |
| `error-handling` | Error handling, exception management, recovery patterns |

### Quality (3 skills)

| Skill | Description |
|-------|-------------|
| `testing` | Testing pyramid (70/20/10), TDD patterns, quality gates |
| `debugging-performance` | Systematic debugging, profiling, optimization patterns |
| `observability` | Distributed tracing, structured logging, OpenTelemetry, load testing |

### Delivery (3 skills)

| Skill | Description |
|-------|-------------|
| `ci-cd-delivery` | Pipeline patterns, GitHub Actions, blue-green/canary deployments |
| `release-git` | SemVer, changelog, git workflows, commit conventions, PR practices |
| `infrastructure` | Terraform, Docker, Kubernetes, feature flags, A/B testing |

### Operations (1 skill)

| Skill | Description |
|-------|-------------|
| `sre-operations` | SRE principles, SLOs, error budgets, incident response, monitoring, DR |

### Meta (1 skill)

| Skill | Description |
|-------|-------------|
| `analysis-architecture` | Pareto 80/20, ADRs/RFCs, microservices, event-driven, clean architecture |

### Data (2 skills)

| Skill | Description |
|-------|-------------|
| `data-persistence` | PostgreSQL, MongoDB, Redis, SQL/NoSQL decision tree, caching patterns |
| `messaging` | Kafka, RabbitMQ, event-driven architecture patterns |

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

x-devsecops skills provide domain knowledge that workflow skills (from x-workflows) reference during execution. For example, x-verify references the `testing` skill for quality gates.

## Structure

```
x-devsecops/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── security/
│   │   ├── secure-coding/
│   │   ├── identity-access/
│   │   └── secrets-supply-chain/
│   ├── code/
│   │   ├── code-quality/
│   │   ├── design-patterns/
│   │   ├── api-design/
│   │   └── error-handling/
│   ├── quality/
│   │   ├── testing/
│   │   ├── debugging-performance/
│   │   └── observability/
│   ├── delivery/
│   │   ├── ci-cd-delivery/
│   │   ├── release-git/
│   │   └── infrastructure/
│   ├── operations/
│   │   └── sre-operations/
│   ├── meta/
│   │   └── analysis-architecture/
│   └── data/
│       ├── data-persistence/
│       └── messaging/
├── LICENSE
└── README.md
```

## Integration with x-workflows

Knowledge skills are referenced by workflow skills:

| Workflow Skill | Knowledge Skills Used |
|----------------|----------------------|
| x-verify | testing |
| x-implement | code-quality, design-patterns |
| x-review | secure-coding, code-quality |
| x-troubleshoot | debugging-performance, sre-operations |
| x-docs | api-design |

See [AGENT-USAGE.md](AGENT-USAGE.md) for detailed workflow integration patterns.

## Build & Test

No build required - pure markdown documentation.

```bash
# Validate skill structure
for cat in code data delivery meta operations quality security; do
  echo "$cat: $(ls -d skills/$cat/*/ 2>/dev/null | wc -l) skills"
done

# Check reference files
find skills -path "*/references/*.md" | wc -l  # Should be 101

# Validate no empty files
find skills -name "*.md" -empty
```

## Skill Structure Convention

Knowledge skills follow this structure:
```
skills/{category}/{skill-name}/
├── SKILL.md           # Main skill file with quick reference
└── references/        # Deep-dive documentation
    ├── {topic}.md
    └── ...
```

**Categories**: code, data, delivery, meta, operations, quality, security

## Security Considerations

This repository contains security documentation. Critical rules:

- **Never include real secrets or credentials** in examples
- Use placeholder values like `<API_KEY>`, `your-secret-here`, `${SECRET}`
- **OWASP examples show prevention**, not exploitation techniques
- External security links must point to authoritative sources (OWASP, NIST, CIS)
- All code examples must demonstrate secure practices

## Commit Message Format

```
{type}({scope}): {description}

Types: feat, fix, docs, refactor
Scopes: category/skill-name or category
```

Example: `feat(security/secure-coding): add injection prevention reference`

## Testing Instructions

When modifying knowledge skills:
1. Verify YAML frontmatter is valid
2. Ensure Quick Reference (80/20) table exists
3. Check all referenced files exist in `references/`
4. Validate external links are HTTPS and authoritative
5. Verify no real credentials in examples

## License

Apache-2.0

## Contributing

Contributions welcome! Please follow the skill template format in each SKILL.md file.

---

**Version**: 1.0.0
**Compatibility**: skills.sh, Claude Code, Cursor, Copilot, Cline, Devin
