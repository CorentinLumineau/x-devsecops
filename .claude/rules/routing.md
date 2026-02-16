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
├─ Topic about vulnerabilities, input validation, CORS, security headers?
│  └─ → security/secure-coding
│
├─ Topic about authentication, authorization, compliance, access control?
│  └─ → security/identity-access
│
├─ Topic about secrets, supply chain, containers, SBOM?
│  └─ → security/secrets-supply-chain
│
├─ Topic about testing, TDD, quality gates, coverage?
│  └─ → quality/testing
│
├─ Topic about debugging, profiling, performance optimization?
│  └─ → quality/debugging-performance
│
├─ Topic about logging, tracing, metrics, load testing?
│  └─ → quality/observability
│
├─ Topic about SOLID, DRY, refactoring, code review?
│  └─ → code/code-quality
│
├─ Topic about design patterns (Factory, Strategy, Observer)?
│  └─ → code/design-patterns
│
├─ Topic about REST, GraphQL, SDK design, OpenAPI?
│  └─ → code/api-design
│
├─ Topic about error handling, exceptions, recovery?
│  └─ → code/error-handling
│
├─ Topic about CI/CD pipelines, deployment strategies?
│  └─ → delivery/ci-cd-delivery
│
├─ Topic about git workflows, releases, versioning, commits?
│  └─ → delivery/release-git
│
├─ Topic about infrastructure, IaC, feature flags?
│  └─ → delivery/infrastructure
│
├─ Topic about SRE, incidents, monitoring, disaster recovery?
│  └─ → operations/sre-operations
│
├─ Topic about decisions, analysis, architecture patterns?
│  └─ → meta/analysis-architecture
│
├─ Topic about databases, SQL, NoSQL, caching?
│  └─ → data/data-persistence
│
└─ Topic about message queues, event-driven, Kafka, RabbitMQ?
   └─ → data/messaging
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
