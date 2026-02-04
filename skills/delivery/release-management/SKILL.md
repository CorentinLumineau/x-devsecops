---
name: release-management
description: Release management and versioning. SemVer, changelog, safe git practices, tagging.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---

# Release Management

Version management and safe release practices.

## Semantic Versioning (SemVer)

```
MAJOR.MINOR.PATCH (e.g., 2.1.3)
```

| Component | When to Increment |
|-----------|-------------------|
| MAJOR | Breaking changes |
| MINOR | New features (backward compatible) |
| PATCH | Bug fixes |

## Version Decision Guide

| Change Type | Version Bump |
|-------------|--------------|
| Breaking API change | MAJOR |
| New feature | MINOR |
| Bug fix | PATCH |
| Documentation only | PATCH |
| Dependency update (non-breaking) | PATCH |
| Deprecation (still works) | MINOR |

## Changelog Format

```markdown
# Changelog

## [2.1.0] - 2026-01-23

### Added
- New user authentication endpoint

### Changed
- Improved error messages

### Fixed
- Memory leak in connection pool

### Deprecated
- Old auth method (use v2)

### Removed
- Legacy API endpoints

### Security
- Fixed XSS vulnerability
```

## Safe Git Practices

| Practice | Why |
|----------|-----|
| Feature branches | Isolate work |
| Never force-push main | Protect history |
| PR reviews required | Quality gate |
| Signed commits | Verify authorship |
| Protect main branch | Prevent accidents |

## Branch Strategy

```
main (production)
├── release/v2.1
│   └── fix/critical-bug
├── develop
│   └── feature/new-feature
└── hotfix/urgent-fix → main
```

## Commit Message Format

```
type(scope): description

Types: feat, fix, docs, style, refactor, test, chore
```

Examples:
- `feat(auth): add MFA support`
- `fix(api): handle null response`
- `docs: update README`

## Release Checklist

### Pre-Release
- [ ] All tests passing
- [ ] Changelog updated
- [ ] Version bumped
- [ ] Documentation updated
- [ ] Breaking changes documented

### Release
- [ ] Create release branch
- [ ] Tag with version
- [ ] Build release artifacts
- [ ] Push tag and branch

### Post-Release
- [ ] Monitor for issues
- [ ] Announce release
- [ ] Merge back to develop (if applicable)

## Git Commands Reference

```bash
# Create release tag
git tag -a v2.1.0 -m "Release v2.1.0"
git push origin v2.1.0

# Create release branch
git checkout -b release/v2.1 main
```

## Never Do

| Action | Risk |
|--------|------|
| Force push to main | Lost commits |
| Direct push to main | Skip review |
| Unsigned commits | Unknown author |
| Skip CI | Untested code |
| Delete release tags | Lost references |

## When to Load References

- **For branching strategies**: See `references/branching.md`
- **For changelog automation**: See `references/changelog.md`
- **For release automation**: See `references/automation.md`
