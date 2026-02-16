# Rebase Patterns Reference

Interactive rebase workflows, autosquash, safety rules, and advanced rebase techniques.

---

## Interactive Rebase Commands

### Rebase Command Reference

| Command | Shortcut | Effect | Use Case |
|---------|----------|--------|----------|
| `pick` | `p` | Use commit as-is | Default, keep commit |
| `reword` | `r` | Change commit message | Fix typos, improve clarity |
| `edit` | `e` | Stop to amend commit | Add forgotten changes |
| `squash` | `s` | Merge with previous | Combine related commits |
| `fixup` | `f` | Merge, discard message | Remove "fix typo" commits |
| `drop` | `d` | Delete commit | Remove unwanted commits |
| `exec` | `x` | Run shell command | Test each commit |
| `break` | `b` | Pause rebase | Manual intervention point |
| `label` | `l` | Name a commit | For merge preserving |
| `reset` | `t` | Reset to label | For merge preserving |
| `merge` | `m` | Create merge commit | Preserve merge structure |

---

## Basic Interactive Rebase

### Rebase Last N Commits

```bash
# Rebase last 3 commits
git rebase -i HEAD~3

# Opens editor with:
pick abc123 feat: add authentication
pick def456 fix typo in auth
pick ghi789 feat: add authorization
```

### Rebase from Specific Commit

```bash
# Rebase all commits after abc123
git rebase -i abc123
```

### Rebase Entire Branch

```bash
# Rebase all commits in feature branch
git rebase -i main
```

---

## Squashing Commits

### Squash (Combine Messages)

```bash
# Before:
pick abc123 feat: add authentication
pick def456 add tests for auth
pick ghi789 fix auth bug

# Change to:
pick abc123 feat: add authentication
squash def456 add tests for auth
squash ghi789 fix auth bug

# Result: Single commit with combined message
```

Git prompts to edit combined message:

```
# This is a combination of 3 commits.
# This is the 1st commit message:

feat: add authentication

# This is the commit message #2:

add tests for auth

# This is the commit message #3:

fix auth bug

# Edit to:
feat: add authentication

Includes tests and bug fixes.
```

### Fixup (Discard Message)

```bash
# Before:
pick abc123 feat: add authentication
pick def456 fix typo
pick ghi789 fix another typo

# Change to:
pick abc123 feat: add authentication
fixup def456 fix typo
fixup ghi789 fix another typo

# Result: Single commit with only first message
```

---

## Autosquash Workflow

### Create Fixup Commits

```bash
# Initial commit
git commit -m "feat: add authentication"  # abc123

# Oops, found typo
git add typo-fix.txt
git commit --fixup abc123

# Another fix
git add another-fix.txt
git commit --fixup abc123

# Commit log now:
# abc123 feat: add authentication
# def456 fixup! feat: add authentication
# ghi789 fixup! feat: add authentication
```

### Autosquash Rebase

```bash
# Rebase with autosquash
git rebase -i --autosquash main

# Git automatically arranges:
pick abc123 feat: add authentication
fixup def456 fixup! feat: add authentication
fixup ghi789 fixup! feat: add authentication

# Just save and quit, no manual editing needed
```

### Enable Autosquash by Default

```bash
# Configure git
git config --global rebase.autosquash true

# Now just:
git rebase -i main
# Autosquash is automatic
```

### Create Squash Commits

```bash
# Similar to fixup, but keeps message
git commit --squash abc123
```

---

## Reword Commits

### Reword Commit Message

```bash
# Rebase
git rebase -i HEAD~3

# Change:
pick abc123 feat: add authentiction  # Typo!

# To:
reword abc123 feat: add authentiction

# Git stops and prompts for new message:
# Change "authentiction" to "authentication"
```

### Batch Reword

```bash
# Reword multiple commits
reword abc123 feat: add authentiction
reword def456 fix: bug in authoriztion

# Git prompts for each message in sequence
```

---

## Edit Commits

### Amend Commit in History

```bash
# Rebase
git rebase -i HEAD~3

# Change:
pick abc123 feat: add authentication

# To:
edit abc123 feat: add authentication

# Git stops at commit
# Make changes
git add forgotten-file.txt

# Amend commit
git commit --amend

# Continue rebase
git rebase --continue
```

### Split Commit

```bash
# Rebase
git rebase -i HEAD~3

# Mark commit for edit:
edit abc123 feat: add multiple features

# Git stops at commit
# Reset to before commit (keep changes)
git reset HEAD~

# Stage and commit separately
git add feature1.txt
git commit -m "feat: add feature 1"

git add feature2.txt
git commit -m "feat: add feature 2"

# Continue rebase
git rebase --continue
```

---

## Drop Commits

### Remove Unwanted Commits

```bash
# Rebase
git rebase -i HEAD~5

# Change:
pick abc123 feat: add feature
pick def456 WIP: debugging
pick ghi789 fix: bug fix

# To:
pick abc123 feat: add feature
drop def456 WIP: debugging
pick ghi789 fix: bug fix

# Or just delete the line
```

---

## Exec Command

### Test Each Commit

```bash
# Rebase with test after each commit
git rebase -i HEAD~3

# Add exec commands:
pick abc123 feat: add feature
exec npm test
pick def456 fix: bug fix
exec npm test
pick ghi789 feat: another feature
exec npm test

# Git runs tests after each commit
# Stops if test fails
```

### Automatic Testing

```bash
# Rebase with exec flag
git rebase -i HEAD~3 -x "npm test"

# Git automatically inserts exec after each commit
```

---

## Rebase onto Different Base

### Standard Rebase onto

```bash
# Move feature branch from old-base to new-base
git rebase --onto new-base old-base feature-branch

# Example:
git rebase --onto main feature-a feature-b
# Moves commits from feature-b that are not in feature-a onto main
```

### Practical Example

**Scenario**: Feature branch was based on outdated main.

```bash
# Old state:
# main (old)---A---B---C
#               \
#                D---E feature-branch

# Main has been updated:
# main---A---B---C---F---G

# Rebase feature onto new main:
git rebase --onto main C feature-branch

# New state:
# main---A---B---C---F---G
#                         \
#                          D'---E' feature-branch
```

---

## Preserve Merge Commits

### Standard Rebase (Flattens Merges)

```bash
# Standard rebase loses merge commits
git rebase main

# Before:
# main---A---B
#         \   \
#          C---M feature

# After:
# main---A---B---C' feature
# (Merge commit M is lost)
```

### Rebase with Merge Preservation

```bash
# Preserve merge commits
git rebase --rebase-merges main

# Before:
# main---A---B
#         \   \
#          C---M feature

# After:
# main---A---B
#             \
#              C'---M' feature
# (Merge structure preserved)
```

**Use case**: Complex branch topology with meaningful merges.

---

## Rebase Safety Rules

### NEVER Rebase Public Branches

**Bad**:
```bash
git checkout main
git rebase feature-branch  # DANGEROUS!
```

**Why**: Others may have based work on current main.

**Good**:
```bash
git checkout feature-branch
git rebase main  # Safe
```

### NEVER Force Push Without Coordination

**Bad**:
```bash
git push --force  # Can overwrite others' work
```

**Good**:
```bash
# Use --force-with-lease (safer)
git push --force-with-lease

# Or coordinate with team
# 1. Announce: "I'm rebasing feature-branch"
# 2. Wait for confirmation from collaborators
# 3. Force push
# 4. Notify: "Rebase complete, re-pull please"
```

### Only Rebase Private Branches

```bash
# Safe: Feature branch not shared
git checkout my-feature
git rebase main
git push --force-with-lease

# Unsafe: Branch shared with team
git checkout team-feature
git rebase main  # AVOID!
```

---

## Rebase vs Merge Guidelines

| Scenario | Recommendation | Reason |
|----------|----------------|--------|
| Update feature from main | Rebase | Clean linear history |
| Integrate feature to main | Merge (via PR) | Preserve feature context |
| Shared feature branch | Merge | Avoid force push |
| Hotfix to main | Merge | Quick, safe |
| Cleanup before PR | Rebase | Clean commit history |
| Public branch | Merge | Never rebase public |

---

## Advanced Rebase Techniques

### Rebase with Specific Strategy

```bash
# Use theirs strategy for conflicts
git rebase -Xtheirs main

# Use ours strategy
git rebase -Xours main

# Ignore whitespace
git rebase -Xignore-space-change main
```

### Rebase Specific File

```bash
# During rebase, use version from specific commit
git checkout abc123 -- file.txt
git add file.txt
git rebase --continue
```

### Skip Commits During Rebase

```bash
# Start rebase
git rebase main

# If commit can't be applied
git rebase --skip

# Continues with next commit
```

---

## Recovering from Rebase Gone Wrong

### Abort Rebase

```bash
# Abort mid-rebase
git rebase --abort

# Returns to pre-rebase state
```

### Recover After Force Push

```bash
# Find pre-rebase commit
git reflog
# abc123 HEAD@{1}: rebase finished: refs/heads/feature-branch

# Reset to pre-rebase state
git reset --hard abc123
```

### Undo Completed Rebase

```bash
# Find original branch position
git reflog
# abc123 HEAD@{1}: rebase finished

# Reset to before rebase
git reset --hard HEAD@{1}
```

---

## Rebase Workflow Example

### Clean Feature Branch Before PR

```bash
# 1. Create feature branch
git checkout -b feature/new-feature main

# 2. Make several commits
git commit -m "feat: add feature skeleton"
git commit -m "WIP"
git commit -m "fix typo"
git commit -m "feat: complete feature"
git commit -m "fix another typo"

# 3. Update from main
git fetch origin
git rebase origin/main

# 4. Clean up commits
git rebase -i origin/main

# Interactive editor:
pick abc123 feat: add feature skeleton
fixup def456 WIP
fixup ghi789 fix typo
pick jkl012 feat: complete feature
fixup mno345 fix another typo

# Result: 2 clean commits

# 5. Force push (safe, private branch)
git push --force-with-lease origin feature/new-feature

# 6. Create PR
gh pr create --title "feat: add new feature"
```

---

## Common Rebase Patterns

### Squash All Commits into One

```bash
# Squash entire feature branch
git rebase -i main

# Change all but first to fixup:
pick abc123 First commit
fixup def456 Second commit
fixup ghi789 Third commit
```

### Reorder Commits

```bash
# Rebase
git rebase -i HEAD~3

# Reorder by moving lines:
pick ghi789 feat: add feature C
pick abc123 feat: add feature A
pick def456 feat: add feature B

# Result: Commits applied in new order
```

### Combine Fixup and Reword

```bash
pick abc123 feat: add authentiction  # Typo
fixup def456 fix typo
reword abc123 feat: add authentiction

# Git combines, then prompts to fix message
```

---

**Last Updated**: 2026-02-16
