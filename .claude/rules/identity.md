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
| `security/` | secure-coding, identity-access, secrets-supply-chain | OWASP Top 10, input validation, JWT, RBAC, vault, SLSA |
| `quality/` | testing, debugging-performance, observability | TDD, quality gates, profiling, OpenTelemetry, k6 |
| `code/` | code-quality, design-patterns, api-design, error-handling | SOLID, refactoring, Factory, OpenAPI, SDK design, exceptions |
| `delivery/` | ci-cd-delivery, release-git, infrastructure | GitHub Actions, blue-green/canary, SemVer, git workflows, Terraform |
| `operations/` | sre-operations | SRE, SLOs, incident response, monitoring, DR |
| `meta/` | analysis-architecture | ADRs, Pareto, microservices, event-driven, clean architecture |
| `data/` | data-persistence, messaging | PostgreSQL, MongoDB, Redis, Kafka, RabbitMQ |

---

## When to Update This Repo

| Trigger | Action |
|---------|--------|
| New domain knowledge | Create skill in `skills/{category}/{name}/` |
| Pattern update | Update `SKILL.md` or `references/*.md` |
| New reference needed | Add to `references/` directory |
| Best practice evolution | Update relevant skill with new guidance |
| Security advisory | Update security/ skills with mitigations |
