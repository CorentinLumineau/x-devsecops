---
name: forge-operations
description: Cross-forge CLI equivalences, detection patterns, and PR/issue/release operations for GitHub and Gitea.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: vcs
---

# forge-operations

Cross-forge CLI equivalences, detection patterns, and PR/issue/release operations for GitHub and Gitea.

---

## 80/20 Focus

| Priority Area | Coverage | Why It Matters |
|--------------|----------|----------------|
| PR operations | 40% | Create, review, merge, and close PRs across forges |
| Issue management | 25% | Track work items, labels, milestones |
| Forge detection | 20% | Auto-detect GitHub vs Gitea from URL/context |
| Release operations | 15% | Create releases, manage tags, changelog integration |

**Core principle**: Write forge-agnostic workflows that auto-detect and adapt to the current forge using CLI equivalences.

---

## Quick Reference

| Operation | GitHub (gh) | Gitea (tea) |
|-----------|-------------|-------------|
| Create PR | `gh pr create` | `tea pr create` |
| List PRs | `gh pr list` | `tea pr list` |
| View PR | `gh pr view <num>` | `tea pr show <num>` |
| Merge PR | `gh pr merge <num>` | `tea pr merge <num>` |
| Create issue | `gh issue create` | `tea issue create` |
| List issues | `gh issue list` | `tea issue list` |
| Close issue | `gh issue close <num>` | `tea issue close <num>` |
| Create release | `gh release create` | `tea release create` |
| Check CI | `gh pr checks` | `tea pr ci` |
| Add label | `gh issue edit --add-label` | `tea issue edit --add-label` |

---

## Supported Forges

| Forge | CLI Tool | Detection Pattern | Status |
|-------|----------|-------------------|--------|
| GitHub | `gh` | `github.com` in URL | Full support |
| Gitea | `tea` | Non-GitHub domain + Gitea API | Full support |
| Forgejo | `tea` | Forgejo API endpoint | Via Gitea CLI |
| GitLab | `glab` | `gitlab.com` in URL | Future consideration |

**Note**: GitLab support is intentionally excluded from this skill. Focus is on GitHub and Gitea/Forgejo ecosystems.

---

## Forge Detection Algorithm

When working with a git repository, detect the forge type using this priority order:

1. **URL parsing** - Extract forge domain from git remote URL
2. **Domain matching** - `github.com` → GitHub, else probe for Gitea API
3. **CLI availability** - Check which CLI tools are installed
4. **Fallback** - If no CLI available, suggest installation

### Detection Flow

```
git remote get-url origin
  ↓
Parse URL (SSH or HTTPS)
  ↓
Extract domain
  ↓
github.com? → GitHub → check `gh` installed
  ↓
Other domain? → Probe Gitea API → check `tea` installed
  ↓
No CLI? → Suggest installation
```

### CLI Installation Check

```bash
# Check for GitHub CLI
which gh || echo "Install: https://cli.github.com"

# Check for Gitea CLI
which tea || echo "Install: https://gitea.com/gitea/tea"
```

---

## Workflow Patterns

> See [references/forge-scripts.md](references/forge-scripts.md) for cross-forge PR creation, issue management, release operations, and CI status check scripts.

---

## When to Load References

| Reference | Load When | Use Case |
|-----------|-----------|----------|
| `cli-equivalences.md` | Creating forge-agnostic automation | Need complete gh ↔ tea command mapping |
| `detection-patterns.md` | Implementing forge detection logic | Building multi-forge tools |
| `pr-operations.md` | Managing PR lifecycle | PR creation, review, merge workflows |
| `issue-operations.md` | Issue tracking workflows | Issue triage, labeling, milestones |
| `forge-scripts.md` | Using ready-made scripts | Cross-forge PR, issue, release, CI scripts |

---

## Related Skills

- **vcs-git-workflows** - Git operations that work with any forge
- **vcs-conventional-commits** - Commit message format for PR titles
- **delivery-release-git** - Release workflows using forge APIs
- **security-git** - GPG signing for forge-verified commits

---

## Common Pitfalls

1. **Assuming GitHub** - Always detect forge type, don't hardcode `gh`
2. **Ignoring CLI availability** - Check tool exists before using
3. **Inconsistent flags** - Some flags differ (`gh pr view` vs `tea pr show`)
4. **API rate limits** - GitHub has stricter limits than self-hosted Gitea
5. **Authentication** - Each CLI has separate auth (`gh auth login`, `tea login add`)

---

**Version**: 1.0.0 | **Category**: vcs | **License**: Apache-2.0
