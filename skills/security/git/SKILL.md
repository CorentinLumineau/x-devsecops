---
name: git
description: Git security best practices covering GPG signing, secret scanning, and hook security.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# git

Git security best practices covering GPG signing, secret scanning, and hook security.

---

## 80/20 Focus

| Priority Area | Coverage | Why It Matters |
|--------------|----------|----------------|
| GPG commit signing | 35% | Verify author identity, prevent impersonation |
| Secret scanning | 35% | Prevent credential leaks before they hit history |
| Hook security | 20% | Protect against supply chain attacks via git hooks |
| Credential management | 10% | Secure token storage and rotation |

**Core principle**: Security controls must be enforced at commit time, before secrets enter git history.

---

## Quick Reference

| Operation | Command | Purpose |
|-----------|---------|---------|
| Sign commit | `git commit -S -m "msg"` | GPG-sign single commit |
| Enable auto-signing | `git config commit.gpgsign true` | Sign all commits |
| Verify commit | `git verify-commit <sha>` | Check GPG signature |
| Scan for secrets | `gitleaks detect` | Find leaked credentials |
| Install pre-commit | `pre-commit install` | Enable pre-commit hooks |
| List hooks | `ls -la .git/hooks/` | Show active hooks |
| Disable hook bypass | `git config --global commit.gpgSign true` | Force signing |

---

## GPG Commit Signing

### Why Sign Commits?

- **Identity verification** - Prove commits are from claimed author
- **Non-repudiation** - Author cannot deny creating commit
- **Forge integration** - GitHub/Gitea show "Verified" badge
- **Supply chain security** - Detect compromised contributors

### Setup GPG Signing

```bash
# 1. Generate GPG key
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, no expiration (or 2 years)

# 2. List keys
gpg --list-secret-keys --keyid-format LONG

# 3. Configure git
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# 4. Export public key for forge
gpg --armor --export <KEY_ID>
# Add to GitHub: Settings → SSH and GPG keys
# Add to Gitea: Settings → Keys
```

### Verify Signed Commits

```bash
# Verify specific commit
git verify-commit HEAD

# Show signature in log
git log --show-signature

# Verify all commits in range
git log --show-signature main..feature-branch
```

### Forge-Specific Display

Both GitHub and Gitea display "Verified" badge for signed commits:

```
✓ Verified — GPG signature verified with key ABC123
```

---

## Secret Scanning

### Pre-Commit Prevention

**Critical**: Scan for secrets BEFORE they enter git history. Removing secrets from history is difficult.

### Tools Comparison

| Tool | Strengths | Use Case |
|------|-----------|----------|
| `gitleaks` | Fast, comprehensive | Primary scanner |
| `git-secrets` | AWS-focused | AWS projects |
| `truffleHog` | Entropy detection | Find unknown patterns |
| `detect-secrets` | Baseline support | Large codebases |

### Install Gitleaks Pre-Commit Hook

```bash
# Install gitleaks
brew install gitleaks  # macOS
# or download from https://github.com/gitleaks/gitleaks

# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
gitleaks protect --staged --verbose
EOF

chmod +x .git/hooks/pre-commit
```

### Pre-Commit Framework

For multi-tool setup:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

Install:
```bash
pip install pre-commit
pre-commit install
```

### Scan Existing History

```bash
# Scan entire repo history
gitleaks detect --verbose

# Scan specific commit range
gitleaks detect --log-opts="main..feature-branch"

# Output to report
gitleaks detect --report-format json --report-path report.json
```

### .gitignore Patterns for Sensitive Files

```gitignore
# Credentials
.env
.env.*
*.key
*.pem
*.p12
*.pfx

# Config with secrets
secrets.yaml
credentials.json
*-secrets.yml

# Cloud provider
.aws/credentials
.gcp/credentials.json

# Databases
*.db-wal
*.db-shm
```

---

## Hook Security

### Threat Model

Git hooks are executables that run during git operations. Malicious hooks can:
- Exfiltrate code/credentials
- Modify commits before push
- Install backdoors
- Tamper with build artifacts

### Supply Chain Risks

| Attack Vector | Risk | Mitigation |
|---------------|------|------------|
| Malicious hooks in repo | High | Hooks in `.git/hooks/` NOT committed |
| Hook managers (Husky, etc.) | Medium | Review hook installation scripts |
| Server-side hooks | High | Audit `pre-receive`, `update`, `post-receive` |
| Third-party hook tools | Medium | Pin versions, audit dependencies |

### Client-Side Hook Hardening

```bash
# Review active hooks
ls -la .git/hooks/

# Check for symlinks to external scripts
find .git/hooks -type l -ls

# Disable hook bypass for signed commits
git config --global commit.gpgsign true
# (Can't use --no-verify with GPG signing)

# Set custom hooks path (advanced)
git config --global core.hooksPath ~/.git-hooks
```

### Server-Side Hook Security

For repository administrators:

```bash
# Server hooks location (bare repo)
ls -la hooks/

# Review pre-receive hook (runs before accepting push)
cat hooks/pre-receive

# Review update hook (runs per ref update)
cat hooks/update

# Review post-receive hook (runs after successful push)
cat hooks/post-receive
```

**Best practice**: Server hooks should:
1. Verify GPG signatures on commits
2. Reject unsigned commits from untrusted users
3. Scan for secrets before accepting push
4. Enforce commit message format

### Husky/Lint-Staged Security

Husky installs hooks via `package.json`. Review before installing:

```json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint-staged"
    }
  },
  "lint-staged": {
    "*.js": ["eslint --fix", "git add"]
  }
}
```

**Security checks**:
- Verify `husky` version is latest
- Review scripts in `lint-staged` config
- Avoid arbitrary command execution in hooks
- Pin dependency versions

---

## Credential Management

### Credential Storage

**NEVER** store credentials in:
- Git config (`~/.gitconfig`)
- Repository files (even if `.gitignore`d)
- Commit messages
- Branch names

**DO** use:
- Git credential helpers (encrypted storage)
- Environment variables (per-session)
- Secret management tools (Vault, 1Password)

### Git Credential Helpers

```bash
# macOS: use Keychain
git config --global credential.helper osxkeychain

# Linux: use secret-service (GNOME Keyring)
git config --global credential.helper /usr/share/git/credential/libsecret/git-credential-libsecret

# Windows: use Credential Manager
git config --global credential.helper manager

# Cache credentials (15 min default)
git config --global credential.helper 'cache --timeout=900'
```

### Token Rotation

```bash
# GitHub: create token with expiration
# Settings → Developer settings → Personal access tokens → Fine-grained tokens
# Set expiration: 90 days

# Gitea: create token with expiration
# Settings → Applications → Generate New Token
# Set expiration date

# Rotate before expiration
# Delete old token, generate new, update credential helper
```

### SSH vs HTTPS

| Protocol | Pros | Cons | Best For |
|----------|------|------|----------|
| SSH | No password prompts, key-based | Firewall issues, more setup | Developers |
| HTTPS | Works everywhere, token auth | Token management | CI/CD |

---

## Security Checklist

### Repository Setup

- [ ] Enable GPG signing for all commits
- [ ] Install secret scanning pre-commit hook
- [ ] Configure `.gitignore` for sensitive files
- [ ] Review and approve git hooks before running
- [ ] Use credential helper for token storage
- [ ] Set token expiration (max 90 days)

### For Contributors

- [ ] Generate GPG key and add to forge
- [ ] Configure `commit.gpgsign = true`
- [ ] Install `gitleaks` or similar scanner
- [ ] Review `.git/hooks/` before first commit
- [ ] Never commit credentials or API keys
- [ ] Rotate tokens every 60-90 days

### For Repository Admins

- [ ] Enforce signed commits on protected branches
- [ ] Configure server-side hooks for secret scanning
- [ ] Audit hook scripts for security issues
- [ ] Require 2FA for all contributors
- [ ] Monitor for leaked credentials in history
- [ ] Document security requirements in CONTRIBUTING.md

---

## When to Load References

| Reference | Load When | Use Case |
|-----------|-----------|----------|
| `gpg-signing.md` | Setting up commit verification | GPG key generation, forge integration |
| `secret-scanning.md` | Preventing credential leaks | Pre-commit setup, history scanning |
| `hook-security.md` | Auditing git hooks | Supply chain hardening, hook review |

---

## Related Skills

- **vcs-forge-operations** - Forge-specific GPG key upload
- **security-owasp** - OWASP A02:2021 (Cryptographic Failures) and A08:2021 (Software Integrity)
- **delivery-ci-cd** - CI/CD secret management
- **code-code-quality** - Pre-commit linting hooks

---

## Common Pitfalls

1. **Committing `.env` files** - Use `.gitignore` and pre-commit hooks
2. **Forgetting to sign tags** - Set `tag.gpgsign = true`
3. **Bypassing hooks with `--no-verify`** - Disable via GPG enforcement
4. **Trusting third-party hooks** - Always review before installing
5. **Storing tokens in `.netrc`** - Use credential helper instead
6. **Not rotating tokens** - Set expiration dates
7. **Removing secrets with `git commit --amend`** - Doesn't remove from reflog, use `git filter-branch` or BFG

---

## Emergency: Secret Leaked to History

If credentials are committed to git history:

1. **Revoke immediately** - Assume credential is compromised
2. **Scan history** - `gitleaks detect` to find all occurrences
3. **Rewrite history** - Use BFG Repo Cleaner or `git filter-branch`
4. **Force push** - `git push --force` (requires coordination)
5. **Notify team** - All contributors must re-clone
6. **Rotate all secrets** - Even if removed from history

**Note**: Public repositories (GitHub, GitLab) may have forks with leaked secrets. Contact support to purge caches.

---

**Version**: 1.0.0 | **Category**: security | **License**: Apache-2.0
