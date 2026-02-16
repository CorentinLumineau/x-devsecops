# PR Operations Reference

Pull request lifecycle management across GitHub and Gitea forges.

---

## PR Lifecycle Stages

```
Create → Review → CI Check → Merge → Cleanup
   ↓        ↓         ↓         ↓        ↓
 Draft   Request    Monitor   Squash   Delete
         Review     Status            Branch
```

---

## 1. PR Creation

### GitHub (gh)

```bash
# Basic PR creation
gh pr create --title "feat: add feature X" --body "Description here"

# Draft PR
gh pr create --title "WIP: feature X" --draft

# PR with reviewers
gh pr create --title "feat: X" --reviewer user1,user2

# PR to specific base branch
gh pr create --base develop --title "feat: X"

# PR from issue
gh pr create --issue 42

# Interactive mode
gh pr create --web
```

### Gitea (tea)

```bash
# Basic PR creation
tea pr create --title "feat: add feature X" --body "Description here"

# Draft PR
tea pr create --title "WIP: feature X" --draft

# PR with reviewers
tea pr create --title "feat: X" --assignees user1,user2

# PR to specific base branch
tea pr create --base develop --title "feat: X"

# Interactive mode
tea pr create --interactive
```

### PR Description Templates

Both forges support `.github/pull_request_template.md`:

```markdown
## Summary
Brief description of changes

## Changes
- List of changes
- With bullet points

## Testing
- How to test
- Test cases covered

## Related Issues
Closes #42
Refs #43

## Checklist
- [ ] Tests added
- [ ] Documentation updated
- [ ] Breaking changes noted
```

---

## 2. Review Operations

### Request Review

```bash
# GitHub
gh pr review 42 --approve
gh pr review 42 --comment --body "LGTM"
gh pr review 42 --request-changes --body "Needs changes"

# Gitea
tea pr review 42 --approve
tea pr review 42 --comment --body "LGTM"
tea pr review 42 --reject --body "Needs changes"
```

**Key difference**: GitHub uses `--request-changes`, Gitea uses `--reject`.

### Add Reviewers

```bash
# GitHub
gh pr edit 42 --add-reviewer user1,user2

# Gitea
tea pr edit 42 --add-assignee user1,user2
```

**Key difference**: GitHub has explicit reviewers, Gitea uses assignees.

### Comment on PR

```bash
# GitHub
gh pr comment 42 --body "Please update the docs"

# Gitea
tea pr comment 42 --body "Please update the docs"
```

### Reply to Review Comments

```bash
# GitHub (via API)
gh api repos/:owner/:repo/pulls/42/comments/:comment_id/replies -f body="Fixed"

# Gitea
tea pr comment 42 --body "Fixed (replying to review)"
```

---

## 3. CI Status Checks

### Check CI Status

```bash
# GitHub
gh pr checks 42

# Gitea
tea pr ci 42
```

### Wait for CI to Pass

```bash
# GitHub
gh pr checks 42 --watch

# Gitea (manual polling)
while ! tea pr ci 42 | grep -q "success"; do
  sleep 30
done
```

### CI Integration Patterns

Both forges support status checks via commit status API:

```bash
# Set status (GitHub)
gh api repos/:owner/:repo/statuses/:sha -f state=success -f context=ci/test

# Set status (Gitea via tea API)
tea api repos/:owner/:repo/statuses/:sha -X POST -d '{"state":"success","context":"ci/test"}'
```

---

## 4. Merge Strategies

### Squash Merge

Combines all commits into one.

```bash
# GitHub
gh pr merge 42 --squash --delete-branch

# Gitea
tea pr merge 42 --squash --delete-branch
```

**Use when**: Feature branch has messy commit history.

### Rebase Merge

Replays commits on top of base branch.

```bash
# GitHub
gh pr merge 42 --rebase --delete-branch

# Gitea
tea pr merge 42 --rebase --delete-branch
```

**Use when**: Want to preserve individual commits but linear history.

### Merge Commit

Creates explicit merge commit.

```bash
# GitHub
gh pr merge 42 --merge --delete-branch

# Gitea
tea pr merge 42 --merge --delete-branch
```

**Use when**: Want to preserve branch context and merge history.

### Auto-Merge

Queue PR to merge when CI passes.

```bash
# GitHub
gh pr merge 42 --auto --squash

# Gitea
tea pr merge 42 --auto --squash
```

---

## 5. Cleanup

### Delete Branch After Merge

```bash
# GitHub (manual, if not done via --delete-branch)
git push origin --delete feature/branch-name

# Gitea (same)
git push origin --delete feature/branch-name
```

### Close PR Without Merging

```bash
# GitHub
gh pr close 42 --comment "Closing: approach changed"

# Gitea
tea pr close 42 --comment "Closing: approach changed"
```

### Reopen Closed PR

```bash
# GitHub
gh pr reopen 42

# Gitea
tea pr reopen 42
```

---

## PR State Management

### Convert Draft to Ready

```bash
# GitHub
gh pr ready 42

# Gitea
tea pr ready 42
```

### Mark as Draft Again

```bash
# GitHub (via API)
gh api repos/:owner/:repo/pulls/42 -X PATCH -f draft=true

# Gitea
tea pr edit 42 --draft
```

### Update PR Title/Body

```bash
# GitHub
gh pr edit 42 --title "New title" --body "New description"

# Gitea
tea pr edit 42 --title "New title" --body "New description"
```

---

## Cross-Forge PR Creation Script

```bash
#!/bin/bash
# Forge-agnostic PR creation

TITLE="$1"
BODY="$2"
DRAFT="${3:-false}"

REMOTE_URL=$(git remote get-url origin)

if echo "$REMOTE_URL" | grep -q "github.com"; then
  CMD="gh pr create --title \"$TITLE\" --body \"$BODY\""
  [ "$DRAFT" = "true" ] && CMD="$CMD --draft"
  eval "$CMD"
elif command -v tea &> /dev/null; then
  CMD="tea pr create --title \"$TITLE\" --body \"$BODY\""
  [ "$DRAFT" = "true" ] && CMD="$CMD --draft"
  eval "$CMD"
else
  echo "Error: No forge CLI found"
  exit 1
fi
```

Usage:
```bash
./create-pr.sh "feat: add X" "Description" true
```

---

## PR Labels

### Add Labels

```bash
# GitHub
gh pr edit 42 --add-label "bug,enhancement"

# Gitea
tea pr edit 42 --add-label "bug" --add-label "enhancement"
```

**Key difference**: GitHub accepts comma-separated labels, Gitea requires multiple flags.

### Remove Labels

```bash
# GitHub
gh pr edit 42 --remove-label "bug"

# Gitea
tea pr edit 42 --remove-label "bug"
```

---

## PR Milestones

### Assign to Milestone

```bash
# GitHub
gh pr edit 42 --milestone "v1.0"

# Gitea
tea pr edit 42 --milestone "v1.0"
```

---

## Advanced Operations

### List PR Files

```bash
# GitHub
gh pr view 42 --json files -q '.files[].path'

# Gitea (via API)
tea api repos/:owner/:repo/pulls/42/files | jq -r '.[].filename'
```

### List PR Commits

```bash
# GitHub
gh pr view 42 --json commits -q '.commits[].commit.message'

# Gitea
tea api repos/:owner/:repo/pulls/42/commits | jq -r '.[].commit.message'
```

### Download PR Patch

```bash
# GitHub
gh pr diff 42 > pr-42.patch

# Gitea
tea pr diff 42 > pr-42.patch
```

---

## Common Workflow Patterns

### Feature Branch → PR → Review → Merge

```bash
# 1. Create feature branch
git checkout -b feature/new-feature

# 2. Make changes and commit
git add .
git commit -m "feat: implement new feature"
git push -u origin feature/new-feature

# 3. Create PR
gh pr create --title "feat: new feature" --draft  # or tea

# 4. Mark ready when done
gh pr ready  # or tea

# 5. Request review
gh pr edit --add-reviewer reviewer1  # or tea with --add-assignee

# 6. Wait for CI
gh pr checks --watch  # or tea pr ci (manual polling)

# 7. Merge when approved
gh pr merge --squash --delete-branch  # or tea
```

### Hotfix → Direct Merge

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-bug

# 2. Fix and commit
git add .
git commit -m "fix: critical security bug"
git push -u origin hotfix/critical-bug

# 3. Create PR without draft
gh pr create --title "fix: critical bug"  # or tea

# 4. Merge immediately if urgent
gh pr merge --squash  # or tea
```

---

**Last Updated**: 2026-02-16
