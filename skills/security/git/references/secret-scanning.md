# Secret Scanning Reference

Tools, patterns, and workflows for detecting and preventing credential leaks in git repositories.

---

## Pre-Commit Hook Strategy

**Golden rule**: Prevent secrets from entering git history. Scanning history is detective, pre-commit hooks are preventive.

---

## Tool Comparison

### Gitleaks (Recommended)

**Strengths**:
- Fast scanning (Go-based)
- Comprehensive rule set (400+ patterns)
- Pre-commit and CI/CD support
- SARIF output for GitHub Security

**Installation**:
```bash
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/

# Windows
scoop install gitleaks
```

**Pre-commit hook**:
```bash
#!/bin/bash
# .git/hooks/pre-commit

gitleaks protect --staged --verbose --redact

if [ $? -ne 0 ]; then
  echo "❌ Gitleaks detected secrets. Commit blocked."
  exit 1
fi
```

### git-secrets (AWS-focused)

**Strengths**:
- AWS credential patterns
- Custom regex support
- Maintained by AWS Labs

**Installation**:
```bash
# macOS
brew install git-secrets

# Linux
git clone https://github.com/awslabs/git-secrets
cd git-secrets
sudo make install
```

**Setup**:
```bash
# Install hooks in repo
git secrets --install

# Add AWS patterns
git secrets --register-aws

# Add custom patterns
git secrets --add 'password\s*=\s*.+'
```

### TruffleHog (Entropy-based)

**Strengths**:
- Entropy detection (finds unknown patterns)
- Finds secrets even without known patterns
- GitHub integration

**Installation**:
```bash
# macOS
brew install trufflesecurity/trufflehog/trufflehog

# Linux
wget https://github.com/trufflesecurity/trufflehog/releases/download/v3.63.0/trufflehog_3.63.0_linux_amd64.tar.gz
tar -xzf trufflehog_3.63.0_linux_amd64.tar.gz
sudo mv trufflehog /usr/local/bin/
```

**Scan repo**:
```bash
# Scan git history
trufflehog git file://. --only-verified

# Scan filesystem
trufflehog filesystem . --only-verified
```

### detect-secrets (Baseline support)

**Strengths**:
- Baseline file for known false positives
- Plugin architecture
- Enterprise-friendly

**Installation**:
```bash
pip install detect-secrets
```

**Setup**:
```bash
# Create baseline
detect-secrets scan > .secrets.baseline

# Audit baseline (mark false positives)
detect-secrets audit .secrets.baseline

# Scan for new secrets
detect-secrets scan --baseline .secrets.baseline
```

---

## Pre-Commit Framework Integration

### .pre-commit-config.yaml

```yaml
repos:
  # Gitleaks
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  # detect-secrets
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package-lock.json

  # Custom secret patterns
  - repo: local
    hooks:
      - id: check-secrets
        name: Check for secrets
        entry: scripts/check-secrets.sh
        language: script
        pass_filenames: false
```

### Installation

```bash
# Install pre-commit framework
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

---

## Detection Patterns

### Common Secret Types

| Type | Pattern Example | Gitleaks Rule |
|------|-----------------|---------------|
| AWS Access Key | `AKIA[0-9A-Z]{16}` | `aws-access-token` |
| GitHub Token | `ghp_[0-9a-zA-Z]{36}` | `github-pat` |
| Private Key | `-----BEGIN PRIVATE KEY-----` | `private-key` |
| JWT | `eyJ[A-Za-z0-9-_=]+\.eyJ[A-Za-z0-9-_=]+\.?` | `jwt` |
| Password in URL | `https://user:pass@example.com` | `uri` |
| Generic API Key | `api[_-]?key[_-]?=.{20,}` | `generic-api-key` |

### Custom Gitleaks Rules

Create `.gitleaks.toml`:

```toml
# Extend default rules
[extend]
useDefault = true

# Add custom rule
[[rules]]
id = "internal-api-key"
description = "Internal API Key"
regex = '''internal[_-]?api[_-]?key\s*[:=]\s*['"]?([a-zA-Z0-9]{32,})['"]?'''
keywords = ["internal_api_key", "internal-api-key"]

[[rules]]
id = "database-password"
description = "Database Password"
regex = '''db[_-]?pass(?:word)?\s*[:=]\s*['"]?([^'"\s]+)['"]?'''
keywords = ["db_password", "db-pass", "database_password"]
```

### Allowlist False Positives

In `.gitleaks.toml`:

```toml
[allowlist]
description = "Allowlist for false positives"
paths = [
  '''\.env\.example$''',
  '''\.env\.template$''',
  '''tests/fixtures/.*'''
]

regexes = [
  '''EXAMPLE_API_KEY''',
  '''YOUR_API_KEY_HERE'''
]
```

---

## .gitignore Patterns

### Comprehensive .gitignore

```gitignore
# Environment files
.env
.env.*
!.env.example
!.env.template

# Credential files
*.key
*.pem
*.p12
*.pfx
*.cer
*.crt
*.der
id_rsa
id_dsa
id_ecdsa
id_ed25519

# Config with secrets
secrets.yaml
secrets.yml
*-secrets.yaml
*-secrets.yml
credentials.json
*-credentials.json

# Cloud provider credentials
.aws/credentials
.aws/config
.gcp/credentials.json
.azure/credentials

# Database files
*.db
*.sqlite
*.sqlite3
*.db-wal
*.db-shm

# Certificate stores
*.jks
*.keystore
*.truststore

# Terraform
*.tfstate
*.tfstate.backup
.terraform/
terraform.tfvars

# Kubernetes
*-secret.yaml
*-secret.yml
kubeconfig

# Docker
docker-compose.override.yml
.dockerignore

# IDE files with secrets
.vscode/settings.json
.idea/workspace.xml
```

---

## Scanning Git History

### Scan Entire History

```bash
# Gitleaks
gitleaks detect --source . --verbose --report-path gitleaks-report.json

# TruffleHog
trufflehog git file://. --only-verified --json > trufflehog-report.json

# detect-secrets
detect-secrets scan --all-files > history-scan.json
```

### Scan Commit Range

```bash
# Gitleaks (commits from main to feature branch)
gitleaks detect --log-opts="main..feature-branch"

# TruffleHog
trufflehog git file://. --since-commit main --only-verified
```

### Scan Specific File History

```bash
# Show all versions of file
git log --all --full-history -- path/to/file.env

# Check each version
git show <commit>:path/to/file.env | gitleaks detect --no-git
```

---

## Remediation: Removing Secrets from History

**CRITICAL**: Once committed, secrets are in git history forever (until rewritten). Assume leaked secrets are compromised.

### Step 1: Revoke Secret Immediately

Before removing from history, revoke the credential:
- Rotate API keys
- Regenerate tokens
- Change passwords
- Invalidate certificates

### Step 2: Use BFG Repo Cleaner (Recommended)

```bash
# Install BFG
brew install bfg  # macOS
# or download jar from https://rtyley.github.io/bfg-repo-cleaner/

# Clone fresh copy
git clone --mirror git@github.com:org/repo.git repo-mirror.git

# Remove secrets
bfg --replace-text secrets.txt repo-mirror.git

# secrets.txt contains:
# PASSWORD1           # Literal string
# regex:api[_-]?key=.{20,}  # Regex pattern

# Clean up
cd repo-mirror.git
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push
git push --force
```

### Step 3: Alternative - git-filter-repo

```bash
# Install
pip3 install git-filter-repo

# Remove file from all history
git filter-repo --path secrets.yaml --invert-paths

# Replace text in all history
git filter-repo --replace-text <(echo "PASSWORD=secret==>PASSWORD=REDACTED")

# Force push
git push --force --all
git push --force --tags
```

### Step 4: Notify Team

After force push:
```bash
# Everyone must re-clone
git clone git@github.com:org/repo.git repo-clean

# Or reset existing clones
git fetch origin
git reset --hard origin/main
git clean -fdx
```

---

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/secret-scan.yml
name: Secret Scan

on: [push, pull_request]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }} # Optional for pro

      - name: Upload SARIF
        if: failure()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

### Gitea Actions

```yaml
# .gitea/workflows/secret-scan.yml
name: Secret Scan

on: [push, pull_request]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install Gitleaks
        run: |
          wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
          tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
          chmod +x gitleaks

      - name: Run Gitleaks
        run: ./gitleaks detect --source . --verbose --no-git
```

---

## Custom Secret Check Script

```bash
#!/bin/bash
# scripts/check-secrets.sh
# Check for common secret patterns

set -e

ERRORS=0

# Check for .env files not in .gitignore
if git ls-files | grep -E '\.env$' | grep -v '\.env\.example'; then
  echo "❌ .env file found in git (should be .gitignored)"
  ERRORS=$((ERRORS + 1))
fi

# Check for private keys
if git diff --cached --name-only | xargs grep -l "BEGIN PRIVATE KEY" 2>/dev/null; then
  echo "❌ Private key detected in staged files"
  ERRORS=$((ERRORS + 1))
fi

# Check for AWS keys
if git diff --cached | grep -E "AKIA[0-9A-Z]{16}"; then
  echo "❌ AWS access key detected"
  ERRORS=$((ERRORS + 1))
fi

# Check for passwords in code
if git diff --cached | grep -iE "password\s*=\s*['\"][^'\"]+['\"]"; then
  echo "❌ Hardcoded password detected"
  ERRORS=$((ERRORS + 1))
fi

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "Secret scan failed. Commit blocked."
  exit 1
fi

echo "✅ No secrets detected"
exit 0
```

---

## Monitoring for Public Leaks

### GitHub Secret Scanning (Public Repos)

GitHub automatically scans public repos and notifies maintainers:
- Settings → Code security and analysis → Secret scanning
- Alerts appear in Security tab
- Partners (AWS, Stripe, etc.) are notified automatically

### Third-Party Monitoring

- **GitGuardian**: SaaS secret scanning (free for public repos)
- **Spectral**: Real-time secret detection
- **TruffleHog Enterprise**: Continuous monitoring

---

**Last Updated**: 2026-02-16
