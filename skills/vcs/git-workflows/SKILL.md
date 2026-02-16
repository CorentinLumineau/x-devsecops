---
name: git-workflows
description: Git operations patterns for conflict resolution, rebase strategies, and history navigation.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: vcs
---

# git-workflows

Git operations patterns for conflict resolution, rebase strategies, and history navigation.

---

## 80/20 Focus

| Priority Area | Coverage | Why It Matters |
|--------------|----------|----------------|
| Conflict resolution | 40% | Most common pain point in team workflows |
| Rebase strategies | 30% | Maintain clean history, but dangerous if misused |
| History navigation | 20% | Debug issues, find bugs, understand changes |
| Cherry-pick operations | 10% | Selective commit application across branches |

**Core principle**: Understand when to merge vs rebase, how to safely resolve conflicts, and how to navigate history effectively.

---

## Quick Reference

| Operation | Command | Use Case |
|-----------|---------|----------|
| Merge branch | `git merge feature` | Preserve branch history |
| Rebase branch | `git rebase main` | Linear history |
| Interactive rebase | `git rebase -i HEAD~3` | Clean up commits |
| Resolve conflict (ours) | `git checkout --ours file.txt` | Keep our version |
| Resolve conflict (theirs) | `git checkout --theirs file.txt` | Keep their version |
| Find bug commit | `git bisect start` | Binary search for bug |
| Blame line | `git blame -L 10,20 file.txt` | Who changed these lines |
| Cherry-pick commit | `git cherry-pick abc123` | Apply specific commit |
| Recover lost commit | `git reflog` | Find lost commits |

---

## Merge vs Rebase Decision Tree

```
Need to integrate changes?
  ↓
Is branch shared with others?
  ↓ YES → MERGE (safe, preserves history)
  ↓ NO  → Continue
  ↓
Want linear history?
  ↓ YES → REBASE (rewrites history)
  ↓ NO  → MERGE (preserves branch context)
  ↓
Integrating from upstream?
  ↓ YES → REBASE (keep feature branch up-to-date)
  ↓ NO  → MERGE (integrating feature into main)
```

**Golden rule**: Never rebase commits that have been pushed to a shared branch.

---

## Conflict Resolution

### Conflict Types

#### 1. Merge Conflict

Occurs when: Same lines modified in both branches.

```bash
# During merge
git merge feature-branch

# Output:
# Auto-merging file.txt
# CONFLICT (content): Merge conflict in file.txt
# Automatic merge failed; fix conflicts and then commit the result.
```

**Conflict markers**:

```
<<<<<<< HEAD
Current branch content
=======
Incoming branch content
>>>>>>> feature-branch
```

#### 2. Rebase Conflict

Occurs when: Replaying commits on new base.

```bash
git rebase main

# Output:
# CONFLICT (content): Merge conflict in file.txt
# error: could not apply abc123... commit message
```

**Resolution**: Fix conflict, then `git rebase --continue`.

#### 3. Cherry-Pick Conflict

Occurs when: Applying commit to different context.

```bash
git cherry-pick abc123

# Output:
# CONFLICT (content): Merge conflict in file.txt
```

**Resolution**: Fix conflict, then `git cherry-pick --continue`.

### Resolution Strategies

#### Strategy 1: Manual Resolution

```bash
# 1. View conflict
git status
git diff

# 2. Edit file, remove markers, keep desired content
vim file.txt

# 3. Mark as resolved
git add file.txt

# 4. Complete merge/rebase
git commit  # for merge
git rebase --continue  # for rebase
```

#### Strategy 2: Accept Ours

```bash
# Keep current branch version
git checkout --ours file.txt
git add file.txt
git commit
```

**Use when**: Current branch has correct version.

#### Strategy 3: Accept Theirs

```bash
# Keep incoming branch version
git checkout --theirs file.txt
git add file.txt
git commit
```

**Use when**: Incoming branch has correct version.

#### Strategy 4: Merge Tool

```bash
# Launch visual merge tool
git mergetool

# Configure merge tool (one-time)
git config --global merge.tool vimdiff
# or: meld, kdiff3, opendiff, etc.
```

### Abort Operations

```bash
# Abort merge
git merge --abort

# Abort rebase
git rebase --abort

# Abort cherry-pick
git cherry-pick --abort
```

---

## Rebase Strategies

### Interactive Rebase

Clean up commit history before merging:

```bash
# Rebase last 3 commits
git rebase -i HEAD~3

# Opens editor with:
# pick abc123 feat: add feature A
# pick def456 fix typo
# pick ghi789 feat: add feature B
```

### Rebase Commands

| Command | Effect | Use Case |
|---------|--------|----------|
| `pick` | Keep commit as-is | Default |
| `reword` | Change commit message | Fix message typos |
| `edit` | Stop to amend commit | Add forgotten changes |
| `squash` | Combine with previous | Merge related commits |
| `fixup` | Squash, discard message | Remove "fix typo" commits |
| `drop` | Remove commit | Delete unwanted commits |

### Example: Squash Typo Fixes

```bash
# Before rebase:
# pick abc123 feat: add authentication
# pick def456 fix typo in auth
# pick ghi789 fix another typo

# After editing:
pick abc123 feat: add authentication
fixup def456 fix typo in auth
fixup ghi789 fix another typo

# Result: Single commit with all changes
```

### Autosquash Workflow

```bash
# Make initial commit
git commit -m "feat: add authentication"  # abc123

# Oops, forgot something
git add forgotten-file.txt
git commit --fixup abc123

# Later, autosquash during rebase
git rebase -i --autosquash main
# Automatically arranges fixup commits
```

### Rebase Safety Rules

1. **NEVER rebase public branches** - Others may have based work on them
2. **NEVER rebase main/master** - Shared branch
3. **DO rebase feature branches** - Before merging to keep history clean
4. **DO rebase to update feature branch** - `git rebase main` on feature branch

### Rebase vs Merge Example

**Scenario**: Feature branch needs changes from main.

**Option 1: Merge** (preserves history)
```bash
git checkout feature-branch
git merge main
# Creates merge commit
```

**Option 2: Rebase** (linear history)
```bash
git checkout feature-branch
git rebase main
# Replays feature commits on top of main
```

**Recommendation**: Rebase if branch is private, merge if shared.

---

## History Navigation

### Git Bisect (Find Bug)

Binary search to find commit that introduced bug:

```bash
# 1. Start bisect
git bisect start

# 2. Mark current commit as bad
git bisect bad

# 3. Mark known-good commit
git bisect good v1.0.0

# 4. Test each commit git checks out
# If bug present:
git bisect bad
# If bug absent:
git bisect good

# 5. Git identifies first bad commit

# 6. End bisect
git bisect reset
```

**Automated bisect**:

```bash
# Use test script
git bisect start HEAD v1.0.0
git bisect run ./test.sh

# test.sh exits 0 (good) or 1 (bad)
```

### Git Blame (Find Author)

```bash
# Blame entire file
git blame file.txt

# Blame specific lines
git blame -L 10,20 file.txt

# Ignore whitespace changes
git blame -w file.txt

# Ignore specific commits (e.g., reformatting)
git blame --ignore-rev abc123 file.txt

# Blame with commit details
git blame -l file.txt
```

### Git Log (History Analysis)

```bash
# View commit history
git log

# One-line format
git log --oneline

# Graph view
git log --graph --oneline --all

# Filter by author
git log --author="John Doe"

# Filter by date
git log --since="2 weeks ago"
git log --after="2026-01-01" --before="2026-02-01"

# Search commit messages
git log --grep="bug fix"

# Search code changes (pickaxe)
git log -S "function_name"

# Follow file renames
git log --follow file.txt

# Show files changed
git log --name-only

# Show diff statistics
git log --stat

# Show patches
git log -p
```

### Git Reflog (Recover Lost Commits)

Reflog records all ref updates:

```bash
# View reflog
git reflog

# Output:
# abc123 HEAD@{0}: commit: feat: add feature
# def456 HEAD@{1}: reset: moving to HEAD~1
# ghi789 HEAD@{2}: commit: fix: bug fix

# Recover lost commit
git checkout ghi789
git cherry-pick ghi789
# or
git reset --hard ghi789
```

**Use cases**:
- Recover from `git reset --hard`
- Recover deleted branch
- Undo rebase gone wrong

---

## Cherry-Pick Operations

### Basic Cherry-Pick

```bash
# Apply specific commit to current branch
git cherry-pick abc123

# Apply multiple commits
git cherry-pick abc123 def456 ghi789

# Apply commit range
git cherry-pick abc123..ghi789
```

### When to Cherry-Pick

| Scenario | Use Cherry-Pick? |
|----------|------------------|
| Hotfix from feature to main | ✓ Yes |
| Backport fix to old version | ✓ Yes |
| Merge entire feature branch | ✗ No, use merge |
| Undo commit | ✗ No, use revert |

### Cherry-Pick with Conflicts

```bash
# Start cherry-pick
git cherry-pick abc123

# If conflict:
# 1. Resolve conflict
vim file.txt
git add file.txt

# 2. Continue cherry-pick
git cherry-pick --continue

# Or abort
git cherry-pick --abort
```

### Cherry-Pick Options

```bash
# Keep original author
git cherry-pick abc123

# Change commit message
git cherry-pick abc123 --edit

# Don't commit immediately (stage only)
git cherry-pick abc123 --no-commit

# Add sign-off
git cherry-pick abc123 --signoff
```

---

## When to Load References

| Reference | Load When | Use Case |
|-----------|-----------|----------|
| `conflict-resolution.md` | Facing merge/rebase conflicts | Detailed conflict resolution strategies |
| `history-navigation.md` | Debugging or investigating changes | Bisect, blame, log, reflog techniques |
| `rebase-patterns.md` | Cleaning up commit history | Interactive rebase, autosquash, safety |

---

## Related Skills

- **vcs-conventional-commits** - Commit message format for clean history
- **vcs-forge-operations** - PR operations that trigger merges
- **security-git** - GPG signing for verified history

---

## Common Pitfalls

1. **Rebasing public branches** - Breaks history for collaborators
2. **Force pushing without coordination** - `git push --force` can lose others' work
3. **Using `git reset --hard` without backup** - Lose uncommitted changes
4. **Not testing after conflict resolution** - Broken merge can pass unnoticed
5. **Cherry-picking without context** - Commit may not work in different branch
6. **Forgetting to continue rebase** - Repository stuck in rebase state
7. **Merging without reviewing changes** - `git merge --no-ff` skips verification

---

## Best Practices

### Merge Best Practices

```bash
# 1. Update main branch
git checkout main
git pull

# 2. Checkout feature branch
git checkout feature-branch

# 3. Merge main into feature (test integration)
git merge main

# 4. Test thoroughly
npm test

# 5. Push feature branch
git push

# 6. Create PR (via forge CLI)
gh pr create --title "feat: new feature"

# 7. Merge PR (after review)
gh pr merge --squash
```

### Rebase Best Practices

```bash
# 1. Update main
git checkout main
git pull

# 2. Rebase feature branch
git checkout feature-branch
git rebase main

# 3. Fix conflicts if any
# 4. Force push (only if branch is not shared)
git push --force-with-lease

# 5. Create PR
gh pr create

# Prefer --force-with-lease over --force
# (prevents overwriting others' changes)
```

### Conflict Resolution Best Practices

1. **Understand both sides** - Read conflict markers, understand intent
2. **Test after resolution** - Run tests to verify merge is correct
3. **Keep communication open** - Discuss with other developer if unclear
4. **Use merge tool for complex conflicts** - Visual diff helps
5. **Commit descriptive message** - Explain resolution reasoning

---

## Advanced Techniques

### Rebase onto Different Base

```bash
# Move feature branch from old-main to new-main
git rebase --onto new-main old-main feature-branch
```

### Preserve Merge Commits During Rebase

```bash
# Keep merge commits (useful for complex histories)
git rebase --rebase-merges main
```

### Partial Cherry-Pick

```bash
# Apply only specific files from commit
git checkout abc123 -- file1.txt file2.txt
git commit -m "Partial cherry-pick of abc123"
```

---

**Version**: 1.0.0 | **Category**: vcs | **License**: Apache-2.0
