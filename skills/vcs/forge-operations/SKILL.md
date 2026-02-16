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

---

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

---

## Release Operations

Both forges support tag-based releases with similar CLI patterns:

```bash
# Create release from tag
gh release create v1.0.0 --title "Release 1.0" --notes "..."    # GitHub
tea release create --tag v1.0.0 --title "Release 1.0" --note "..."  # Gitea

# Attach artifacts
gh release upload v1.0.0 dist/*.tar.gz                # GitHub
tea release create --tag v1.0.0 --asset dist/*.tar.gz # Gitea
```

**Key difference**: Gitea's `tea` combines asset upload with creation.

---

## CLI Capability Matrix

| Capability | gh (GitHub) | tea (Gitea) | Notes |
|------------|-------------|-------------|-------|
| PR templates | ✓ | ✓ | Both support .github/pull_request_template.md |
| Draft PRs | ✓ | ✓ | `--draft` flag |
| PR reviews | ✓ | ✓ | `gh pr review`, `tea pr review` |
| Auto-merge | ✓ | ✓ | `--auto` flag |
| Issue templates | ✓ | ✓ | .github/ISSUE_TEMPLATE/ |
| Project boards | ✓ | ✗ | GitHub-only feature |
| CI integration | ✓ | ✓ | Different status check APIs |
| GPG verification | ✓ | ✓ | Both display signature status |

---

## When to Load References

| Reference | Load When | Use Case |
|-----------|-----------|----------|
| `cli-equivalences.md` | Creating forge-agnostic automation | Need complete gh ↔ tea command mapping |
| `detection-patterns.md` | Implementing forge detection logic | Building multi-forge tools |
| `pr-operations.md` | Managing PR lifecycle | PR creation, review, merge workflows |
| `issue-operations.md` | Issue tracking workflows | Issue triage, labeling, milestones |

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

## Examples

### Forge-Agnostic PR Creation Script

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

### Multi-Forge CI Status Check

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

---

**Version**: 1.0.0 | **Category**: vcs | **License**: Apache-2.0
