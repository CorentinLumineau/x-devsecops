# x-devsecops Repository Identity

## Repository Identity

| Attribute | Value |
|-----------|-------|
| **Role** | Knowledge Layer ("WHAT" to know) |
| **Content** | Domain expertise skills (security, quality, code, delivery, etc.) |
| **Compatibility** | Agent-agnostic (Claude Code, Cursor, Cline, etc.) |

---

## What Belongs Here

| Category | Skills | Example Topics |
|----------|--------|----------------|
| `security/` | authentication, owasp, secrets, authorization, etc. | JWT, RBAC, OWASP Top 10, vault |
| `quality/` | testing, debugging, performance, quality-gates | TDD, coverage, profiling, validation |
| `code/` | code-quality, design-patterns, api-design, error-handling | SOLID, Factory, OpenAPI, exceptions |
| `delivery/` | ci-cd, release-management, infrastructure, feature-flags | GitHub Actions, SemVer, Terraform |
| `operations/` | incident-response, monitoring | Runbooks, Prometheus, alerting |
| `meta/` | analysis, decision-making | ADRs, Pareto, prioritization |
| `data/` | database | PostgreSQL, migrations, indexing |

---

## When to Update This Repo

| Trigger | Action |
|---------|--------|
| New domain knowledge | Create skill in `skills/{category}/{name}/` |
| Pattern update | Update `SKILL.md` or `references/*.md` |
| New reference needed | Add to `references/` directory |
| Best practice evolution | Update relevant skill with new guidance |
| Security advisory | Update security/ skills with mitigations |
