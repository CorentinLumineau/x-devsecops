# CLI Equivalences: gh ↔ tea

Complete mapping of GitHub CLI (`gh`) and Gitea CLI (`tea`) commands for common forge operations.

---

## Pull Request Operations

| Operation | GitHub (gh) | Gitea (tea) | Notes |
|-----------|-------------|-------------|-------|
| Create PR | `gh pr create --title "Title" --body "Body"` | `tea pr create --title "Title" --body "Body"` | Both support `--draft` |
| Create from issue | `gh pr create --issue 42` | N/A | GitHub-only feature |
| List PRs | `gh pr list` | `tea pr list` | Both support `--state open/closed/all` |
| List by author | `gh pr list --author @me` | `tea pr list --author username` | Different author syntax |
| View PR | `gh pr view 42` | `tea pr show 42` | **Different verb**: view vs show |
| View in browser | `gh pr view 42 --web` | `tea pr show 42 --web` | Same flag |
| Checkout PR | `gh pr checkout 42` | `tea pr checkout 42` | Identical |
| Check CI status | `gh pr checks` | `tea pr ci` | **Different command** |
| Request review | `gh pr review 42 --approve` | `tea pr review 42 --approve` | Identical |
| Comment on PR | `gh pr comment 42 --body "Text"` | `tea pr comment 42 --body "Text"` | Identical |
| Merge PR (squash) | `gh pr merge 42 --squash` | `tea pr merge 42 --squash` | Identical |
| Merge PR (rebase) | `gh pr merge 42 --rebase` | `tea pr merge 42 --rebase` | Identical |
| Merge PR (merge) | `gh pr merge 42 --merge` | `tea pr merge 42 --merge` | Identical |
| Close PR | `gh pr close 42` | `tea pr close 42` | Identical |
| Reopen PR | `gh pr reopen 42` | `tea pr reopen 42` | Identical |
| Edit PR | `gh pr edit 42 --title "New"` | `tea pr edit 42 --title "New"` | Identical |
| Ready for review | `gh pr ready 42` | `tea pr ready 42` | Both convert draft → ready |

---

## Issue Operations

| Operation | GitHub (gh) | Gitea (tea) | Notes |
|-----------|-------------|-------------|-------|
| Create issue | `gh issue create --title "Bug" --body "..."` | `tea issue create --title "Bug" --body "..."` | Identical |
| List issues | `gh issue list` | `tea issue list` | Both support `--state`, `--label` |
| List assigned | `gh issue list --assignee @me` | `tea issue list --assignee username` | Different assignee syntax |
| View issue | `gh issue view 42` | `tea issue show 42` | **Different verb** |
| Close issue | `gh issue close 42` | `tea issue close 42` | Identical |
| Reopen issue | `gh issue reopen 42` | `tea issue reopen 42` | Identical |
| Add label | `gh issue edit 42 --add-label "bug"` | `tea issue edit 42 --add-label "bug"` | Identical |
| Remove label | `gh issue edit 42 --remove-label "bug"` | `tea issue edit 42 --remove-label "bug"` | Identical |
| Assign user | `gh issue edit 42 --add-assignee user` | `tea issue edit 42 --add-assignee user` | Identical |
| Set milestone | `gh issue edit 42 --milestone "v1.0"` | `tea issue edit 42 --milestone "v1.0"` | Identical |
| Comment | `gh issue comment 42 --body "Text"` | `tea issue comment 42 --body "Text"` | Identical |

---

## Release Operations

| Operation | GitHub (gh) | Gitea (tea) | Notes |
|-----------|-------------|-------------|-------|
| List releases | `gh release list` | `tea release list` | Identical |
| View release | `gh release view v1.0.0` | `tea release show v1.0.0` | **Different verb** |
| Create release | `gh release create v1.0.0 --title "..." --notes "..."` | `tea release create --tag v1.0.0 --title "..." --note "..."` | **Different flags**: --notes vs --note |
| Upload assets | `gh release upload v1.0.0 file.tar.gz` | `tea release create --tag v1.0.0 --asset file.tar.gz` | **Major difference**: tea uploads during creation |
| Delete release | `gh release delete v1.0.0` | `tea release delete --tag v1.0.0` | tea requires --tag flag |
| Download assets | `gh release download v1.0.0` | `tea release download --tag v1.0.0` | tea requires --tag flag |

---

## Label Operations

| Operation | GitHub (gh) | Gitea (tea) | Notes |
|-----------|-------------|-------------|-------|
| List labels | `gh label list` | `tea label list` | Identical |
| Create label | `gh label create "bug" --color FF0000` | `tea label create --name "bug" --color FF0000` | tea requires --name flag |
| Delete label | `gh label delete "bug"` | `tea label delete "bug"` | Identical |
| Edit label | `gh label edit "bug" --color 00FF00` | `tea label update "bug" --color 00FF00` | **Different verb**: edit vs update |

---

## Milestone Operations

| Operation | GitHub (gh) | Gitea (tea) | Notes |
|-----------|-------------|-------------|-------|
| List milestones | `gh api repos/:owner/:repo/milestones` | `tea milestone list` | gh requires API call, tea has dedicated command |
| Create milestone | `gh api repos/:owner/:repo/milestones -f title="v1.0"` | `tea milestone create --title "v1.0"` | tea much simpler |
| Close milestone | N/A (API only) | `tea milestone close --name "v1.0"` | tea has native support |

---

## Repository Operations

| Operation | GitHub (gh) | Gitea (tea) | Notes |
|-----------|-------------|-------------|-------|
| Clone repo | `gh repo clone owner/repo` | `tea repo clone owner/repo` | Identical |
| Fork repo | `gh repo fork owner/repo` | `tea repo fork owner/repo` | Identical |
| View repo | `gh repo view owner/repo` | `tea repo show owner/repo` | **Different verb** |
| Create repo | `gh repo create name` | `tea repo create --name name` | tea requires --name flag |

---

## Authentication

| Operation | GitHub (gh) | Gitea (tea) | Notes |
|-----------|-------------|-------------|-------|
| Login | `gh auth login` | `tea login add` | **Completely different** |
| Check status | `gh auth status` | `tea login list` | Different commands |
| Logout | `gh auth logout` | `tea logout` | Different syntax |
| Token setup | `gh auth login --with-token` | `tea login add --token` | Both support token-based auth |

---

## Key Differences Summary

| Aspect | GitHub (gh) | Gitea (tea) | Impact |
|--------|-------------|-------------|--------|
| View command | `view` | `show` | Must adapt verb for view operations |
| Release assets | `upload` subcommand | `--asset` flag on create | Workflow difference |
| Authentication | `auth` subcommand | `login` command | Completely different |
| Milestone support | API calls only | Native commands | tea is easier |
| Author syntax | `@me` | `username` | Must resolve username for tea |
| Flag consistency | Generally consistent | Some require explicit flags | tea sometimes more verbose |

---

## Automation Pattern

For forge-agnostic scripts, use this pattern:

```bash
if [ "$FORGE" = "github" ]; then
  # gh syntax
  gh pr view "$PR_NUM"
elif [ "$FORGE" = "gitea" ]; then
  # tea syntax (adapt verb)
  tea pr show "$PR_NUM"
fi
```

---

## Installation

| Forge | CLI | Installation |
|-------|-----|--------------|
| GitHub | gh | https://cli.github.com |
| Gitea | tea | https://gitea.com/gitea/tea |

---

**Last Updated**: 2026-02-16
