# Forge Detection Patterns

Algorithms and heuristics for auto-detecting GitHub vs Gitea from repository context.

---

## Detection Priority Order

1. **Remote URL parsing** (highest priority)
2. **Domain pattern matching**
3. **API endpoint probing**
4. **CLI availability check**
5. **User configuration fallback**

---

## URL Parsing Algorithm

### SSH URL Formats

```
# GitHub SSH
git@github.com:owner/repo.git

# Gitea SSH (custom domain)
git@git.example.com:owner/repo.git

# Gitea SSH (with port)
git@git.example.com:2222/owner/repo.git
```

### HTTPS URL Formats

```
# GitHub HTTPS
https://github.com/owner/repo.git

# Gitea HTTPS
https://git.example.com/owner/repo.git

# Gitea HTTPS (with port)
https://git.example.com:3000/owner/repo.git
```

### Extraction Code

```bash
#!/bin/bash
# Extract domain from git remote URL

REMOTE_URL=$(git remote get-url origin 2>/dev/null)

if [ -z "$REMOTE_URL" ]; then
  echo "Error: No remote URL found"
  exit 1
fi

# Parse SSH format: git@domain:path or git@domain:port/path
if echo "$REMOTE_URL" | grep -q "^git@"; then
  DOMAIN=$(echo "$REMOTE_URL" | sed 's/git@\([^:]*\):.*/\1/')
# Parse HTTPS format: https://domain/path or https://domain:port/path
elif echo "$REMOTE_URL" | grep -q "^https://"; then
  DOMAIN=$(echo "$REMOTE_URL" | sed 's|https://\([^:/]*\).*|\1|')
else
  echo "Error: Unrecognized URL format"
  exit 1
fi

echo "$DOMAIN"
```

---

## Domain Matching Heuristics

### Known GitHub Domains

```
github.com           → GitHub (primary)
ghe.example.com      → GitHub Enterprise (if known)
```

### Gitea Detection

Any domain that is:
- **NOT** `github.com`
- **AND** responds to Gitea API endpoint probe

### Domain Pattern Table

| Domain Pattern | Likely Forge | Confidence |
|----------------|--------------|------------|
| `github.com` | GitHub | 100% |
| `*.github.com` | GitHub Enterprise Cloud | 95% |
| `ghe.*` | GitHub Enterprise | 80% |
| `git.*` | Gitea/Forgejo | 70% |
| `gitea.*` | Gitea | 95% |
| `*.*.com` (other) | Unknown, probe API | 0% |

---

## API Endpoint Probing

### Gitea API Probe

```bash
#!/bin/bash
# Probe for Gitea API endpoint

DOMAIN="$1"
API_URL="https://${DOMAIN}/api/v1/version"

# Attempt to fetch Gitea version info
RESPONSE=$(curl -s "$API_URL")

if echo "$RESPONSE" | grep -q "version"; then
  echo "Gitea detected"
  exit 0
else
  echo "Not Gitea"
  exit 1
fi
```

### Forgejo API Probe

Forgejo uses the same API as Gitea (`/api/v1/version`), so Gitea detection works for Forgejo too.

### GitHub API Probe

```bash
#!/bin/bash
# Probe for GitHub API (usually unnecessary if domain is github.com)

DOMAIN="$1"
API_URL="https://api.${DOMAIN}/meta"

RESPONSE=$(curl -s "$API_URL")

if echo "$RESPONSE" | grep -q "verifiable_password_authentication"; then
  echo "GitHub detected"
  exit 0
else
  echo "Not GitHub"
  exit 1
fi
```

---

## CLI Availability Check

### Check for Installed Tools

```bash
#!/bin/bash
# Detect which forge CLIs are available

if command -v gh &> /dev/null; then
  echo "gh (GitHub CLI) is installed"
fi

if command -v tea &> /dev/null; then
  echo "tea (Gitea CLI) is installed"
fi

if command -v glab &> /dev/null; then
  echo "glab (GitLab CLI) is installed (not supported)"
fi
```

### CLI Authentication Status

```bash
#!/bin/bash
# Check if CLI is authenticated

# GitHub
if gh auth status &> /dev/null; then
  echo "gh is authenticated"
fi

# Gitea
if tea login list | grep -q "^-"; then
  echo "tea has configured logins"
fi
```

---

## Complete Detection Function

```bash
#!/bin/bash
# Complete forge detection with fallback

detect_forge() {
  # Step 1: Extract domain from git remote
  REMOTE_URL=$(git remote get-url origin 2>/dev/null)

  if [ -z "$REMOTE_URL" ]; then
    echo "Error: Not a git repository or no remote found" >&2
    return 1
  fi

  # Parse domain
  if echo "$REMOTE_URL" | grep -q "^git@"; then
    DOMAIN=$(echo "$REMOTE_URL" | sed 's/git@\([^:]*\):.*/\1/')
  elif echo "$REMOTE_URL" | grep -q "^https://"; then
    DOMAIN=$(echo "$REMOTE_URL" | sed 's|https://\([^:/]*\).*|\1|')
  else
    echo "Error: Unrecognized URL format" >&2
    return 1
  fi

  # Step 2: Match known domains
  if [ "$DOMAIN" = "github.com" ]; then
    echo "github"
    return 0
  fi

  # Step 3: Probe for Gitea API
  if curl -sf "https://${DOMAIN}/api/v1/version" > /dev/null; then
    echo "gitea"
    return 0
  fi

  # Step 4: Check for GitHub Enterprise (less common)
  if curl -sf "https://api.${DOMAIN}/meta" > /dev/null; then
    echo "github"
    return 0
  fi

  # Fallback: Unknown
  echo "unknown"
  return 1
}

# Usage
FORGE=$(detect_forge)
echo "Detected forge: $FORGE"
```

---

## Known Domain Patterns

### GitHub Patterns

```
github.com                           # Public GitHub
ghe.mycompany.com                   # GitHub Enterprise (custom domain)
github.enterprise.example.com       # GitHub Enterprise
```

### Gitea Patterns

```
gitea.com                            # Gitea's own instance
git.example.com                      # Common self-hosted pattern
code.example.com                     # Alternative self-hosted
gitea.internal.corp                  # Internal corporate
```

### Forgejo Patterns

```
forgejo.example.com                  # Self-hosted Forgejo
code.example.com                     # Shares pattern with Gitea
```

**Note**: Forgejo is a Gitea fork and uses identical API, so detection treats it as Gitea.

---

## Fallback Strategy

If no forge can be detected:

1. **Prompt user** - Ask which forge they're using
2. **Check .git/config** - Look for forge-specific config
3. **Default to git-only** - Fall back to standard git commands
4. **Suggest CLI installation** - If appropriate CLI is missing

### Example Fallback Prompt

```bash
if [ "$FORGE" = "unknown" ]; then
  echo "Unable to detect forge type for $DOMAIN"
  echo "Which forge are you using?"
  echo "1) GitHub"
  echo "2) Gitea/Forgejo"
  read -p "Choice (1-2): " CHOICE

  case $CHOICE in
    1) FORGE="github" ;;
    2) FORGE="gitea" ;;
    *) echo "Invalid choice"; exit 1 ;;
  esac
fi
```

---

## CLI Installation Suggestions

### When gh is needed but missing

```
GitHub CLI not found. Install:
- macOS: brew install gh
- Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
- Windows: https://cli.github.com
```

### When tea is needed but missing

```
Gitea CLI not found. Install:
- Binary: https://gitea.com/gitea/tea/releases
- macOS: brew tap gitea/tap && brew install tea
- Linux: Download from releases page
```

---

## Error Handling

### No Remote URL

```bash
if ! git remote get-url origin &> /dev/null; then
  echo "Error: No git remote 'origin' found"
  echo "Add remote: git remote add origin <url>"
  exit 1
fi
```

### Network Timeout

```bash
# Use timeout for API probes
if ! timeout 3 curl -sf "https://${DOMAIN}/api/v1/version" > /dev/null; then
  echo "Warning: Unable to reach $DOMAIN (network timeout)"
  echo "Falling back to domain pattern matching"
fi
```

### Authentication Required

```bash
# Check if API requires auth
RESPONSE=$(curl -s "https://${DOMAIN}/api/v1/version")
if echo "$RESPONSE" | grep -q "401"; then
  echo "Warning: API requires authentication"
  echo "Assuming Gitea/Forgejo based on API structure"
fi
```

---

## Cache Detection Result

For performance, cache the detection result:

```bash
# Cache in .git/config
git config --local forge.type "github"

# Retrieve cached value
CACHED_FORGE=$(git config --local forge.type)
if [ -n "$CACHED_FORGE" ]; then
  echo "$CACHED_FORGE"
  exit 0
fi
```

---

**Last Updated**: 2026-02-16
