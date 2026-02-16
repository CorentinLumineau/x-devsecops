---
title: Changelog Management Reference
category: delivery
type: reference
version: "1.0.0"
---

# Changelog Management

> Part of the delivery/release-management knowledge skill

## Overview

Changelogs communicate changes to users and developers. This reference covers changelog formats, automation, and best practices for maintaining release notes.

## Quick Reference (80/20)

| Section | Content |
|---------|---------|
| Added | New features |
| Changed | Modified features |
| Deprecated | Soon-to-be-removed features |
| Removed | Removed features |
| Fixed | Bug fixes |
| Security | Security patches |

## Patterns

### Pattern 1: Keep a Changelog Format

**When to Use**: Standard human-readable changelog

**Example**:
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- User profile customization options
- Dark mode support

### Changed
- Improved performance of search queries

## [2.1.0] - 2024-01-15

### Added
- New payment gateway integration (#234)
- Export functionality for reports (#256)
- API rate limiting with configurable thresholds

### Changed
- Updated authentication flow to use OAuth 2.0
- Improved error messages for validation failures
- Database queries optimized for large datasets

### Deprecated
- Legacy XML export format (use JSON instead)

### Fixed
- Race condition in order processing (#278)
- Memory leak in long-running tasks (#291)
- Incorrect timezone handling in scheduled jobs

### Security
- Updated dependencies to patch CVE-2024-1234
- Added CSRF protection to all forms

## [2.0.0] - 2024-01-01

### Added
- Complete API redesign with v2 endpoints
- GraphQL support alongside REST

### Changed
- **BREAKING**: Authentication tokens now expire after 24 hours
- **BREAKING**: Renamed `/api/users` to `/api/v2/users`

### Removed
- **BREAKING**: Removed deprecated v1 API endpoints
- Legacy database migration scripts

## [1.5.0] - 2023-12-15
...

[Unreleased]: https://github.com/user/repo/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/user/repo/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/user/repo/compare/v1.5.0...v2.0.0
[1.5.0]: https://github.com/user/repo/releases/tag/v1.5.0
```

**Anti-Pattern**: Git log dumps instead of curated changelogs.

### Pattern 2: Conventional Commits

**When to Use**: Automated changelog generation

**Example**:
```bash
# Commit message format
# <type>(<scope>): <description>
#
# [optional body]
#
# [optional footer(s)]

# Feature
git commit -m "feat(auth): add OAuth 2.0 support

Implements OAuth 2.0 authorization code flow for third-party integrations.

Closes #234"

# Bug fix
git commit -m "fix(orders): resolve race condition in processing

Multiple concurrent order updates could cause inventory inconsistencies.

Fixes #278"

# Breaking change
git commit -m "feat(api)!: redesign authentication endpoints

BREAKING CHANGE: The /auth/login endpoint now returns a JWT token
instead of a session cookie. All clients must be updated.

Migration guide: docs/migration/auth-v2.md"

# Types:
# feat:     New feature
# fix:      Bug fix
# docs:     Documentation only
# style:    Code style (formatting, semicolons)
# refactor: Code change that neither fixes a bug nor adds a feature
# perf:     Performance improvement
# test:     Adding or updating tests
# build:    Build system or external dependencies
# ci:       CI configuration
# chore:    Other changes that don't modify src or test files
# revert:   Reverts a previous commit
```

```json
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'build',
        'ci',
        'chore',
        'revert'
      ]
    ],
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

**Anti-Pattern**: Inconsistent commit messages.

### Pattern 3: Automated Changelog Generation

**When to Use**: CI/CD integrated changelog

**Example**:
```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Generate changelog and release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: npx semantic-release
```

```json
// package.json
{
  "release": {
    "branches": ["main"],
    "plugins": [
      "@semantic-release/commit-analyzer",
      "@semantic-release/release-notes-generator",
      [
        "@semantic-release/changelog",
        {
          "changelogFile": "CHANGELOG.md"
        }
      ],
      [
        "@semantic-release/npm",
        {
          "npmPublish": true
        }
      ],
      [
        "@semantic-release/git",
        {
          "assets": ["CHANGELOG.md", "package.json"],
          "message": "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
        }
      ],
      "@semantic-release/github"
    ]
  }
}
```

```javascript
// release.config.js - Custom configuration
module.exports = {
  branches: [
    'main',
    { name: 'beta', prerelease: true },
    { name: 'alpha', prerelease: true }
  ],
  plugins: [
    ['@semantic-release/commit-analyzer', {
      preset: 'conventionalcommits',
      releaseRules: [
        { type: 'docs', scope: 'README', release: 'patch' },
        { type: 'refactor', release: 'patch' },
        { type: 'style', release: 'patch' },
        { type: 'perf', release: 'patch' }
      ]
    }],
    ['@semantic-release/release-notes-generator', {
      preset: 'conventionalcommits',
      presetConfig: {
        types: [
          { type: 'feat', section: 'Features' },
          { type: 'fix', section: 'Bug Fixes' },
          { type: 'perf', section: 'Performance Improvements' },
          { type: 'revert', section: 'Reverts' },
          { type: 'docs', section: 'Documentation', hidden: true },
          { type: 'style', section: 'Styles', hidden: true },
          { type: 'refactor', section: 'Code Refactoring', hidden: true },
          { type: 'test', section: 'Tests', hidden: true },
          { type: 'build', section: 'Build System', hidden: true },
          { type: 'ci', section: 'CI', hidden: true }
        ]
      }
    }]
  ]
};
```

**Anti-Pattern**: Manual changelog updates that get forgotten.

### Pattern 4: Release Notes Template

**When to Use**: Structured release announcements

**Example**:
```markdown
# Release v2.1.0

**Release Date:** January 15, 2024

## Highlights

This release introduces dark mode support and significantly improves search performance.

### Dark Mode Support
Users can now switch to dark mode in their profile settings. The theme preference
is automatically synced across all devices.

### Search Performance
Search queries are now up to 10x faster thanks to our new indexing strategy.

## What's New

### Features
- **Dark Mode**: Added dark mode support with automatic system preference detection
- **Search**: Improved search with fuzzy matching and relevance scoring
- **Export**: Added PDF export for reports

### Improvements
- Reduced initial page load time by 40%
- Better error messages for API validation errors
- Updated UI components for better accessibility

### Bug Fixes
- Fixed issue where notifications weren't clearing properly
- Resolved memory leak in real-time updates
- Fixed timezone display in scheduled tasks

## Breaking Changes

None in this release.

## Deprecations

- The `GET /api/search` endpoint is deprecated. Use `POST /api/v2/search` instead.
  This endpoint will be removed in v3.0.0.

## Security Updates

- Updated `lodash` to patch prototype pollution vulnerability (CVE-2024-1234)

## Upgrade Instructions

```bash
npm update mypackage@2.1.0
```

No migration steps required for this release.

## Contributors

Thanks to all contributors who made this release possible:
- @developer1 - Dark mode implementation
- @developer2 - Search improvements
- @developer3 - Bug fixes

## Full Changelog

See [CHANGELOG.md](./CHANGELOG.md) for the complete list of changes.
```

**Anti-Pattern**: Generic release notes without context.

### Pattern 5: API Changelog

**When to Use**: Documenting API changes

**Example**:
```markdown
# API Changelog

## 2024-01-15 (v2.1.0)

### New Endpoints

#### `POST /api/v2/search`
Full-text search with advanced filtering.

**Request:**
```json
{
  "query": "search term",
  "filters": {
    "category": "products",
    "dateRange": {
      "from": "2024-01-01",
      "to": "2024-01-31"
    }
  },
  "pagination": {
    "page": 1,
    "limit": 20
  }
}
```

**Response:**
```json
{
  "results": [...],
  "pagination": {
    "total": 150,
    "page": 1,
    "limit": 20,
    "pages": 8
  }
}
```

### Changed Endpoints

#### `GET /api/users/{id}`
- Added `preferences` field to response
- `lastLogin` now returns ISO 8601 format (was Unix timestamp)

**Before:**
```json
{
  "id": "123",
  "name": "John",
  "lastLogin": 1705312800
}
```

**After:**
```json
{
  "id": "123",
  "name": "John",
  "lastLogin": "2024-01-15T10:00:00Z",
  "preferences": {
    "theme": "dark",
    "notifications": true
  }
}
```

### Deprecated Endpoints

#### `GET /api/search` - Deprecated
Use `POST /api/v2/search` instead. Will be removed in v3.0.0.

**Migration:**
```javascript
// Before
const results = await fetch('/api/search?q=term');

// After
const results = await fetch('/api/v2/search', {
  method: 'POST',
  body: JSON.stringify({ query: 'term' })
});
```

### Rate Limits

| Endpoint | Limit |
|----------|-------|
| `/api/v2/search` | 100/min |
| `/api/users/*` | 1000/min |
```

**Anti-Pattern**: Undocumented API changes.

### Pattern 6: Internal vs Public Changelog

**When to Use**: Different audiences for changes

**Example**:
```markdown
# Internal Release Notes (v2.1.0)

## Technical Details

### Database Changes
- Added index on `users.email` for faster lookups
- New table `user_preferences` for theme settings
- Migration: `20240115_add_user_preferences.sql`

### Infrastructure
- Increased Redis cache size to 4GB
- Added new Elasticsearch index for search
- Updated Kubernetes deployment to use rolling updates

### Performance Metrics
- P99 latency reduced from 450ms to 120ms
- Memory usage reduced by 25%
- Database query count reduced by 40%

### Known Issues
- Search highlighting doesn't work with special characters
- Dark mode has minor issues in Safari (ticket: ENG-456)

### Rollback Procedure
1. Revert deployment: `kubectl rollout undo deployment/api`
2. Run migration rollback: `npm run migrate:down`
3. Clear Redis cache: `redis-cli FLUSHDB`

---

# Public Release Notes (v2.1.0)

## What's New

### Dark Mode
We've added dark mode support! Enable it in Settings > Appearance.

### Faster Search
Search is now up to 10x faster with improved relevance.

### Bug Fixes
- Fixed notification clearing issues
- Improved date/time display in all timezones

[Read the full changelog](./CHANGELOG.md)
```

**Anti-Pattern**: Exposing internal details in public changelogs.

## Checklist

- [ ] Changelog format documented
- [ ] Conventional commits enforced
- [ ] Automated changelog generation configured
- [ ] Breaking changes clearly marked
- [ ] Security updates highlighted
- [ ] Migration guides provided
- [ ] API changes documented
- [ ] Internal/public separation as needed
- [ ] Links to issues/PRs included
- [ ] Release dates recorded

## References

- [Keep a Changelog](https://keepachangelog.com/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Release](https://semantic-release.gitbook.io/)
- [Semantic Versioning](https://semver.org/)
