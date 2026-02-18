# Forge-Agnostic Scripts

Ready-to-use scripts for cross-forge automation.

## Forge-Agnostic PR Creation Script

```bash
#!/bin/bash
# Detects forge and creates PR with appropriate CLI

REMOTE_URL=$(git remote get-url origin)

if echo "$REMOTE_URL" | grep -q "github.com"; then
  gh pr create --title "$1" --body "$2" --draft
elif command -v tea &> /dev/null; then
  tea pr create --title "$1" --body "$2" --draft
else
  echo "Error: No forge CLI detected. Install gh or tea."
  exit 1
fi
```

## Multi-Forge CI Status Check

```bash
#!/bin/bash
# Check CI status across forges

REMOTE_URL=$(git remote get-url origin)

if echo "$REMOTE_URL" | grep -q "github.com"; then
  gh pr checks
else
  tea pr ci
fi
```

## PR Workflow Pattern

Cross-forge PR creation follows this pattern:

```bash
# 1. Detect forge
FORGE=$(detect_forge)

# 2. Create PR with equivalent command
if [ "$FORGE" = "github" ]; then
  gh pr create --title "..." --body "..."
elif [ "$FORGE" = "gitea" ]; then
  tea pr create --title "..." --body "..."
fi

# 3. Check CI status
if [ "$FORGE" = "github" ]; then
  gh pr checks
elif [ "$FORGE" = "gitea" ]; then
  tea pr ci
fi

# 4. Merge when ready
if [ "$FORGE" = "github" ]; then
  gh pr merge --squash
elif [ "$FORGE" = "gitea" ]; then
  tea pr merge --squash
fi
```

## Issue Workflow Pattern

Cross-forge issue management:

```bash
# Create issue
gh issue create --title "Bug: ..." --label "bug"      # GitHub
tea issue create --title "Bug: ..." --label "bug"    # Gitea

# Add to milestone
gh issue edit 42 --milestone "v1.0"                   # GitHub
tea issue edit 42 --milestone "v1.0"                  # Gitea

# Close with reference
gh issue close 42 --comment "Fixed in #43"            # GitHub
tea issue close 42 --comment "Fixed in #43"           # Gitea
```
