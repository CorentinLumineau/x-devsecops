---
name: git
description: Use when hardening Git repositories or configuring security controls. Covers GPG signing, secret scanning, hook security, and Git best practices.
version: "1.0.0"
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  category: security
---

# git

Git security best practices covering GPG signing, secret scanning, and hook security.

<hook-trigger event="PreToolUse" tool="Bash" condition="Before git commit or git push operations">
  <action>Trigger pre-commit secret scanning (gitleaks/git-secrets) and verify GPG signing is configured before allowing commits</action>
</hook-trigger>

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
# Add to GitHub: Settings -> SSH and GPG keys
```

### Verify Signed Commits

```bash
git verify-commit HEAD
git log --show-signature
git log --show-signature main..feature-branch
```

---

## Secret Scanning

**Critical**: Scan for secrets BEFORE they enter git history. Removing secrets from history is difficult.

### Tools Comparison

| Tool | Strengths | Use Case |
|------|-----------|----------|
| `gitleaks` | Fast, comprehensive | Primary scanner |
| `git-secrets` | AWS-focused | AWS projects |
| `truffleHog` | Entropy detection | Find unknown patterns |
| `detect-secrets` | Baseline support | Large codebases |

### Pre-Commit Hook Setup

```bash
# Install gitleaks
brew install gitleaks  # macOS

# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
gitleaks protect --staged --verbose
EOF
chmod +x .git/hooks/pre-commit
```

### .gitignore Patterns for Sensitive Files

```gitignore
# Credentials
.env
.env.*
*.key
*.pem
*.p12

# Config with secrets
secrets.yaml
credentials.json

# Cloud provider
.aws/credentials
.gcp/credentials.json
```

---

## Hook Security

### Threat Model

Git hooks are executables that run during git operations. Malicious hooks can exfiltrate code/credentials, modify commits, install backdoors, or tamper with build artifacts.

### Supply Chain Risks

| Attack Vector | Risk | Mitigation |
|---------------|------|------------|
| Malicious hooks in repo | High | Hooks in `.git/hooks/` NOT committed |
| Hook managers (Husky, etc.) | Medium | Review hook installation scripts |
| Server-side hooks | High | Audit `pre-receive`, `update`, `post-receive` |
| Third-party hook tools | Medium | Pin versions, audit dependencies |

### Client-Side Hardening

```bash
# Review active hooks
ls -la .git/hooks/

# Check for symlinks to external scripts
find .git/hooks -type l -ls

# Set custom hooks path (advanced)
git config --global core.hooksPath ~/.git-hooks
```

**Server-side best practice**: Verify GPG signatures, reject unsigned commits, scan for secrets before accepting push, enforce commit message format.

---

## Common Pitfalls

1. **Committing `.env` files** - Use `.gitignore` and pre-commit hooks
2. **Forgetting to sign tags** - Set `tag.gpgsign = true`
3. **Bypassing hooks with `--no-verify`** - Disable via GPG enforcement
4. **Trusting third-party hooks** - Always review before installing
5. **Storing tokens in `.netrc`** - Use credential helper instead
6. **Not rotating tokens** - Set expiration dates
7. **Removing secrets with `git commit --amend`** - Doesn't remove from reflog

---

## When to Load References

| Reference | Load When | Use Case |
|-----------|-----------|----------|
| `references/credential-management.md` | Managing tokens, SSH/HTTPS, emergency response | Credential helpers, rotation, checklists, leak response |
| `references/gpg-signing.md` | Setting up commit verification | GPG key generation, forge integration |
| `references/secret-scanning.md` | Preventing credential leaks | Pre-commit setup, history scanning |
| `references/hook-security.md` | Auditing git hooks | Supply chain hardening, hook review |

---

## Related Skills

- **vcs-forge-operations** - Forge-specific GPG key upload
- **security-owasp** - OWASP A02:2021 (Cryptographic Failures) and A08:2021 (Software Integrity)
- **delivery-ci-cd** - CI/CD secret management
- **code-code-quality** - Pre-commit linting hooks

---

**Version**: 1.0.0 | **Category**: security | **License**: Apache-2.0
