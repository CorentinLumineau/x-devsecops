---
name: ci-cd
description: CI/CD pipeline patterns and automation. GitHub Actions, GitLab CI, build automation.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---

# CI/CD

Continuous Integration and Continuous Deployment patterns.

## CI/CD Principles

| Principle | Description |
|-----------|-------------|
| Automate everything | Build, test, deploy |
| Fast feedback | Fail fast, notify quickly |
| Build once | Same artifact through all stages |
| Infrastructure as code | Reproducible environments |

## Pipeline Stages

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Build   │ →  │   Test   │ →  │  Stage   │ →  │  Deploy  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

| Stage | Purpose | Fail Fast |
|-------|---------|-----------|
| Build | Compile, bundle | Yes |
| Test | Unit, integration | Yes |
| Stage | Deploy to staging | No |
| Deploy | Production release | Manual gate |

## GitHub Actions Structure

```yaml
name: CI/CD
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm run lint
      - run: npm run test
      - run: npm run build
```

## Common Jobs

| Job | Purpose | When |
|-----|---------|------|
| lint | Code style | Every push |
| test | Unit tests | Every push |
| build | Create artifact | Every push |
| security | Vulnerability scan | Every push |
| deploy-staging | Staging deployment | PR merge |
| deploy-prod | Production release | Manual/tag |

## Best Practices

| Practice | Benefit |
|----------|---------|
| Caching dependencies | Faster builds |
| Parallel jobs | Reduced time |
| Matrix builds | Multi-version testing |
| Artifact storage | Consistent deployments |
| Secret management | Secure credentials |

## Pipeline Optimizations

| Optimization | Implementation |
|--------------|----------------|
| Cache | `actions/cache` for node_modules |
| Parallelism | Independent jobs run together |
| Conditional | Skip jobs based on file changes |
| Incremental | Only test affected packages |

## Security in CI/CD

| Control | Implementation |
|---------|----------------|
| Secret scanning | Never commit secrets |
| Dependency audit | `npm audit` in pipeline |
| SAST | Code analysis tools |
| Image scanning | Container vulnerability scan |
| Signed commits | Verify author identity |

## Checklist

- [ ] Pipeline runs on every push
- [ ] Build fails fast on errors
- [ ] Tests run before deployment
- [ ] Secrets stored securely
- [ ] Dependencies cached
- [ ] Security scanning enabled
- [ ] Deployment requires approval
- [ ] Rollback strategy exists

## When to Load References

- **For GitHub Actions**: See `references/github-actions.md`
- **For GitLab CI**: See `references/gitlab-ci.md`
- **For deployment strategies**: See `references/deployment.md`
