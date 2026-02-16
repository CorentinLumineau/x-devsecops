---
name: conventional-commits
description: Conventional commits specification with types, scopes, breaking changes, and co-authored-by patterns.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: vcs
---

# conventional-commits

Conventional commits specification with types, scopes, breaking changes, and co-authored-by patterns.

---

## 80/20 Focus

| Priority Area | Coverage | Why It Matters |
|--------------|----------|----------------|
| Core types (feat, fix, chore) | 60% | 80% of commits use these three types |
| Breaking changes | 20% | Critical for semantic versioning |
| Scope conventions | 15% | Organize commits by component |
| Footers (Closes, Co-authored-by) | 5% | Link commits to issues and collaborators |

**Core principle**: Standardized commit messages enable automated versioning, changelog generation, and clear communication.

---

## Quick Reference

| Type | Description | Example | Changelog Section |
|------|-------------|---------|-------------------|
| `feat` | New feature | `feat: add login` | Features |
| `fix` | Bug fix | `fix: crash on startup` | Bug Fixes |
| `docs` | Documentation only | `docs: update README` | Documentation |
| `style` | Code style (no logic change) | `style: fix indentation` | (none) |
| `refactor` | Code restructure (no behavior change) | `refactor: extract helper` | (none) |
| `perf` | Performance improvement | `perf: optimize query` | Performance |
| `test` | Add/update tests | `test: add auth tests` | (none) |
| `build` | Build system changes | `build: update webpack` | Build System |
| `ci` | CI configuration | `ci: add test workflow` | CI/CD |
| `chore` | Maintenance tasks | `chore: update deps` | (none) |
| `revert` | Revert previous commit | `revert: feat: add login` | Reverts |

---

## Message Format

### Basic Structure

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Components

#### Type (Required)

Categorizes the commit. Must be one of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

#### Scope (Optional)

Component or module affected. Use lowercase, kebab-case.

Examples:
- `auth` - Authentication module
- `api` - API layer
- `database` - Database layer
- `ui` - User interface
- `parser` - Parser component

#### Subject (Required)

Short description of the change.

**Rules**:
- Use imperative mood ("add" not "added" or "adds")
- Lowercase first letter
- No period at end
- Maximum 50 characters
- Be concise but descriptive

**Good**:
```
feat: add JWT authentication
fix: resolve crash on empty input
docs: clarify installation steps
```

**Bad**:
```
feat: Added JWT authentication.  # Wrong mood, capitalized, period
fix: fixes a bug                 # Vague
docs: Documentation              # Not descriptive
```

#### Body (Optional)

Detailed explanation of the change.

**Rules**:
- Separate from subject with blank line
- Explain **what** and **why**, not **how**
- Wrap at 72 characters
- Use multiple paragraphs if needed

**Example**:
```
feat(auth): add JWT authentication

Implement token-based authentication to replace session cookies.
This improves statelessness and enables horizontal scaling.

Tokens expire after 24 hours and must be refreshed.
```

#### Footer (Optional)

Metadata about the commit.

**Common footers**:
- `BREAKING CHANGE:` - Incompatible API change
- `Closes #123` - Close issue
- `Fixes #123` - Fix bug
- `Refs #123` - Reference issue
- `Co-authored-by:` - Multiple authors
- `Reviewed-by:` - Reviewer attribution

---

## Commit Types Detail

### feat (Feature)

New feature or capability.

```
feat: add user registration
feat(api): add GraphQL endpoint
feat(ui): add dark mode toggle
```

**Triggers**: Minor version bump (0.X.0).

### fix (Bug Fix)

Bug fix that doesn't change API.

```
fix: prevent crash on null input
fix(auth): validate token expiry
fix(ui): correct button alignment
```

**Triggers**: Patch version bump (0.0.X).

### docs (Documentation)

Documentation changes only.

```
docs: update API reference
docs(readme): add installation guide
docs: fix typo in contributing guide
```

**Triggers**: No version bump.

### style (Code Style)

Code formatting, whitespace, missing semicolons (no logic change).

```
style: format with prettier
style(api): fix indentation
style: remove trailing whitespace
```

**Triggers**: No version bump.

### refactor (Refactoring)

Code restructure with no behavior change.

```
refactor: extract validation logic
refactor(auth): simplify token generation
refactor: rename variable for clarity
```

**Triggers**: No version bump.

### perf (Performance)

Performance improvement.

```
perf: optimize database query
perf(parser): use binary search
perf: add caching layer
```

**Triggers**: Patch version bump (optional, project-dependent).

### test (Tests)

Add or update tests.

```
test: add user registration tests
test(auth): cover edge cases
test: improve test coverage to 90%
```

**Triggers**: No version bump.

### build (Build System)

Changes to build system or dependencies.

```
build: update webpack to v5
build(deps): bump lodash to 4.17.21
build: add typescript compiler
```

**Triggers**: No version bump.

### ci (CI/CD)

CI configuration changes.

```
ci: add GitHub Actions workflow
ci(test): run tests on pull request
ci: deploy to staging on merge
```

**Triggers**: No version bump.

### chore (Maintenance)

Routine tasks, tooling, no production code change.

```
chore: update dependencies
chore(release): bump version to 1.0.0
chore: clean up old files
```

**Triggers**: No version bump.

### revert (Revert)

Revert previous commit.

```
revert: feat: add user registration

This reverts commit abc123def456.
```

**Triggers**: Depends on reverted commit type.

---

## Scope Conventions

### Module/Component Scopes

```
feat(auth): add login endpoint
fix(database): resolve connection leak
docs(api): update endpoint documentation
```

### Directory-Based Scopes

```
feat(src/api): add user controller
fix(src/ui): correct layout bug
```

### Multi-Scope

```
feat(auth,api): integrate OAuth provider
```

### No Scope

Acceptable for cross-cutting changes:

```
feat: add logging framework
chore: update all dependencies
```

---

## Breaking Changes

### Syntax 1: ! Suffix

```
feat!: remove deprecated API endpoint
fix(auth)!: change token format
```

**Effect**: Major version bump (X.0.0).

### Syntax 2: Footer

```
feat(api): redesign authentication flow

BREAKING CHANGE: Auth endpoints now require OAuth tokens instead of API keys.
Migrate by obtaining OAuth credentials from developer portal.
```

### Both Combined (Recommended)

```
feat(api)!: redesign authentication flow

BREAKING CHANGE: Auth endpoints now require OAuth tokens instead of API keys.
Migrate by obtaining OAuth credentials from developer portal.
```

**When to use**:
- API signature change
- Configuration format change
- Behavioral change that may break existing usage
- Removal of deprecated features

---

## Footers

### Closes / Fixes / Resolves

Auto-close issues on merge:

```
fix: resolve crash on empty input

Fixes #42
Closes #43
Resolves #44
```

**Supported keywords**: `Closes`, `Fixes`, `Resolves` (and lowercase versions).

### Refs (Reference)

Reference without closing:

```
feat: add caching layer

Refs #123
Related to #456
```

### Co-authored-by

Multiple authors:

```
feat: implement authentication

Co-authored-by: Jane Doe <jane@example.com>
Co-authored-by: John Smith <john@example.com>
```

**Format**: `Co-authored-by: Name <email>`

### Reviewed-by

Track reviewer:

```
fix: critical security bug

Reviewed-by: Security Team <security@example.com>
```

### Signed-off-by

Developer Certificate of Origin (DCO):

```
feat: add feature

Signed-off-by: Developer Name <dev@example.com>
```

**Auto-add**: `git commit -s`

### Multiple Footers

```
feat(api): add GraphQL support

BREAKING CHANGE: REST API deprecated, use GraphQL.
Closes #100
Co-authored-by: Jane Doe <jane@example.com>
Reviewed-by: Tech Lead <lead@example.com>
```

---

## Examples

### Simple Feature

```
feat: add user registration
```

### Feature with Scope and Body

```
feat(auth): add JWT authentication

Implement token-based authentication to replace session cookies.
Tokens expire after 24 hours and must be refreshed.
```

### Bug Fix with Issue Reference

```
fix: prevent crash on null input

Fixes #123
```

### Breaking Change

```
feat(api)!: redesign user endpoint

BREAKING CHANGE: User endpoint now returns full user object instead of ID.
Update clients to handle new response format.

Closes #200
```

### Multiple Authors

```
feat(ui): add dark mode

Implement dark mode theme with system preference detection.

Co-authored-by: Jane Doe <jane@example.com>
Co-authored-by: John Smith <john@example.com>
```

### Revert

```
revert: feat(auth): add OAuth provider

This reverts commit abc123def456.

The OAuth integration caused login failures in production.
Reverting while investigating root cause.
```

### Chore with Dependency Update

```
chore(deps): update lodash to 4.17.21

Security update to fix CVE-2021-23337.

Refs #500
```

### Performance Improvement

```
perf(database): optimize user query

Switch from N+1 queries to single JOIN query.
Reduces query time from 500ms to 50ms.

Closes #300
```

---

## Automation Tools

### Commitlint

Enforce conventional commits:

```bash
# Install
npm install --save-dev @commitlint/{cli,config-conventional}

# Configure
echo "module.exports = {extends: ['@commitlint/config-conventional']}" > commitlint.config.js

# Hook via husky
npx husky add .husky/commit-msg 'npx --no-install commitlint --edit "$1"'
```

`.commitlintrc.json`:
```json
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "type-enum": [2, "always", [
      "feat", "fix", "docs", "style", "refactor",
      "perf", "test", "build", "ci", "chore", "revert"
    ]],
    "subject-case": [2, "always", "lower-case"],
    "subject-max-length": [2, "always", 50]
  }
}
```

### Commitizen

Interactive commit message builder:

```bash
# Install
npm install --save-dev commitizen cz-conventional-changelog

# Configure
echo '{ "path": "cz-conventional-changelog" }' > .czrc

# Use
npx cz
# or
git cz
```

Prompts:
1. Select type
2. Enter scope
3. Write subject
4. Write body
5. Is breaking change?
6. Close issues?

### Semantic Release

Automated versioning and changelog:

```bash
# Install
npm install --save-dev semantic-release

# Configure
# .releaserc.json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    "@semantic-release/npm",
    "@semantic-release/github",
    "@semantic-release/git"
  ]
}
```

**How it works**:
- Analyzes commits since last release
- `feat` → minor bump (0.X.0)
- `fix` → patch bump (0.0.X)
- `BREAKING CHANGE` → major bump (X.0.0)
- Generates changelog
- Creates GitHub release
- Publishes to npm

---

## Commit Message Templates

### Git Commit Template

Create `~/.gitmessage`:

```
# <type>(<scope>): <subject>
#
# <body>
#
# <footer>

# Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert
# Scope: component/module affected (optional)
# Subject: imperative, lowercase, no period, max 50 chars
# Body: wrap at 72 chars, explain what and why
# Footer: BREAKING CHANGE, Closes #123, Co-authored-by:

# Breaking change? Add ! after type: feat!: <subject>
# Multiple authors? Add: Co-authored-by: Name <email>
```

Configure git:
```bash
git config --global commit.template ~/.gitmessage
```

---

## Best Practices

### Subject Line

- **Imperative mood**: "add feature" not "added feature"
- **Lowercase**: "add login" not "Add login"
- **No period**: "add login" not "add login."
- **Concise**: 50 characters max
- **Descriptive**: "fix crash" → "fix crash on empty input"

### Body

- Separate from subject with blank line
- Explain **what** and **why**, not **how**
- Wrap at 72 characters
- Use multiple paragraphs for complex changes

### Type Selection

- New functionality → `feat`
- Bug fix → `fix`
- Docs only → `docs`
- No production code change → `chore`
- Code restructure → `refactor`

### Scope

- Use when change affects specific module
- Omit for cross-cutting changes
- Use consistent naming (lowercase, kebab-case)

### Breaking Changes

- Always use `!` suffix AND `BREAKING CHANGE:` footer
- Explain migration path in footer
- Update major version

---

## Common Pitfalls

1. **Wrong mood**: "added" → "add"
2. **Capitalized subject**: "Add feature" → "add feature"
3. **Period at end**: "add feature." → "add feature"
4. **Vague subject**: "fix bug" → "fix crash on null input"
5. **Missing type**: "update README" → "docs: update README"
6. **Wrong type**: `feat` for bug fix → `fix`
7. **No scope when needed**: `fix: auth bug` → `fix(auth): token validation`
8. **Breaking change without `!`**: Missing visual indicator

---

## Related Skills

- **vcs-git-workflows** - Git operations that produce commits
- **vcs-forge-operations** - PR titles follow conventional format
- **delivery-release-git** - Automated versioning from conventional commits
- **delivery-release-management** - Changelog generation

---

## Changelog Generation

With conventional commits, changelogs can be auto-generated:

### Grouped by Type

```markdown
## [1.0.0] - 2026-02-16

### Features
- add JWT authentication
- add dark mode toggle

### Bug Fixes
- prevent crash on null input
- resolve token expiration bug

### BREAKING CHANGES
- Auth endpoints now require OAuth tokens
```

### Tools

- **conventional-changelog**: Standalone changelog generator
- **semantic-release**: Automated versioning + changelog
- **standard-version**: Manual release workflow

---

**Version**: 1.0.0 | **Category**: vcs | **License**: Apache-2.0
