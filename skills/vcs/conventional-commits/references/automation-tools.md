# Automation Tools

Tool configurations for enforcing and automating conventional commits.

---

## Commitlint

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

---

## Commitizen

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

---

## Semantic Release

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
- `feat` -> minor bump (0.X.0)
- `fix` -> patch bump (0.0.X)
- `BREAKING CHANGE` -> major bump (X.0.0)
- Generates changelog
- Creates GitHub release
- Publishes to npm

---

## Git Commit Template

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
