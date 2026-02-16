# GPG Signing Reference

Complete guide to GPG key management and commit/tag signing for git.

---

## GPG Key Generation

### Generate New Key

```bash
# Interactive key generation
gpg --full-generate-key
```

**Prompts**:
1. Key type: `(1) RSA and RSA` (default)
2. Key size: `4096` (maximum security)
3. Expiration: `2y` (2 years recommended) or `0` (no expiration)
4. User ID: `Your Name <email@example.com>`
5. Passphrase: Strong passphrase (stored in GPG agent)

### Non-Interactive Generation

```bash
# Batch mode key generation
gpg --batch --generate-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Your Name
Name-Email: email@example.com
Expire-Date: 2y
Passphrase: YourStrongPassphrase
%commit
EOF
```

---

## List and Manage Keys

### List Secret Keys

```bash
# List keys with long ID format
gpg --list-secret-keys --keyid-format LONG

# Output example:
# sec   rsa4096/ABCD1234EFGH5678 2026-02-16 [SC] [expires: 2028-02-16]
#       1234567890ABCDEF1234567890ABCDEF12345678
# uid                 [ultimate] Your Name <email@example.com>
# ssb   rsa4096/1234567890ABCDEF 2026-02-16 [E] [expires: 2028-02-16]

# Key ID is: ABCD1234EFGH5678
```

### Export Public Key

```bash
# Export ASCII-armored public key
gpg --armor --export ABCD1234EFGH5678

# Output:
# -----BEGIN PGP PUBLIC KEY BLOCK-----
# ...
# -----END PGP PUBLIC KEY BLOCK-----
```

### Export Private Key (Backup)

```bash
# Export private key (KEEP SECURE)
gpg --armor --export-secret-keys ABCD1234EFGH5678 > private-key-backup.asc

# Store in password manager or encrypted drive
# NEVER commit to git or upload to cloud
```

### Delete Key

```bash
# Delete secret key
gpg --delete-secret-keys ABCD1234EFGH5678

# Delete public key
gpg --delete-keys ABCD1234EFGH5678
```

---

## Git Configuration

### Configure Signing Key

```bash
# Set GPG key for git
git config --global user.signingkey ABCD1234EFGH5678

# Enable automatic commit signing
git config --global commit.gpgsign true

# Enable automatic tag signing
git config --global tag.gpgsign true

# Specify GPG program (if needed)
git config --global gpg.program gpg2
```

### Verify Configuration

```bash
# Check git config
git config --global user.signingkey
git config --global commit.gpgsign
git config --global tag.gpgsign
```

---

## Signing Commits

### Manual Signing

```bash
# Sign single commit
git commit -S -m "feat: add new feature"

# Sign and GPG-sign
git commit -S -m "$(cat <<'EOF'
feat: add authentication

Implements JWT-based authentication.
EOF
)"
```

### Automatic Signing

With `commit.gpgsign = true`, all commits are signed automatically:

```bash
# No -S flag needed
git commit -m "feat: add feature"
```

### Verify Commit Signature

```bash
# Verify HEAD commit
git verify-commit HEAD

# Output if valid:
# gpg: Signature made Mon Feb 16 10:00:00 2026 PST
# gpg: Good signature from "Your Name <email@example.com>"

# Show signature in log
git log --show-signature -1
```

---

## Signing Tags

### Create Signed Tag

```bash
# Annotated signed tag
git tag -s v1.0.0 -m "Release version 1.0.0"

# Lightweight signed tag (not recommended)
git tag -s v1.0.0
```

### Automatic Tag Signing

With `tag.gpgsign = true`:

```bash
# Automatically signed
git tag -a v1.0.0 -m "Release 1.0.0"
```

### Verify Tag Signature

```bash
# Verify tag
git verify-tag v1.0.0

# Show tag signature
git tag -v v1.0.0
```

---

## Forge Integration

### GitHub GPG Setup

1. Export public key:
   ```bash
   gpg --armor --export ABCD1234EFGH5678
   ```

2. Add to GitHub:
   - Go to: Settings → SSH and GPG keys → New GPG key
   - Paste public key block
   - Click "Add GPG key"

3. Verify in GitHub:
   - Push signed commit
   - Check for "Verified" badge next to commit

### Gitea GPG Setup

1. Export public key:
   ```bash
   gpg --armor --export ABCD1234EFGH5678
   ```

2. Add to Gitea:
   - Go to: Settings → Keys → Add Key
   - Select "GPG Key" type
   - Paste public key block
   - Click "Add Key"

3. Verify in Gitea:
   - Push signed commit
   - Check for "Verified" badge in commit view

### Troubleshooting Forge Verification

**Problem**: Commits show "Unverified" despite signing.

**Solutions**:
1. Email mismatch:
   ```bash
   # Ensure git email matches GPG key email
   git config --global user.email email@example.com
   gpg --list-keys email@example.com
   ```

2. Key not uploaded:
   - Re-upload public key to forge
   - Wait 5 minutes for cache refresh

3. Expired key:
   ```bash
   # Extend expiration
   gpg --edit-key ABCD1234EFGH5678
   gpg> expire
   gpg> save
   # Re-export and re-upload public key
   ```

---

## SSH Signing (Alternative)

Git 2.34+ supports SSH signing as alternative to GPG:

### Setup SSH Signing

```bash
# Generate SSH signing key
ssh-keygen -t ed25519 -f ~/.ssh/git_signing -C "email@example.com"

# Configure git to use SSH signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/git_signing.pub
git config --global commit.gpgsign true
```

### Add SSH Key to Forge

**GitHub**:
- Settings → SSH and GPG keys → New SSH key
- Select "Signing Key" as type
- Paste `~/.ssh/git_signing.pub`

**Gitea**:
- Gitea 1.17+ supports SSH signing
- Settings → Keys → Add Key
- Select "Signing Key" type
- Paste public key

### SSH Signing vs GPG

| Aspect | GPG | SSH |
|--------|-----|-----|
| Key management | Separate keyring | Same as auth keys |
| Forge support | Universal | GitHub, Gitea 1.17+ |
| Key rotation | Manual | Can reuse auth keys |
| Expiration | Built-in | Manual tracking |
| Ecosystem | PGP ecosystem | SSH ecosystem |

**Recommendation**: Use GPG for maximum compatibility, SSH for simplicity if forge supports it.

---

## Key Rotation

### Extend Key Expiration

```bash
# Edit key
gpg --edit-key ABCD1234EFGH5678

# In GPG prompt:
gpg> expire
# Choose new expiration (e.g., 2y)
gpg> save

# Re-export and re-upload public key to forge
gpg --armor --export ABCD1234EFGH5678
```

### Generate New Key and Migrate

```bash
# 1. Generate new key
gpg --full-generate-key

# 2. Configure git to use new key
git config --global user.signingkey NEW_KEY_ID

# 3. Upload new public key to forge

# 4. Keep old key for verification of old commits
# (Don't delete old secret key)
```

---

## GPG Agent Configuration

### Cache Passphrase

```bash
# ~/.gnupg/gpg-agent.conf
default-cache-ttl 3600        # Cache for 1 hour
max-cache-ttl 86400           # Max cache 24 hours
```

Reload agent:
```bash
gpgconf --kill gpg-agent
gpg-agent --daemon
```

### Pin Entry Programs

**macOS**:
```bash
# Use pinentry-mac (GUI prompt)
brew install pinentry-mac
echo "pinentry-program $(which pinentry-mac)" >> ~/.gnupg/gpg-agent.conf
```

**Linux**:
```bash
# Use pinentry-gtk2 (GUI prompt)
echo "pinentry-program /usr/bin/pinentry-gtk-2" >> ~/.gnupg/gpg-agent.conf
```

**Terminal-only**:
```bash
# Use pinentry-tty (terminal prompt)
echo "pinentry-program /usr/bin/pinentry-tty" >> ~/.gnupg/gpg-agent.conf
```

---

## Multi-Machine Setup

### Export and Import Keys

**On old machine**:
```bash
# Export secret key
gpg --armor --export-secret-keys ABCD1234EFGH5678 > secret.asc

# Transfer secret.asc securely (USB, encrypted email, password manager)
```

**On new machine**:
```bash
# Import secret key
gpg --import secret.asc

# Trust imported key
gpg --edit-key ABCD1234EFGH5678
gpg> trust
gpg> 5 (ultimate trust)
gpg> save

# Shred transfer file
shred -vfz -n 10 secret.asc
```

---

## Verification in CI/CD

### GitHub Actions

```yaml
# .github/workflows/verify-commits.yml
name: Verify GPG Signatures

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Import public keys
        run: |
          curl -s https://github.com/${{ github.repository_owner }}.gpg | gpg --import

      - name: Verify commits
        run: |
          git log --show-signature origin/main..HEAD
```

### Gitea Actions

```yaml
# .gitea/workflows/verify-commits.yml
name: Verify GPG Signatures

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Verify commits
        run: |
          git log --show-signature ${{ github.event.before }}..${{ github.sha }}
```

---

**Last Updated**: 2026-02-16
