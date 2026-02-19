---
name: conventional-commits
description: Use when writing commit messages or configuring commit conventions. Covers conventional commits specification with types, scopes, breaking changes, and co-authored-by patterns.
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

For detailed type catalog with examples and version triggers, see `references/commit-type-catalog.md`.

---

## Message Format

### Basic Structure

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type (Required)

Must be one of: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

### Scope (Optional)

Component or module affected. Use lowercase, kebab-case (e.g., `auth`, `api`, `database`, `ui`).

### Subject (Required)

- Use imperative mood ("add" not "added" or "adds")
- Lowercase first letter, no period at end
- Maximum 50 characters, concise but descriptive

### Body (Optional)

- Separate from subject with blank line
- Explain **what** and **why**, not **how**
- Wrap at 72 characters

### Footer (Optional)

- `BREAKING CHANGE:` - Incompatible API change
- `Closes #123` / `Fixes #123` / `Refs #123` - Issue references
- `Co-authored-by: Name <email>` - Multiple authors
- `Reviewed-by:` / `Signed-off-by:` - Attribution

---

## Breaking Changes

### Syntax 1: ! Suffix

```
feat!: remove deprecated API endpoint
fix(auth)!: change token format
```

### Syntax 2: Footer

```
feat(api): redesign authentication flow

BREAKING CHANGE: Auth endpoints now require OAuth tokens instead of API keys.
```

### Both Combined (Recommended)

```
feat(api)!: redesign authentication flow

BREAKING CHANGE: Auth endpoints now require OAuth tokens instead of API keys.
Migrate by obtaining OAuth credentials from developer portal.
```

**When to use**: API signature change, configuration format change, behavioral change, removal of deprecated features.

**Effect**: Major version bump (X.0.0).

---

## Best Practices

### Subject Line

- **Imperative mood**: "add feature" not "added feature"
- **Lowercase**: "add login" not "Add login"
- **No period**: "add login" not "add login."
- **Descriptive**: "fix crash" -> "fix crash on empty input"

### Type Selection

- New functionality -> `feat`
- Bug fix -> `fix`
- Docs only -> `docs`
- No production code change -> `chore`
- Code restructure -> `refactor`

---

## Common Pitfalls

1. **Wrong mood**: "added" -> "add"
2. **Capitalized subject**: "Add feature" -> "add feature"
3. **Vague subject**: "fix bug" -> "fix crash on null input"
4. **Missing type**: "update README" -> "docs: update README"
5. **Breaking change without `!`**: Missing visual indicator

---

## When to Load References

| Reference | Load When | Use Case |
|-----------|-----------|----------|
| `references/commit-type-catalog.md` | Selecting type or writing examples | Detailed types, scopes, extended examples |
| `references/automation-tools.md` | Setting up tooling | Commitlint, Commitizen, Semantic Release configs |

---

## Related Skills

- **vcs-git-workflows** - Git operations that produce commits
- **vcs-forge-operations** - PR titles follow conventional format
- **delivery-release-git** - Automated versioning from conventional commits
- **delivery-release-management** - Changelog generation

---

**Version**: 1.0.0 | **Category**: vcs | **License**: Apache-2.0
