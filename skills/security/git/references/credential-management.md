# Credential Management

Platform-specific credential management, token rotation, and secure storage patterns.

---

## Credential Storage

**NEVER** store credentials in:
- Git config (`~/.gitconfig`)
- Repository files (even if `.gitignore`d)
- Commit messages
- Branch names

**DO** use:
- Git credential helpers (encrypted storage)
- Environment variables (per-session)
- Secret management tools (Vault, 1Password)

---

## Git Credential Helpers

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

---

## Token Rotation

```bash
# GitHub: create token with expiration
# Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens
# Set expiration: 90 days

# Gitea: create token with expiration
# Settings -> Applications -> Generate New Token
# Set expiration date

# Rotate before expiration
# Delete old token, generate new, update credential helper
```

---

## SSH vs HTTPS

| Protocol | Pros | Cons | Best For |
|----------|------|------|----------|
| SSH | No password prompts, key-based | Firewall issues, more setup | Developers |
| HTTPS | Works everywhere, token auth | Token management | CI/CD |

---

## Security Checklists

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

## Emergency: Secret Leaked to History

If credentials are committed to git history:

1. **Revoke immediately** - Assume credential is compromised
2. **Scan history** - `gitleaks detect` to find all occurrences
3. **Rewrite history** - Use BFG Repo Cleaner or `git filter-branch`
4. **Force push** - `git push --force` (requires coordination)
5. **Notify team** - All contributors must re-clone
6. **Rotate all secrets** - Even if removed from history

**Note**: Public repositories (GitHub, GitLab) may have forks with leaked secrets. Contact support to purge caches.
