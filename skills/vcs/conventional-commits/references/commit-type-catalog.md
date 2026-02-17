# Commit Type Catalog

Detailed catalog of all conventional commit types with examples, triggers, and usage guidance.

---

## feat (Feature)

New feature or capability.

```
feat: add user registration
feat(api): add GraphQL endpoint
feat(ui): add dark mode toggle
```

**Triggers**: Minor version bump (0.X.0).

## fix (Bug Fix)

Bug fix that doesn't change API.

```
fix: prevent crash on null input
fix(auth): validate token expiry
fix(ui): correct button alignment
```

**Triggers**: Patch version bump (0.0.X).

## docs (Documentation)

Documentation changes only.

```
docs: update API reference
docs(readme): add installation guide
docs: fix typo in contributing guide
```

**Triggers**: No version bump.

## style (Code Style)

Code formatting, whitespace, missing semicolons (no logic change).

```
style: format with prettier
style(api): fix indentation
style: remove trailing whitespace
```

**Triggers**: No version bump.

## refactor (Refactoring)

Code restructure with no behavior change.

```
refactor: extract validation logic
refactor(auth): simplify token generation
refactor: rename variable for clarity
```

**Triggers**: No version bump.

## perf (Performance)

Performance improvement.

```
perf: optimize database query
perf(parser): use binary search
perf: add caching layer
```

**Triggers**: Patch version bump (optional, project-dependent).

## test (Tests)

Add or update tests.

```
test: add user registration tests
test(auth): cover edge cases
test: improve test coverage to 90%
```

**Triggers**: No version bump.

## build (Build System)

Changes to build system or dependencies.

```
build: update webpack to v5
build(deps): bump lodash to 4.17.21
build: add typescript compiler
```

**Triggers**: No version bump.

## ci (CI/CD)

CI configuration changes.

```
ci: add GitHub Actions workflow
ci(test): run tests on pull request
ci: deploy to staging on merge
```

**Triggers**: No version bump.

## chore (Maintenance)

Routine tasks, tooling, no production code change.

```
chore: update dependencies
chore(release): bump version to 1.0.0
chore: clean up old files
```

**Triggers**: No version bump.

## revert (Revert)

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

## Extended Examples

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
