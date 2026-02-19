---
name: ci-cd-delivery
description: Use when setting up or optimizing CI/CD pipelines and deployment automation. Covers pipeline patterns, deployment strategies, and release automation for safe continuous delivery.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---

# CI/CD & Delivery

CI/CD pipeline patterns and deployment strategies for safe, zero-downtime releases.

## Quick Reference (80/20)

| Topic | Key Concepts |
|-------|-------------|
| **Pipeline stages** | Build, test, stage, deploy (fail fast) |
| **GitHub Actions** | Workflows, jobs, steps, matrix builds, reusable workflows |
| **GitLab CI** | Stages, includes, rules, environments, dynamic pipelines |
| **Blue/green** | Two environments, instant rollback, 2x resources |
| **Canary** | Gradual traffic shift (5% -> 25% -> 50% -> 100%), metrics-based promotion |
| **Rolling** | Incremental instance replacement, maxSurge/maxUnavailable |
| **Rollback** | Feature flag > config > blue/green switch > redeploy (fastest first) |
| **Pipeline security** | Secret scanning, SAST, dependency audit, signed commits, OIDC |

## CI/CD Principles

| Principle | Description |
|-----------|-------------|
| Automate everything | Build, test, deploy |
| Fast feedback | Fail fast, notify quickly |
| Build once | Same artifact through all stages |
| Infrastructure as code | Reproducible environments |

## Pipeline Stages

```
+---------+    +--------+    +--------+    +--------+
|  Build  | -> |  Test  | -> |  Stage | -> | Deploy |
+---------+    +--------+    +--------+    +--------+
```

| Stage | Purpose | Fail Fast |
|-------|---------|-----------|
| Build | Compile, bundle | Yes |
| Test | Unit, integration, security | Yes |
| Stage | Deploy to staging | No |
| Deploy | Production release | Manual gate |

## Deployment Strategy Comparison

| Feature | Rolling | Blue/Green | Canary |
|---------|---------|-----------|--------|
| Zero downtime | Yes | Yes | Yes |
| Rollback speed | Slow (re-roll) | Instant (swap) | Fast (route 0%) |
| Resource cost | 1x | 2x | 1x + canary |
| Mixed versions | During rollout | Never | During rollout |
| Database changes | Complex | Complex | Complex |
| Smoke testing | Limited | Full env | Partial traffic |

## Rolling Update

Replace instances incrementally:

```yaml
# Kubernetes rolling update
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
```

**When to use**: Stateless services, non-breaking changes
**When to avoid**: Breaking API changes, database schema changes

## Blue/Green Deployment

Two identical environments; switch traffic at once:

```
         +--- Blue (v1) <- Active
Router --+
         +--- Green (v2) <- Staging

After verification:

         +--- Blue (v1) <- Idle
Router --+
         +--- Green (v2) <- Active
```

## Canary Release

Route small traffic percentage to new version, gradually increase:

```
Step 1:  v1 (95%)    v2 (5%)  <- Canary
Step 2:  v1 (75%)    v2 (25%)
Step 3:  v1 (50%)    v2 (50%)
Step 4:  v1 (0%)     v2 (100%)
```

**Promotion criteria**:
- Error rate <= baseline + 0.1%
- p99 latency <= baseline + 10%
- No increase in 5xx responses
- Business metrics stable

## Rollback Strategy

| Strategy | Rollback Method | Speed |
|----------|----------------|-------|
| Feature flag | Toggle flag off | Instant |
| Blue/Green | Switch router back | Seconds |
| Canary | Route 0% to canary | Seconds |
| Rolling | Re-deploy previous version | Minutes |

## Pipeline Security

| Control | Implementation |
|---------|----------------|
| Secret scanning | Never commit secrets |
| Dependency audit | `npm audit` / `snyk` in pipeline |
| SAST | Code analysis tools |
| Image scanning | Container vulnerability scan |
| Signed commits | Verify author identity |
| OIDC | Short-lived credentials, no long-lived keys |

## Pipeline Optimizations

| Optimization | Implementation |
|--------------|----------------|
| Cache | `actions/cache` for dependencies |
| Parallelism | Independent jobs run together |
| Conditional | Skip jobs based on file changes |
| Matrix builds | Multi-version/multi-OS testing |
| Reusable workflows | Share pipelines across repos |

## Database Migration Safety

All deployment strategies require backward-compatible database changes:

```
Deploy v2 (adds column) -> Both v1 and v2 work
Migrate traffic to v2   -> Confirm v2 stable
Remove v1 code          -> Clean up old column later
```

**Rule**: Expand-then-contract. Never remove or rename in the same deploy.

## Checklist

- [ ] Pipeline runs on every push
- [ ] Build fails fast on errors
- [ ] Tests run before deployment
- [ ] Secrets stored securely (OIDC preferred)
- [ ] Dependencies cached
- [ ] Security scanning enabled
- [ ] Deployment strategy matches risk tolerance
- [ ] Health checks configured
- [ ] Rollback procedure documented and tested
- [ ] Database migrations are backward-compatible
- [ ] Monitoring alerts detect deployment regression

## When to Load References

- **For GitHub Actions patterns**: See `references/github-actions.md`
- **For GitLab CI patterns**: See `references/gitlab-ci.md`
- **For deployment pipeline patterns**: See `references/deployment.md`
- **For blue/green details**: See `references/blue-green.md`
- **For canary patterns**: See `references/canary-releases.md`
- **For rollback patterns**: See `references/rollback-patterns.md`

## Related Skills

- **Release & Git**: See `delivery/release-git` for versioning, branching, commit conventions
- **Infrastructure**: See `delivery/infrastructure` for IaC, containers, feature flags
