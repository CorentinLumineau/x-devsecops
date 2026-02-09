# x-devsecops

Universal DevSecOps knowledge skills for AI-assisted development.

## Overview

x-devsecops provides **domain knowledge** skills - the "WHAT to know" about software development best practices. These skills are agent-agnostic and work with any skills.sh compatible AI agent.

## Architecture

x-devsecops is part of the **ccsetup 3-repository architecture** ("Swiss Watch" design):

| Repository | Role | Description |
|------------|------|-------------|
| **x-devsecops** | WHAT to know | 39 knowledge skills (domain expertise) ← *You are here* |
| **x-workflows** | HOW to work | 25 workflow skills (development processes) |
| **ccsetup** | Orchestration | Commands, agents, hooks |

For complete architectural documentation, see [ccsetup/ARCHITECTURE.md](https://github.com/CorentinLumineau/ccsetup/blob/main/ARCHITECTURE.md)

## Skills Catalog

### Code (7 skills)

| Skill | Description |
|-------|-------------|
| `code-quality` | SOLID, DRY, KISS, YAGNI principles |
| `design-patterns` | Factory, Repository, Strategy, Observer |
| `api-design` | REST and GraphQL design principles |
| `error-handling` | Error handling and recovery patterns |
| `llm-optimization` | LLM-assisted development patterns |
| `refactoring-patterns` | Fowler's refactoring catalog and safe techniques |
| `sdk-design` | SDK and API client design, OpenAPI codegen |

### Security (9 skills)

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
| `api-security` | API auth patterns, CORS, rate limiting |

### Quality (7 skills)

| Skill | Description |
|-------|-------------|
| `testing` | Testing pyramid (70/20/10), TDD patterns |
| `debugging` | Hypothesis-driven debugging methodology |
| `quality-gates` | CI quality checks and validation |
| `performance` | Performance optimization patterns |
| `load-testing` | Load, stress, and soak testing with k6 |
| `accessibility-wcag` | WCAG 2.1/2.2 compliance and ARIA patterns |
| `observability` | Distributed tracing, structured logging, OpenTelemetry |

### Delivery (5 skills)

| Skill | Description |
|-------|-------------|
| `ci-cd` | Pipeline patterns and best practices |
| `release-management` | SemVer, changelog, safe git operations |
| `infrastructure` | Terraform, Docker Compose, IaC patterns |
| `feature-flags` | Progressive rollouts, A/B testing |
| `deployment-strategies` | Blue-green, canary, rolling deployments |

### Operations (4 skills)

| Skill | Description |
|-------|-------------|
| `incident-response` | Runbooks, post-mortems, escalation |
| `monitoring` | Golden signals, SLOs, observability |
| `sre-practices` | SLO framework, error budgets, toil reduction |
| `disaster-recovery` | RTO/RPO planning, backup strategies, failover |

### Meta (3 skills)

| Skill | Description |
|-------|-------------|
| `analysis` | Pareto 80/20, prioritization frameworks |
| `decision-making` | ADRs, RFC patterns, evaluation matrices |
| `architecture-patterns` | Microservices, event-driven, clean architecture |

### Data (4 skills)

| Skill | Description |
|-------|-------------|
| `database` | Schema design, migrations, query optimization |
| `caching` | Redis patterns, cache invalidation strategies |
| `nosql` | MongoDB, DynamoDB, document modeling |
| `message-queues` | Kafka, RabbitMQ, event-driven architecture |

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
│   │   ├── design-patterns/
│   │   ├── api-design/
│   │   ├── error-handling/
│   │   ├── llm-optimization/
│   │   ├── refactoring-patterns/
│   │   └── sdk-design/
│   ├── security/
│   │   ├── authentication/
│   │   ├── authorization/
│   │   ├── owasp/
│   │   ├── input-validation/
│   │   ├── secrets/
│   │   ├── container-security/
│   │   ├── compliance/
│   │   ├── supply-chain/
│   │   └── api-security/
│   ├── quality/
│   │   ├── testing/
│   │   ├── debugging/
│   │   ├── quality-gates/
│   │   ├── performance/
│   │   ├── load-testing/
│   │   ├── accessibility-wcag/
│   │   └── observability/
│   ├── delivery/
│   │   ├── ci-cd/
│   │   ├── release-management/
│   │   ├── infrastructure/
│   │   ├── feature-flags/
│   │   └── deployment-strategies/
│   ├── operations/
│   │   ├── incident-response/
│   │   ├── monitoring/
│   │   ├── sre-practices/
│   │   └── disaster-recovery/
│   ├── meta/
│   │   ├── analysis/
│   │   ├── decision-making/
│   │   └── architecture-patterns/
│   └── data/
│       ├── database/
│       ├── caching/
│       ├── nosql/
│       └── message-queues/
├── LICENSE
└── README.md
```

## Integration with x-workflows

Knowledge skills are referenced by workflow skills:

| Workflow Skill | Knowledge Skills Used |
|----------------|----------------------|
| x-verify | testing, quality-gates |
| x-implement | code-quality, design-patterns |
| x-review | owasp, code-quality |
| x-troubleshoot | debugging, incident-response |
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
find skills -path "*/references/*.md" | wc -l  # Should be 95+

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

Example: `feat(security/owasp): add injection prevention reference`

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

**Version**: 0.2.1
**Compatibility**: skills.sh, Claude Code, Cursor, Copilot, Cline, Devin
