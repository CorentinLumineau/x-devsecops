# History Navigation Reference

Advanced techniques for navigating, searching, and analyzing git history.

---

## Git Bisect (Binary Search for Bugs)

### Basic Bisect Workflow

```bash
# 1. Start bisect
git bisect start

# 2. Mark current commit as bad (bug present)
git bisect bad

# 3. Mark known-good commit (bug absent)
git bisect good v1.0.0

# Git checks out midpoint commit
# Test for bug

# 4. Mark current commit
git bisect bad   # Bug present
# or
git bisect good  # Bug absent

# Git checks out next commit
# Repeat until git identifies first bad commit

# 5. End bisect
git bisect reset
```

### Automated Bisect

Use script to test automatically:

```bash
#!/bin/bash
# test-for-bug.sh
# Exit 0 if good, 1 if bad

npm install --silent
npm test | grep -q "specific test name"
exit $?
```

Run bisect:
```bash
git bisect start HEAD v1.0.0
git bisect run ./test-for-bug.sh

# Git automatically finds first bad commit
```

### Bisect with Skip

```bash
# If commit can't be tested (doesn't compile)
git bisect skip

# Skip range of commits
git bisect skip v1.0.0..v1.1.0
```

### Bisect Visualization

```bash
# View bisect progress
git bisect visualize

# Or with custom log format
git bisect visualize --oneline --graph
```

### Bisect Terms (Custom Labels)

```bash
# Use custom terms instead of good/bad
git bisect start --term-old=working --term-new=broken

git bisect broken   # Current commit is broken
git bisect working  # Commit works
```

---

## Git Blame (Line Attribution)

### Basic Blame

```bash
# Blame entire file
git blame file.txt

# Output format:
# abc123 (John Doe 2026-01-15 10:30:00 +0000 10) line of code
```

### Blame Specific Lines

```bash
# Blame lines 10-20
git blame -L 10,20 file.txt

# Blame from line 10 to end
git blame -L 10, file.txt

# Blame function (if language supported)
git blame -L :function_name file.txt
```

### Blame Options

```bash
# Show email instead of name
git blame -e file.txt

# Show long commit hash
git blame -l file.txt

# Ignore whitespace changes
git blame -w file.txt

# Show line numbers
git blame -n file.txt

# Suppress author name (show commit only)
git blame -s file.txt
```

### Ignore Revisions

Ignore formatting commits (e.g., Prettier, Black):

```bash
# Create .git-blame-ignore-revs
cat > .git-blame-ignore-revs << 'EOF'
# Prettier formatting
abc123def456

# Black formatting
def456ghi789
EOF

# Blame ignoring these commits
git blame --ignore-revs-file .git-blame-ignore-revs file.txt

# Configure globally
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

### Blame with Copy/Move Detection

```bash
# Detect moved lines
git blame -M file.txt

# Detect copied lines
git blame -C file.txt

# Detect copied lines from all commits
git blame -CCC file.txt
```

---

## Git Log (Commit History)

### Basic Log Formats

```bash
# Standard log
git log

# One-line format
git log --oneline

# Graph view
git log --graph --oneline --all

# Custom format
git log --pretty=format:"%h - %an, %ar : %s"
# %h = short hash
# %an = author name
# %ar = author date (relative)
# %s = subject
```

### Filter by Author

```bash
# Commits by specific author
git log --author="John Doe"

# Multiple authors (regex)
git log --author="John\|Jane"

# Commits by committer
git log --committer="John Doe"
```

### Filter by Date

```bash
# Since specific date
git log --since="2026-01-01"
git log --after="2026-01-01"

# Before specific date
git log --until="2026-02-01"
git log --before="2026-02-01"

# Relative dates
git log --since="2 weeks ago"
git log --since="3 days ago"
git log --since="1 month ago"

# Date range
git log --since="2026-01-01" --until="2026-02-01"
```

### Search Commit Messages

```bash
# Commits with "bug fix" in message
git log --grep="bug fix"

# Case-insensitive search
git log --grep="bug fix" -i

# Commits NOT matching pattern
git log --grep="bug fix" --invert-grep

# Multiple patterns (OR)
git log --grep="bug" --grep="fix"

# Multiple patterns (AND)
git log --grep="bug" --grep="fix" --all-match
```

### Search Code Changes (Pickaxe)

```bash
# Commits that added or removed "function_name"
git log -S "function_name"

# Case-sensitive regex search
git log -G "function_\w+"

# Show diffs with pickaxe results
git log -S "function_name" -p
```

### Filter by File

```bash
# Commits affecting specific file
git log file.txt

# Follow file through renames
git log --follow file.txt

# Commits affecting files in directory
git log src/

# Commits affecting multiple files
git log file1.txt file2.txt
```

### Show File Changes

```bash
# List changed files
git log --name-only

# Show file status (Added, Modified, Deleted)
git log --name-status

# Show diff statistics
git log --stat

# Show full patches
git log -p

# Limit patch output
git log -p -2  # Last 2 commits
```

### Limit Output

```bash
# Last 10 commits
git log -10

# Skip first 5 commits
git log --skip=5 -10

# Commits in range
git log abc123..def456

# Commits on branch but not on main
git log main..feature-branch

# Commits on either branch but not both
git log main...feature-branch
```

### Merge Commits

```bash
# Show only merge commits
git log --merges

# Hide merge commits
git log --no-merges

# Show first parent only (linear history)
git log --first-parent
```

---

## Git Reflog (Reference Log)

Reflog records all updates to HEAD and branch references.

### View Reflog

```bash
# Show reflog for HEAD
git reflog

# Output:
# abc123 HEAD@{0}: commit: feat: add feature
# def456 HEAD@{1}: reset: moving to HEAD~1
# ghi789 HEAD@{2}: commit: fix: bug fix
```

### Reflog for Specific Ref

```bash
# Reflog for branch
git reflog show main

# Reflog for remote branch
git reflog show origin/main

# Reflog for tag
git reflog show v1.0.0
```

### Recover Lost Commits

**Scenario**: Accidentally reset branch.

```bash
# Before reset
git log --oneline
# abc123 feat: important feature
# def456 fix: bug fix

# Oops, reset too far
git reset --hard HEAD~2

# Now commit abc123 is "lost"
git log --oneline
# (doesn't show abc123)

# Find commit in reflog
git reflog
# abc123 HEAD@{1}: commit: feat: important feature

# Recover commit
git cherry-pick abc123
# or
git reset --hard abc123
```

### Recover Deleted Branch

```bash
# Deleted branch
git branch -D feature-branch

# Find branch tip in reflog
git reflog
# abc123 HEAD@{3}: checkout: moving from feature-branch to main

# Recreate branch
git checkout -b feature-branch abc123
```

### Time-Based Reflog Queries

```bash
# Show reflog from 2 days ago
git reflog show HEAD@{2.days.ago}

# Show reflog at specific time
git reflog show HEAD@{2026-01-15.12:00:00}

# Show reflog entries from last week
git reflog show --since="1 week ago"
```

### Reflog Expiration

```bash
# Reflog entries expire after 90 days (default)
git config --global gc.reflogExpire 90

# Expire unreachable entries after 30 days
git config --global gc.reflogExpireUnreachable 30

# Manually expire reflog
git reflog expire --expire=30.days.ago --all
```

---

## Git Show (View Objects)

### Show Commit

```bash
# Show commit details
git show abc123

# Show specific file in commit
git show abc123:path/to/file.txt

# Show file from HEAD
git show HEAD:file.txt
```

### Show Tag

```bash
# Show tag details
git show v1.0.0

# Show tag message only
git tag -l -n v1.0.0
```

### Show Stash

```bash
# Show stash entry
git stash show stash@{0}

# Show stash with diff
git stash show -p stash@{0}
```

---

## Git Diff for History

### Compare Commits

```bash
# Diff between two commits
git diff abc123 def456

# Diff between commit and working directory
git diff abc123

# Diff between commit and HEAD
git diff abc123 HEAD
```

### Compare Branches

```bash
# Diff between branches
git diff main feature-branch

# Changes on feature not in main
git diff main...feature-branch

# Files that differ
git diff main feature-branch --name-only
```

### Compare with Remote

```bash
# Diff local vs remote
git diff main origin/main

# Files that differ
git diff main origin/main --name-only
```

---

## Advanced History Analysis

### Find When Line Was Added

```bash
# Blame with log (shows when line was introduced)
git log -S "specific line" --source --all
```

### Find Commits by File Pattern

```bash
# Commits that modified any .js file
git log --all -- "*.js"

# Commits that modified files matching pattern
git log --all -- "*test*"
```

### Show Commit Tree

```bash
# ASCII tree
git log --graph --oneline --all

# With decoration
git log --graph --oneline --all --decorate

# Custom tree format
git log --graph --pretty=format:'%C(yellow)%h%Creset -%C(bold blue)%d%Creset %s %C(green)(%cr) %C(bold)<%an>%Creset' --abbrev-commit
```

### Find Commits Touching Lines

```bash
# Find all commits that touched lines 10-20
git log -L 10,20:file.txt

# Find commits touching function
git log -L :function_name:file.js
```

### Statistics

```bash
# Contribution stats
git shortlog -sn

# Contribution stats (last month)
git shortlog -sn --since="1 month ago"

# Files changed most often
git log --pretty=format: --name-only | sort | uniq -c | sort -rg | head -10
```

---

## Useful Aliases

Add to `~/.gitconfig`:

```ini
[alias]
  # History visualization
  lg = log --graph --oneline --all --decorate

  # Find commits by message
  find = log --grep

  # Show who changed file
  who = shortlog -sn --

  # Show what changed in commit
  what = show --stat

  # Pickaxe search
  search = log -S

  # Better blame
  praise = blame -w -C -C -C
```

Usage:
```bash
git lg
git find "bug fix"
git who src/
git search "API_KEY"
```

---

**Last Updated**: 2026-02-16
