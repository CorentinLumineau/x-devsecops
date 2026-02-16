# x-devsecops

> Agent-agnostic DevSecOps knowledge skills providing domain expertise for AI-assisted development.
> Compatible with Claude Code, Cursor, Copilot, Cline, Devin, and any AI agent.

## Project Overview

x-devsecops is a skills.sh-compatible plugin providing DevSecOps knowledge skills covering security, quality, code patterns, delivery, operations, meta, and data domains.

**Key Principle**: Knowledge skills provide WHAT to know; workflow skills (from x-workflows) provide HOW to apply.

## Quick Reference

| Category | Skills | Key Topics |
|----------|--------|------------|
| **Security** (3) | secure-coding, identity-access, secrets-supply-chain | OWASP Top 10, input validation, CORS, JWT/OAuth/MFA, RBAC/ABAC, SOC2/GDPR, Vault, SLSA/SBOM, container hardening |
| **Code** (4) | code-quality, design-patterns, api-design, error-handling | SOLID/DRY/KISS, refactoring catalog, code review, Factory/Strategy/Observer, REST/GraphQL, SDK design, async errors |
| **Quality** (3) | testing, debugging-performance, observability | TDD, testing pyramid, quality gates, systematic debugging, profiling, optimization, OpenTelemetry, k6 |
| **Delivery** (3) | ci-cd-delivery, release-git, infrastructure | GitHub Actions, blue-green/canary, SemVer, git workflows, commit conventions, Terraform/K8s, feature flags |
| **Operations** (1) | sre-operations | SRE principles, SLOs, error budgets, incident response, monitoring, golden signals, disaster recovery |
| **Meta** (1) | analysis-architecture | Pareto 80/20, ADRs/RFCs, trade-off analysis, microservices, event-driven, clean architecture |
| **Data** (2) | data-persistence, messaging | PostgreSQL, MongoDB, Redis, SQL/NoSQL decision tree, Kafka, RabbitMQ, event-driven patterns |

**Total**: 17 knowledge skills across 7 categories

## Usage Patterns

Skills activate automatically based on context:

| Context | Skills to Reference |
|---------|---------------------|
| Writing code | code-quality, design-patterns, error-handling |
| Security review | secure-coding, identity-access, secrets-supply-chain |
| Testing | testing, debugging-performance |
| Deployment | ci-cd-delivery, release-git, infrastructure |
| Production issues | sre-operations, observability |
| Technical decisions | analysis-architecture |
| Data layer | data-persistence, messaging |

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

---

**Version**: 2.0.0
**Compatibility**: skills.sh, Claude Code, Cursor, Copilot, Cline, Devin
