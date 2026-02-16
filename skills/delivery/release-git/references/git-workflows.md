---
title: Git Workflows Reference
category: delivery
type: reference
version: "1.0.0"
---

# Git Workflows

> Part of the delivery/release-git knowledge skill

## Overview

Git workflows define how teams collaborate on code, manage branches, and deliver changes. This reference compares trunk-based development, GitFlow, and GitHub Flow with guidance on when to use each.

## Quick Reference (80/20)

| Strategy | Best For | Branch Lifetime | Release Cadence |
|----------|----------|-----------------|-----------------|
| Trunk-Based | Continuous deployment | Hours | Continuous |
| GitHub Flow | Web apps, SaaS | Days | On merge |
| GitFlow | Versioned products | Weeks | Scheduled |

## Trunk-Based Development

### Description

All developers commit to a single branch (main/trunk). Feature flags control what users see. Short-lived branches (< 1 day) are allowed for code review via PRs.

### When to Use

- Teams practicing continuous deployment
- Strong automated test coverage
- Feature flag infrastructure available
- Small, frequent changes preferred

### Branch Protection

```yaml
# Branch protection for trunk-based
branches:
  - name: main
    protection:
      required_status_checks:
        strict: true
        contexts:
          - "ci/tests"
          - "ci/lint"
      required_pull_request_reviews:
        required_approving_review_count: 1
        dismiss_stale_reviews: true
```

### Workflow

```
main (trunk) ----------------------------------------->
  |     |     |     |     |     |
  |     |     |     |     |     +-- commit (deployed)
  |     |     |     |     +-- commit (behind flag)
  |     |     |     +-- commit (deployed)
  |     |     +-- short branch -> PR -> merge (< 1 day)
  |     +-- commit (deployed)
  +-- short branch -> PR -> merge (< 1 day)
```

### Key Rules

- All commits to main are deployable
- Branches live less than 1-2 days
- Feature flags for incomplete features
- Comprehensive automated testing
- No long-lived feature branches

## GitFlow

### Description

A structured branching model with `main`, `develop`, `feature/*`, `release/*`, and `hotfix/*` branches. Releases are planned and staged through release branches.

### When to Use

- Products with scheduled release cycles
- Multiple versions supported simultaneously
- Formal QA/release process required
- Large teams with parallel feature development

### Branch Types

| Branch | Purpose | Created From | Merges Into |
|--------|---------|-------------|-------------|
| `main` | Production releases | - | - |
| `develop` | Integration | main | release/*, main |
| `feature/*` | New features | develop | develop |
| `release/*` | Release preparation | develop | main + develop |
| `hotfix/*` | Production fixes | main | main + develop |

### Workflow

```
main -------------------------------------------------->
  |                    |                    |
  |                    +-- v1.0.0           +-- v2.1.0
  |                          |
develop --------------------------------------------------->
  |      |       |                 |        |
  |      |       +-- release/2.0 --+        |
  |      |             |                    |
  |      |             +-- bugfixes only    |
  |      |                                  |
  |      +-- feature/payments --------------+
  |
  +-- feature/user-profiles
```

### Key Rules

- Never commit directly to main
- Feature work only on feature branches
- Release branches for stabilization only (no new features)
- Hotfixes merge to both main and develop

## GitHub Flow

### Description

A simplified workflow: branch from main, make changes, open a PR, merge to main, deploy. No develop or release branches.

### When to Use

- Web applications with frequent deploys
- Small to medium teams
- Continuous deployment culture
- Simple release process (deploy on merge)

### Workflow

```
main ------------------------------------------>
  |         |              |
  |         |              +-- PR #3: merged -> deploy
  |         |
  |         +-- PR #2: merged -> deploy
  |
  +-- feature/user-auth -> PR #1: merged -> deploy
```

### Key Rules

- Main is always deployable
- Branch from main for any change
- Pull requests required for all merges
- Deploy immediately after merge to main
- No separate develop or release branches

## Strategy Comparison

| Aspect | Trunk-Based | GitFlow | GitHub Flow |
|--------|-------------|---------|-------------|
| Complexity | Low | High | Low |
| Release cadence | Continuous | Scheduled | On merge |
| Parallel releases | Via flags | Via release branches | No |
| Merge conflicts | Rare (short branches) | Frequent (long branches) | Moderate |
| CI/CD requirement | Strong | Moderate | Moderate |
| Feature flags needed | Yes | Optional | Optional |
| Best team size | Any | Large | Small-Medium |
| Rollback | Feature flag toggle | Revert release | Revert commit |

## Branch Naming Conventions

| Pattern | Example | Use |
|---------|---------|-----|
| `feature/<name>` | `feature/user-auth` | New features |
| `fix/<name>` | `fix/login-bug` | Bug fixes |
| `hotfix/<name>` | `hotfix/security-patch` | Urgent production fixes |
| `release/<version>` | `release/v2.1` | Release preparation |
| `chore/<name>` | `chore/update-deps` | Maintenance tasks |
| `docs/<name>` | `docs/api-guide` | Documentation updates |

### Naming Rules

- Use lowercase with hyphens
- Include ticket number when applicable: `feature/PROJ-123-user-auth`
- Keep names short but descriptive
- Avoid special characters except `/` and `-`

## Choosing a Strategy

```
Need continuous deployment?
  +-- Yes -> Trunk-Based Development
  +-- No
      |
      Need scheduled releases?
        +-- Yes -> GitFlow
        +-- No
            |
            Simple deploy-on-merge?
              +-- Yes -> GitHub Flow
              +-- No -> Release Branches
```

## Checklist

- [ ] Strategy matches team size and release cadence
- [ ] Branch protection rules configured
- [ ] CI/CD triggers match branch strategy
- [ ] Clear naming conventions established
- [ ] Merge strategy defined (squash/rebase/merge)
- [ ] Branch cleanup automated
- [ ] Hotfix process documented
- [ ] Team trained on chosen strategy

## References

- [Trunk Based Development](https://trunkbaseddevelopment.com/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [GitFlow](https://nvie.com/posts/a-successful-git-branching-model/)
