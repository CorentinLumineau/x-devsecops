---
title: Branching Strategies Reference
category: delivery
type: reference
version: "1.0.0"
---

# Branching Strategies

> Part of the delivery/release-management knowledge skill

## Overview

Branching strategies define how teams collaborate on code and manage releases. This reference covers common strategies and their appropriate use cases.

## Quick Reference (80/20)

| Strategy | Best For | Complexity |
|----------|----------|------------|
| Trunk-Based | Continuous deployment | Low |
| GitHub Flow | Web apps, frequent deploys | Low |
| GitFlow | Scheduled releases | High |
| Release Branches | Multiple versions supported | Medium |

## Patterns

### Pattern 1: Trunk-Based Development

**When to Use**: Teams practicing continuous deployment

**Example**:
```
main (trunk)
  │
  ├── Feature flags control releases
  │
  ├── commit: feat: add user profile
  │     └── Deployed immediately
  │
  ├── commit: feat: new checkout flow (behind flag)
  │     └── Deployed but disabled
  │
  └── commit: fix: resolve payment bug
        └── Deployed immediately

Short-lived branches (< 1 day):
  feature/quick-fix ──► main (via PR)
```

```bash
# Workflow
git checkout main
git pull origin main

# Create short-lived branch
git checkout -b feature/add-button

# Make changes and commit
git add .
git commit -m "feat: add submit button"

# Push and create PR
git push -u origin feature/add-button

# After review, merge to main
git checkout main
git pull origin main

# Delete local branch
git branch -d feature/add-button
```

**Rules**:
- All commits to main are deployable
- Branches live less than 1-2 days
- Feature flags for incomplete features
- Comprehensive automated testing

**Anti-Pattern**: Long-lived feature branches.

### Pattern 2: GitHub Flow

**When to Use**: Web applications with frequent deployments

**Example**:
```
main ────────────────────────────────────►
  │         │              │
  │         │              └── PR #3: merged
  │         │
  │         └── PR #2: merged
  │
  └── feature/user-auth ──► PR #1: merged

Branches:
  feature/user-auth
  feature/payment-integration
  fix/login-bug
  hotfix/security-patch
```

```bash
# Start new feature
git checkout main
git pull origin main
git checkout -b feature/user-dashboard

# Work and commit regularly
git add .
git commit -m "feat(dashboard): add user stats widget"
git push -u origin feature/user-dashboard

# Keep up to date with main
git fetch origin
git rebase origin/main

# Create Pull Request
gh pr create --title "feat: user dashboard" --body "Adds user statistics dashboard"

# After approval, merge
gh pr merge --squash

# Deploy happens automatically after merge
```

**Rules**:
- Main is always deployable
- Branch from main for any change
- Pull requests for all merges
- Deploy after merge to main

**Anti-Pattern**: Direct commits to main without review.

### Pattern 3: GitFlow

**When to Use**: Products with scheduled releases

**Example**:
```
main ─────────────────────────────────────────────►
  │                    │                    │
  │                    └── v1.0.0           └── v2.1.0
  │                          │
develop ──────────────────────────────────────────►
  │      │       │                 │        │
  │      │       └── release/2.0 ──┘        │
  │      │             │                    │
  │      │             └── bugfixes         │
  │      │                                  │
  │      └── feature/payments ──────────────┘
  │
  └── feature/user-profiles
```

```bash
# Initialize GitFlow
git flow init

# Start feature
git flow feature start user-profiles
# Work on feature...
git flow feature finish user-profiles

# Start release
git flow release start 1.0.0
# Bugfixes only in release branch...
git flow release finish 1.0.0

# Hotfix for production
git flow hotfix start critical-fix
# Fix the issue...
git flow hotfix finish critical-fix
```

**Branch types**:
- `main`: Production releases only
- `develop`: Integration branch
- `feature/*`: New features
- `release/*`: Release preparation
- `hotfix/*`: Production fixes

**Anti-Pattern**: Feature development in release branches.

### Pattern 4: Release Branches

**When to Use**: Supporting multiple production versions

**Example**:
```
main ──────────────────────────────────────────────►
  │           │           │
  │           │           └── v3.x development
  │           │
  │           └── release/v2 ──────────────────────►
  │                  │        │        │
  │                  │        │        └── v2.2.1 (backport)
  │                  │        └── v2.2.0
  │                  └── v2.1.0
  │
  └── release/v1 ──────────────────────────────────►
           │        │
           │        └── v1.5.1 (security fix)
           └── v1.5.0 (LTS)
```

```bash
# Create release branch from main
git checkout main
git checkout -b release/v2

# Ongoing development continues on main
git checkout main
git commit -m "feat: new feature for v3"

# Fixes can be cherry-picked to release branch
git checkout release/v2
git cherry-pick <commit-hash>

# Tag releases from release branch
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0

# Backport security fixes
git checkout release/v1
git cherry-pick <security-fix-commit>
git tag -a v1.5.1 -m "Security fix"
```

**Rules**:
- Each major version has a release branch
- Security fixes backported as needed
- Features only go to main
- Clear version support policy

**Anti-Pattern**: Maintaining too many version branches.

### Pattern 5: Environment Branches

**When to Use**: Environment-specific configurations

**Example**:
```
main ────────────────────────────────────►
  │        │        │
  │        │        └── Merged from staging
  │        │
staging ──────────────────────────────────►
  │        │        │
  │        │        └── Merged from develop
  │        │
develop ──────────────────────────────────►
  │        │
  │        └── feature/xyz merged
  │
  └── feature/xyz
```

```yaml
# Branch protection rules
# .github/settings.yml
branches:
  - name: main
    protection:
      required_status_checks:
        strict: true
        contexts:
          - "ci/tests"
          - "ci/build"
      required_pull_request_reviews:
        required_approving_review_count: 2
        dismiss_stale_reviews: true
      enforce_admins: true
      restrictions:
        users: []
        teams:
          - release-managers

  - name: staging
    protection:
      required_status_checks:
        strict: true
        contexts:
          - "ci/tests"
      required_pull_request_reviews:
        required_approving_review_count: 1

  - name: develop
    protection:
      required_status_checks:
        contexts:
          - "ci/tests"
```

**Anti-Pattern**: Manual deployments based on branch merges.

### Pattern 6: Monorepo Branching

**When to Use**: Multiple projects in single repository

**Example**:
```
main ────────────────────────────────────────►
  │
  ├── packages/api/... (changes trigger api CI)
  │
  ├── packages/web/... (changes trigger web CI)
  │
  └── packages/shared/... (changes trigger all CI)

Branches:
  feature/api-auth      (affects packages/api)
  feature/web-redesign  (affects packages/web)
  feature/shared-types  (affects all packages)
```

```yaml
# CI with path filters
# .github/workflows/ci.yml
on:
  push:
    branches: [main]
    paths:
      - 'packages/api/**'
      - 'packages/shared/**'
  pull_request:
    paths:
      - 'packages/api/**'
      - 'packages/shared/**'

jobs:
  api-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test --workspace=packages/api
```

```bash
# Conventional commits for monorepo
git commit -m "feat(api): add user endpoint"
git commit -m "fix(web): resolve routing issue"
git commit -m "chore(shared): update types"
```

**Anti-Pattern**: Single CI pipeline for all packages.

## Checklist

- [ ] Strategy matches team size and release cadence
- [ ] Branch protection rules configured
- [ ] CI/CD triggers match branch strategy
- [ ] Clear naming conventions established
- [ ] Merge strategy defined (squash/rebase/merge)
- [ ] Branch cleanup automated
- [ ] Release tagging process defined
- [ ] Hotfix process documented
- [ ] Team trained on chosen strategy
- [ ] Strategy documented in CONTRIBUTING.md

## References

- [Trunk Based Development](https://trunkbaseddevelopment.com/)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [GitFlow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Google's Branching Strategy](https://cloud.google.com/architecture/devops/devops-tech-trunk-based-development)
