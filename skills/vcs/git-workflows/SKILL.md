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
  |
Is branch shared with others?
  | YES -> MERGE (safe, preserves history)
  | NO  -> Continue
  |
Want linear history?
  | YES -> REBASE (rewrites history)
  | NO  -> MERGE (preserves branch context)
  |
Integrating from upstream?
  | YES -> REBASE (keep feature branch up-to-date)
  | NO  -> MERGE (integrating feature into main)
```

**Golden rule**: Never rebase commits that have been pushed to a shared branch.

---

## Key Conflict Resolution Strategies

| Strategy | Command | Use When |
|----------|---------|----------|
| Manual | Edit file, `git add`, `git commit` | Complex conflicts needing judgment |
| Accept ours | `git checkout --ours file.txt` | Current branch has correct version |
| Accept theirs | `git checkout --theirs file.txt` | Incoming branch has correct version |
| Merge tool | `git mergetool` | Visual diff needed |
| Abort | `git merge --abort` / `git rebase --abort` | Need to start over |

For detailed conflict resolution workflows, rebase patterns, and examples, see `references/advanced-operations.md`.

---

## Rebase Safety Rules

1. **NEVER rebase public branches** - Others may have based work on them
2. **NEVER rebase main/master** - Shared branch
3. **DO rebase feature branches** - Before merging to keep history clean
4. **DO rebase to update feature branch** - `git rebase main` on feature branch
5. **Prefer `--force-with-lease`** over `--force` when pushing rebased branches

---

## Key History Tools

| Tool | Purpose | Key Command |
|------|---------|-------------|
| Bisect | Binary search for bug-introducing commit | `git bisect start` / `git bisect run ./test.sh` |
| Blame | Find who changed specific lines | `git blame -L 10,20 file.txt` |
| Log | Search history by author, date, content | `git log -S "function_name"` |
| Reflog | Recover lost commits after reset/rebase | `git reflog` |

For detailed history navigation, cherry-pick operations, and advanced techniques, see `references/advanced-operations.md`.

---

## Common Pitfalls

1. **Rebasing public branches** - Breaks history for collaborators
2. **Force pushing without coordination** - `git push --force` can lose others' work
3. **Using `git reset --hard` without backup** - Lose uncommitted changes
4. **Not testing after conflict resolution** - Broken merge can pass unnoticed
5. **Cherry-picking without context** - Commit may not work in different branch
6. **Forgetting to continue rebase** - Repository stuck in rebase state

---

## When to Load References

| Reference | Load When | Use Case |
|-----------|-----------|----------|
| `references/advanced-operations.md` | Resolving conflicts, rebasing, navigating history | Full strategies, examples, best practices |
| `references/conflict-resolution.md` | Facing merge/rebase conflicts | Detailed conflict resolution strategies |
| `references/history-navigation.md` | Debugging or investigating changes | Bisect, blame, log, reflog techniques |
| `references/rebase-patterns.md` | Cleaning up commit history | Interactive rebase, autosquash, safety |

---

## Related Skills

- **vcs-conventional-commits** - Commit message format for clean history
- **vcs-forge-operations** - PR operations that trigger merges
- **security-git** - GPG signing for verified history

---

**Version**: 1.0.0 | **Category**: vcs | **License**: Apache-2.0
