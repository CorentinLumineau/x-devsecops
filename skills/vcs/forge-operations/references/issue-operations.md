# Issue Operations Reference

Issue lifecycle management and tracking workflows across GitHub and Gitea.

---

## Issue Lifecycle

```
Create → Label → Assign → Implement → Close
   ↓       ↓        ↓          ↓         ↓
Triage  Priority  Owner     PR Link   Verify
```

---

## 1. Issue Creation

### GitHub (gh)

```bash
# Basic issue
gh issue create --title "Bug: app crashes" --body "Steps to reproduce..."

# Issue with labels
gh issue create --title "Bug: crash" --label "bug,priority:high"

# Issue with assignee
gh issue create --title "Feature: X" --assignee user1

# Issue with milestone
gh issue create --title "Bug: Y" --milestone "v1.0"

# Interactive mode
gh issue create --web
```

### Gitea (tea)

```bash
# Basic issue
tea issue create --title "Bug: app crashes" --body "Steps to reproduce..."

# Issue with labels
tea issue create --title "Bug: crash" --labels "bug,priority:high"

# Issue with assignee
tea issue create --title "Feature: X" --assignees user1

# Issue with milestone
tea issue create --title "Bug: Y" --milestone "v1.0"

# Interactive mode
tea issue create --interactive
```

**Key difference**: GitHub uses `--label` (singular), Gitea uses `--labels` (plural).

---

## 2. Issue Templates

Both forges support issue templates in `.github/ISSUE_TEMPLATE/`:

### Bug Report Template

`.github/ISSUE_TEMPLATE/bug_report.md`:

```markdown
---
name: Bug Report
about: Report a bug or unexpected behavior
labels: bug
---

## Description
Brief description of the bug

## Steps to Reproduce
1. Step one
2. Step two
3. See error

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- OS:
- Version:
- Browser:

## Additional Context
Any other relevant information
```

### Feature Request Template

`.github/ISSUE_TEMPLATE/feature_request.md`:

```markdown
---
name: Feature Request
about: Suggest a new feature or enhancement
labels: enhancement
---

## Problem Statement
What problem does this solve?

## Proposed Solution
How should it work?

## Alternatives Considered
What other approaches were considered?

## Additional Context
Mockups, examples, references
```

---

## 3. Label Management

### Create Labels

```bash
# GitHub
gh label create "priority:high" --color FF0000 --description "High priority"

# Gitea
tea label create --name "priority:high" --color FF0000 --description "High priority"
```

### List Labels

```bash
# GitHub
gh label list

# Gitea
tea label list
```

### Add Labels to Issue

```bash
# GitHub (comma-separated)
gh issue edit 42 --add-label "bug,priority:high"

# Gitea (comma-separated)
tea issue edit 42 --add-label "bug,priority:high"
```

### Remove Labels

```bash
# GitHub
gh issue edit 42 --remove-label "bug"

# Gitea
tea issue edit 42 --remove-label "bug"
```

### Recommended Label Taxonomy

| Category | Labels | Color | Purpose |
|----------|--------|-------|---------|
| Type | `bug`, `enhancement`, `docs` | Red, Blue, Green | What kind of issue |
| Priority | `priority:high`, `priority:low` | Orange, Yellow | Urgency level |
| Status | `blocked`, `in-progress`, `needs-info` | Purple, Gray | Current state |
| Area | `frontend`, `backend`, `infra` | Cyan, Magenta | Which component |

---

## 4. Issue Assignment

### Assign User

```bash
# GitHub
gh issue edit 42 --add-assignee user1,user2

# Gitea
tea issue edit 42 --add-assignee user1,user2
```

### Unassign User

```bash
# GitHub
gh issue edit 42 --remove-assignee user1

# Gitea
tea issue edit 42 --remove-assignee user1
```

### Self-Assign

```bash
# GitHub
gh issue edit 42 --add-assignee @me

# Gitea (get username first)
USERNAME=$(tea login list | head -1 | awk '{print $2}')
tea issue edit 42 --add-assignee "$USERNAME"
```

**Key difference**: GitHub supports `@me`, Gitea requires explicit username.

---

## 5. Milestone Operations

### List Milestones

```bash
# GitHub (via API)
gh api repos/:owner/:repo/milestones

# Gitea (native command)
tea milestone list
```

### Create Milestone

```bash
# GitHub (via API)
gh api repos/:owner/:repo/milestones -f title="v1.0" -f due_on="2026-03-01T00:00:00Z"

# Gitea
tea milestone create --title "v1.0" --deadline "2026-03-01"
```

**Key difference**: Gitea has native milestone commands, GitHub requires API calls.

### Assign Issue to Milestone

```bash
# GitHub
gh issue edit 42 --milestone "v1.0"

# Gitea
tea issue edit 42 --milestone "v1.0"
```

### Close Milestone

```bash
# GitHub (via API)
gh api repos/:owner/:repo/milestones/:milestone_number -X PATCH -f state=closed

# Gitea
tea milestone close --name "v1.0"
```

---

## 6. Issue Commenting

### Add Comment

```bash
# GitHub
gh issue comment 42 --body "This is a comment"

# Gitea
tea issue comment 42 --body "This is a comment"
```

### List Comments

```bash
# GitHub
gh issue view 42 --json comments -q '.comments[].body'

# Gitea (via API)
tea api repos/:owner/:repo/issues/42/comments | jq -r '.[].body'
```

---

## 7. Closing Issues

### Close with Comment

```bash
# GitHub
gh issue close 42 --comment "Fixed in #43"

# Gitea
tea issue close 42 --comment "Fixed in #43"
```

### Close via Commit Message

Both forges auto-close issues with keywords in commit messages:

```bash
git commit -m "fix: crash on startup

Closes #42
Fixes #43
Resolves #44"
```

Supported keywords: `Closes`, `Fixes`, `Resolves`, `Close`, `Fix`, `Resolve`.

### Reopen Issue

```bash
# GitHub
gh issue reopen 42

# Gitea
tea issue reopen 42
```

---

## 8. Issue Search and Filtering

### List Open Issues

```bash
# GitHub
gh issue list --state open

# Gitea
tea issue list --state open
```

### List Closed Issues

```bash
# GitHub
gh issue list --state closed

# Gitea
tea issue list --state closed
```

### Filter by Label

```bash
# GitHub
gh issue list --label "bug"

# Gitea
tea issue list --label "bug"
```

### Filter by Assignee

```bash
# GitHub
gh issue list --assignee @me

# Gitea
USERNAME=$(tea login list | head -1 | awk '{print $2}')
tea issue list --assignee "$USERNAME"
```

### Filter by Milestone

```bash
# GitHub
gh issue list --milestone "v1.0"

# Gitea
tea issue list --milestone "v1.0"
```

### Search Issue Text

```bash
# GitHub
gh issue list --search "crash"

# Gitea
tea issue list | grep -i "crash"
```

**Key difference**: GitHub has native search, Gitea requires grep.

---

## 9. Auto-Linking Patterns

Both forges support auto-linking in issue/PR descriptions and comments:

| Pattern | Links To | Example |
|---------|----------|---------|
| `#123` | Issue/PR #123 in current repo | `Fixes #123` |
| `owner/repo#123` | Issue/PR in another repo | `Related to owner/repo#123` |
| `SHA` (7+ chars) | Commit | `Introduced in abc1234` |
| `@username` | User profile | `cc @reviewer1` |

### Cross-Repository References

```markdown
This is related to myorg/other-repo#42
```

### Commit References

```markdown
Introduced in commit abc123def456
```

---

## 10. Issue Workflow Automation

### Triage New Issues Script

```bash
#!/bin/bash
# Auto-label new issues based on title patterns

FORGE=$(detect_forge)  # Use detection from detection-patterns.md

if [ "$FORGE" = "github" ]; then
  LIST_CMD="gh issue list --state open --label triage"
  EDIT_CMD="gh issue edit"
elif [ "$FORGE" = "gitea" ]; then
  LIST_CMD="tea issue list --state open --label triage"
  EDIT_CMD="tea issue edit"
fi

# Get unlabeled issues
$LIST_CMD | while read -r NUM TITLE; do
  if echo "$TITLE" | grep -qi "bug\|crash\|error"; then
    $EDIT_CMD "$NUM" --add-label "bug"
  elif echo "$TITLE" | grep -qi "feature\|enhancement"; then
    $EDIT_CMD "$NUM" --add-label "enhancement"
  fi

  # Remove triage label
  $EDIT_CMD "$NUM" --remove-label "triage"
done
```

### Close Stale Issues

```bash
#!/bin/bash
# Close issues inactive for 90 days

FORGE=$(detect_forge)

if [ "$FORGE" = "github" ]; then
  # GitHub: use updated filter
  gh issue list --state open --json number,updatedAt \
    | jq -r '.[] | select(.updatedAt < (now - 7776000)) | .number' \
    | while read -r NUM; do
        gh issue close "$NUM" --comment "Closing due to inactivity"
      done
elif [ "$FORGE" = "gitea" ]; then
  # Gitea: manual date comparison
  CUTOFF=$(date -d '90 days ago' +%s)
  tea issue list --state open --fields number,updated | while read -r NUM UPDATED; do
    UPDATED_TS=$(date -d "$UPDATED" +%s)
    if [ "$UPDATED_TS" -lt "$CUTOFF" ]; then
      tea issue close "$NUM" --comment "Closing due to inactivity"
    fi
  done
fi
```

---

## 11. Issue-to-PR Workflow

### Link PR to Issue

```bash
# Create PR that references issue
gh pr create --title "Fix crash (fixes #42)" --body "Closes #42"
# or
tea pr create --title "Fix crash (fixes #42)" --body "Closes #42"
```

### Convert Issue to PR (GitHub Only)

```bash
# GitHub
gh pr create --issue 42

# Gitea: not supported (create PR manually with reference)
```

---

## 12. Bulk Operations

### Close Multiple Issues

```bash
# GitHub
for i in 10 11 12; do
  gh issue close "$i" --comment "Duplicate of #9"
done

# Gitea
for i in 10 11 12; do
  tea issue close "$i" --comment "Duplicate of #9"
done
```

### Add Label to Multiple Issues

```bash
# GitHub
for i in 10 11 12; do
  gh issue edit "$i" --add-label "needs-docs"
done

# Gitea
for i in 10 11 12; do
  tea issue edit "$i" --add-label "needs-docs"
done
```

---

## Cross-Forge Issue Creation Script

```bash
#!/bin/bash
# Forge-agnostic issue creation

TITLE="$1"
BODY="$2"
LABELS="$3"

REMOTE_URL=$(git remote get-url origin)

if echo "$REMOTE_URL" | grep -q "github.com"; then
  gh issue create --title "$TITLE" --body "$BODY" --label "$LABELS"
elif command -v tea &> /dev/null; then
  tea issue create --title "$TITLE" --body "$BODY" --labels "$LABELS"
else
  echo "Error: No forge CLI found"
  exit 1
fi
```

Usage:
```bash
./create-issue.sh "Bug: crash" "Crash on startup" "bug,priority:high"
```

---

**Last Updated**: 2026-02-16
