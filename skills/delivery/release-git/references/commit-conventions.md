---
title: Commit Conventions Reference
category: delivery
type: reference
version: "1.0.0"
---

# Commit Conventions

> Part of the delivery/release-git knowledge skill

## Overview

Commit conventions standardize commit messages for readability, automated changelog generation, and semantic versioning. This reference covers the Conventional Commits specification, tooling, and best practices.

## Quick Reference (80/20)

| Type | Purpose | Version Bump |
|------|---------|-------------|
| `feat` | New feature | MINOR |
| `fix` | Bug fix | PATCH |
| `docs` | Documentation only | None |
| `refactor` | Code change (no fix/feature) | None |
| `test` | Adding/updating tests | None |
| `chore` | Maintenance (deps, config) | None |
| `perf` | Performance improvement | PATCH |
| `ci` | CI configuration changes | None |
| `style` | Formatting, whitespace | None |
| `revert` | Revert previous commit | Varies |
| `build` | Build system changes | None |

## Conventional Commits Format

```
<type>[optional scope][optional !]: <description>

[optional body]

[optional footer(s)]
```

### Structure

| Part | Required | Purpose |
|------|----------|---------|
| `type` | Yes | Category of change |
| `scope` | No | Area of codebase affected |
| `!` | No | Indicates breaking change |
| `description` | Yes | Short summary (imperative mood) |
| `body` | No | Detailed explanation |
| `footer` | No | Breaking changes, issue refs |

## Examples for Each Type

### feat - New Feature

```
feat(auth): add OAuth 2.0 login support

Implements authorization code flow for third-party integrations.
Supports Google, GitHub, and Microsoft providers.

Closes #234
```

### fix - Bug Fix

```
fix(orders): resolve race condition in concurrent updates

Multiple simultaneous order updates could cause inventory
inconsistencies. Added optimistic locking to prevent conflicts.

Fixes #278
```

### docs - Documentation

```
docs: update API authentication guide

Added examples for OAuth 2.0 token refresh flow.
```

### refactor - Code Refactoring

```
refactor(payments): extract validation into separate module

Moved payment validation logic from PaymentService to
PaymentValidator for better separation of concerns.
No behavioral changes.
```

### test - Tests

```
test(auth): add integration tests for MFA flow

Covers SMS, TOTP, and backup code verification paths.
```

### chore - Maintenance

```
chore(deps): update dependencies to latest versions

- express: 4.18.2 -> 4.19.0
- typescript: 5.3.2 -> 5.4.0
- jest: 29.7.0 -> 30.0.0
```

### perf - Performance

```
perf(search): add database index for full-text queries

Reduces p99 search latency from 450ms to 120ms.
Added GIN index on documents.content column.
```

### ci - CI Changes

```
ci: add parallel test execution to GitHub Actions

Split test suite into 4 shards for faster CI runs.
Expected build time reduction: ~60%.
```

### Breaking Changes

Two ways to indicate breaking changes:

```
# Option 1: ! after type/scope
feat(api)!: redesign authentication endpoints

BREAKING CHANGE: The /auth/login endpoint now returns a JWT token
instead of a session cookie. All clients must be updated.

Migration guide: docs/migration/auth-v2.md
```

```
# Option 2: Footer
feat(api): redesign authentication endpoints

BREAKING CHANGE: The /auth/login endpoint now returns a JWT token
instead of a session cookie. All clients must be updated.
```

### Revert

```
revert: revert "feat(auth): add OAuth 2.0 login support"

This reverts commit abc1234.

OAuth integration causing 500 errors in production.
Will re-implement after root cause analysis.
```

## Commit Message Anti-Patterns

| Anti-Pattern | Example | Better |
|-------------|---------|--------|
| Vague description | `fix: fix bug` | `fix(cart): prevent negative quantities` |
| Past tense | `feat: added search` | `feat: add search` |
| No type | `update login page` | `feat(auth): redesign login page` |
| Too long | `feat: add a new...` (80+ chars) | Keep under 72 characters |
| Multiple changes | `feat: add search and fix login` | Split into two commits |
| WIP commits | `wip` or `temp` | Squash before merge |
| Ticket only | `JIRA-123` | `feat(auth): add MFA support (JIRA-123)` |

## Scope Conventions

Define allowed scopes per project to keep them consistent:

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [
      2,
      'always',
      ['api', 'auth', 'orders', 'users', 'payments', 'config', 'deps']
    ],
    'subject-case': [2, 'always', 'lower-case'],
    'header-max-length': [2, 'always', 72]
  }
};
```

## Tooling

### commitlint

Validates commit messages against Conventional Commits:

```json
{
  "devDependencies": {
    "@commitlint/cli": "^19.0.0",
    "@commitlint/config-conventional": "^19.0.0"
  }
}
```

### husky

Git hooks manager to enforce conventions:

```bash
# Install husky
npm install --save-dev husky
npx husky init

# Add commit-msg hook
echo 'npx --no -- commitlint --edit "$1"' > .husky/commit-msg
```

### lint-staged

Run linters on staged files before commit:

```json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md}": ["prettier --write"]
  }
}
```

```bash
# pre-commit hook
echo 'npx lint-staged' > .husky/pre-commit
```

### Complete Hook Setup

```json
{
  "devDependencies": {
    "@commitlint/cli": "^19.0.0",
    "@commitlint/config-conventional": "^19.0.0",
    "husky": "^9.0.0",
    "lint-staged": "^15.0.0"
  },
  "scripts": {
    "prepare": "husky"
  }
}
```

## Integration with Release Tools

Conventional Commits enable automated versioning:

| Commit | semantic-release Action |
|--------|----------------------|
| `feat: ...` | Bump MINOR, add to Features section |
| `fix: ...` | Bump PATCH, add to Bug Fixes section |
| `feat!: ...` | Bump MAJOR, add to Breaking Changes |
| `perf: ...` | Bump PATCH, add to Performance section |
| `docs: ...` | No release |
| `chore: ...` | No release |

## Checklist

- [ ] Conventional Commits adopted by team
- [ ] commitlint configured and enforced
- [ ] husky hooks installed (commit-msg, pre-commit)
- [ ] Allowed scopes defined per project
- [ ] Team trained on commit types
- [ ] CI validates commit messages on PRs
- [ ] Breaking change notation understood
- [ ] Squash strategy defined for messy branches

## References

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [commitlint](https://commitlint.js.org/)
- [husky](https://typicode.github.io/husky/)
- [lint-staged](https://github.com/lint-staged/lint-staged)
