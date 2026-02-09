# x-devsecops

> Agent-agnostic DevSecOps knowledge skills providing domain expertise for AI-assisted development.
> Compatible with Claude Code, Cursor, Copilot, Cline, Devin, and any AI agent.

## Project Overview

x-devsecops is a skills.sh-compatible plugin providing DevSecOps knowledge skills covering security, quality, code patterns, delivery, operations, meta, and data domains.

**Key Principle**: Knowledge skills provide WHAT to know; workflow skills (from x-workflows) provide HOW to apply.

## Quick Reference

| Category | Skills | Key Topics |
|----------|--------|------------|
| **Security** (9) | authentication, authorization, owasp, input-validation, secrets, container-security, compliance, supply-chain, api-security | JWT, RBAC, OWASP Top 10, XSS/SQLi, Vault, K8s security, SOC2/GDPR, SLSA, CORS |
| **Quality** (7) | testing, debugging, quality-gates, performance, load-testing, accessibility-wcag, observability | TDD, debugging strategies, CI gates, DB optimization, k6, WCAG, OpenTelemetry |
| **Code** (7) | code-quality, design-patterns, api-design, error-handling, llm-optimization, refactoring-patterns, sdk-design | SOLID, Factory/Strategy/Observer, OpenAPI, async errors, prompt engineering, Fowler's catalog |
| **Delivery** (5) | ci-cd, release-management, infrastructure, feature-flags, deployment-strategies | GitHub Actions, branching, Terraform/K8s, A/B testing, blue-green/canary |
| **Operations** (4) | incident-response, monitoring, sre-practices, disaster-recovery | Runbooks, post-mortems, Prometheus, SLOs, error budgets, failover |
| **Meta** (3) | analysis, decision-making, architecture-patterns | ADRs, RFC process, prioritization, microservices, event-driven |
| **Data** (4) | database, caching, nosql, message-queues | PostgreSQL, Redis, MongoDB, Kafka/RabbitMQ |

**Total**: 39 knowledge skills across 7 categories

## Usage Patterns

Skills activate automatically based on context:

| Context | Skills to Reference |
|---------|---------------------|
| Writing code | code-quality, design-patterns, error-handling |
| Security review | owasp, input-validation, authentication, authorization |
| Testing | testing, debugging, quality-gates |
| Deployment | ci-cd, release-management, infrastructure |
| Production issues | incident-response, monitoring, sre-practices |
| Technical decisions | analysis, decision-making, architecture-patterns |
| Data layer | database, caching, nosql, message-queues |

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

---

**Version**: 0.2.1
**Compatibility**: skills.sh, Claude Code, Cursor, Copilot, Cline, Devin
