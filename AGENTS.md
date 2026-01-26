# x-devsecops

> Agent-agnostic DevSecOps knowledge skills providing domain expertise for AI-assisted development.
> Compatible with Claude Code, Cursor, Copilot, Cline, Devin, and any AI agent.

## Project Overview

x-devsecops is a skills.sh-compatible plugin providing DevSecOps knowledge skills covering security, quality, code patterns, delivery, operations, and data domains.

**Key Principle**: Knowledge skills provide WHAT to know; workflow skills (from x-workflows) provide HOW to apply.

## Quick Reference

| Category | Skills | Key Topics |
|----------|--------|------------|
| **Security** | authentication, authorization, owasp, input-validation, secrets, container-security, compliance, supply-chain | JWT, RBAC, OWASP Top 10, XSS/SQLi, Vault, K8s security, SOC2/GDPR, SLSA |
| **Quality** | testing, debugging, quality-gates, performance | TDD, debugging strategies, CI gates, DB optimization |
| **Code** | code-quality, design-patterns, llm-optimization, error-handling, api-design | SOLID, Factory/Strategy/Observer, prompt engineering, async errors, OpenAPI |
| **Delivery** | ci-cd, release-management, infrastructure, feature-flags | GitHub Actions, branching strategies, Terraform/K8s, A/B testing |
| **Operations** | incident-response, monitoring | Runbooks, post-mortems, Prometheus, alerting |
| **Meta** | analysis, decision-making | ADRs, RFC process, prioritization |
| **Data** | database | PostgreSQL, migrations, tuning |

## Usage Patterns

Skills activate automatically based on context:

| Context | Skills to Reference |
|---------|---------------------|
| Writing code | code-quality, design-patterns, error-handling |
| Security review | owasp, input-validation, authentication, authorization |
| Testing | testing, debugging, quality-gates |
| Deployment | ci-cd, release-management, infrastructure |
| Production issues | incident-response, monitoring |
| Technical decisions | analysis, decision-making |

## Build & Test

No build required - pure markdown documentation.

```bash
# Validate skill structure
for cat in code data delivery meta operations quality security; do
  echo "$cat: $(ls -d skills/$cat/*/ 2>/dev/null | wc -l) skills"
done

# Check reference files
find skills -path "*/references/*.md" | wc -l  # Should be 74+

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

### SKILL.md Format (Knowledge Skills)
```markdown
---
title: {Title}
category: {category}
type: knowledge
---

# {Skill Name}

> {Brief description}

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| {pattern} | {condition} |

## Deep Dive

See references/:
- {topic}.md - {description}

## Cross-References

Related skills:
- @skills/{category}/{related}
```

### Reference File Format
```markdown
---
title: {Title}
category: {skill-category}
type: reference
---

# {Title}

## Overview
{Description}

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| {key pattern} | {common scenario} |

## Patterns

### Pattern 1: {Name}
**When to Use**: {Conditions}
**Example**: {Code with language tag}
**Anti-Pattern**: {What NOT to do}

## Checklist
- [ ] {Verification items}

## References
- {External links}
```

## Security Considerations

This repository contains security documentation. Critical rules:

- **Never include real secrets or credentials** in examples
- Use placeholder values like `<API_KEY>`, `your-secret-here`, `${SECRET}`
- **OWASP examples show prevention**, not exploitation techniques
- External security links must point to authoritative sources (OWASP, NIST, CIS)
- All code examples must demonstrate secure practices

## Domain Knowledge Map

```
x-devsecops/skills/
├── security/        # Security-first development
│   ├── authentication/   # JWT, OAuth, MFA
│   ├── authorization/    # RBAC, ABAC
│   ├── owasp/           # OWASP Top 10
│   ├── input-validation/ # XSS, SQLi prevention
│   ├── secrets/         # Vault, rotation
│   ├── container-security/  # K8s, scanning
│   ├── compliance/      # SOC2, GDPR
│   └── supply-chain/    # SLSA, SBOM
├── quality/         # Quality engineering
│   ├── testing/         # TDD, coverage
│   ├── debugging/       # Strategies, markers
│   ├── quality-gates/   # CI gates, pre-commit
│   └── performance/     # DB, caching, web
├── code/            # Code craftsmanship
│   ├── code-quality/    # SOLID, anti-patterns
│   ├── design-patterns/ # Creational, Structural, Behavioral
│   ├── api-design/      # OpenAPI, GraphQL, rate limiting
│   ├── error-handling/  # Async, API errors
│   └── llm-optimization/ # Prompting, context
├── delivery/        # Continuous delivery
│   ├── ci-cd/           # Actions, GitLab CI
│   ├── infrastructure/  # Terraform, K8s, Docker
│   ├── release-management/ # Branching, changelog
│   └── feature-flags/   # A/B testing, cleanup
├── operations/      # Production operations
│   ├── incident-response/  # Runbooks, post-mortems
│   └── monitoring/         # Prometheus, alerting
├── meta/            # Meta practices
│   ├── analysis/        # ADRs, prioritization
│   └── decision-making/ # RFCs, process
└── data/            # Data management
    └── database/        # PostgreSQL, migrations
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

---

**Version**: 0.2.0
**Compatibility**: skills.sh, Claude Code, Cursor, Copilot, Cline, Devin
