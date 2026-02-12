# Skill Frontmatter Reference (x-devsecops)

> Definitive guide for skill frontmatter in x-devsecops repository.

## Overview

x-devsecops contains **knowledge skills** - reference documentation that Claude loads when relevant to the user's task. These skills are never user-invocable.

## Knowledge Skills (All Skills in x-devsecops)

**Definition**: Reference documentation providing domain expertise. Claude loads these automatically when relevant. Users cannot invoke them directly.

| Attribute | Value |
|-----------|-------|
| **Naming** | `{skill-name}` (no `x-` prefix) |
| **Frontmatter** | `user-invocable: false` (required) |
| **User trigger** | ❌ No, not accessible via `/command` |
| **Claude trigger** | ✅ Yes, loaded when relevant to task |
| **File location** | `skills/{category}/{name}/SKILL.md` |
| **Categories** | security, quality, code, data, delivery, operations, meta |

**Examples**: `security-owasp`, `quality-testing`, `code-design-patterns`, `data-database`, `delivery-ci-cd`

**Use for**: Domain knowledge, best practices, reference patterns, checklists.

---

## Frontmatter Template

```yaml
---
name: {skill-name}
description: {What knowledge this skill provides}
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: {category}
---
```

**Key fields**:
- `name`: Must match directory name (NOT prefixed with category)
- `category`: Must match parent directory (security, quality, code, data, delivery, operations, meta)
- `allowed-tools`: Knowledge skills should be **read-only** - avoid Write/Edit
- `user-invocable`: **Omitted** (defaults to false for non-x-* skills)

**Note**: Unlike x-workflows, knowledge skills do NOT need explicit `user-invocable: false` in frontmatter. The absence of the `x-` prefix makes them non-user-invocable by default.

---

## Categories

x-devsecops skills are organized by domain:

| Category | Purpose | Example Skills |
|----------|---------|----------------|
| **security** | Security patterns, OWASP, auth | `security-owasp`, `security-authentication` |
| **quality** | Testing, debugging, observability | `quality-testing`, `quality-debugging` |
| **code** | Design patterns, refactoring, quality | `code-design-patterns`, `code-quality` |
| **data** | Database, caching, message queues | `data-database`, `data-caching` |
| **delivery** | CI/CD, deployment, GitOps | `delivery-ci-cd`, `deployment-strategies` |
| **operations** | Monitoring, infrastructure, SRE | `operations-monitoring`, `infrastructure-as-code` |
| **meta** | Analysis, documentation, architecture | `meta-analysis`, `documentation` |

---

## Naming Convention

Knowledge skills follow the pattern: `{category}/{skill-name}/SKILL.md`

**Directory structure**:
```
skills/
├── security/
│   ├── owasp/SKILL.md            (name: owasp)
│   └── authentication/SKILL.md   (name: authentication)
├── quality/
│   ├── testing/SKILL.md          (name: testing)
│   └── debugging/SKILL.md        (name: debugging)
└── code/
    ├── design-patterns/SKILL.md  (name: design-patterns)
    └── quality/SKILL.md          (name: quality)
```

**Important**: The `name` field in frontmatter should match the skill directory name, NOT include the category prefix.

❌ **Wrong**:
```yaml
---
name: security-owasp  # Don't prefix with category
category: security
---
```

✅ **Correct**:
```yaml
---
name: owasp  # Matches directory name
category: security  # Category comes from parent directory
---
```

---

## Invocation Behavior

Knowledge skills are **reference documents** - Claude loads them automatically when relevant to the user's task.

| Access Method | Available? | How |
|---------------|------------|-----|
| User command (`/skill-name`) | ❌ No | Knowledge skills are not user-invocable |
| Claude auto-load | ✅ Yes | Loaded when task domain matches skill category |
| @skills reference | ✅ Yes | `@skills/security-owasp/` in skill docs |

**Examples**:

```markdown
# User asks security question
User: "How do I prevent SQL injection?"
→ Claude auto-loads @skills/security-owasp/
→ Provides OWASP guidance on parameterized queries

# Workflow skill references knowledge skill
x-implement needs security guidance
→ References @skills/security-owasp/ in implementation
→ Applies OWASP top 10 checks
```

---

## Example Frontmatter

### Example: security/owasp (Security Knowledge)

```yaml
---
name: owasp
description: OWASP Top 10 security vulnerabilities and mitigations.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---
```

**File location**: `skills/security/owasp/SKILL.md`

---

### Example: quality/testing (Quality Knowledge)

```yaml
---
name: testing
description: Testing pyramid, TDD, and test design patterns.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---
```

**File location**: `skills/quality/testing/SKILL.md`

---

### Example: delivery/deployment-strategies (Delivery Knowledge)

```yaml
---
name: deployment-strategies
description: Deployment strategies for safe, zero-downtime releases.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---
```

**File location**: `skills/delivery/deployment-strategies/SKILL.md`

---

## Validation Rules

### Naming Validation

| Rule | Valid | Invalid |
|------|-------|---------|
| Must NOT have `x-` prefix | `owasp` | `x-owasp` |
| Use kebab-case | `design-patterns` | `DesignPatterns` |
| Category matches directory | `security/owasp` | `quality/owasp` |

### Frontmatter Validation

| Field | Rule |
|-------|------|
| `name` | Must match directory name (NOT category-prefixed) |
| `category` | Must match parent directory |
| `description` | Must exist and be single-line |
| `allowed-tools` | Warn if Write/Edit present (should be read-only) |
| `license` | Must be `Apache-2.0` |

### Common Mistakes

❌ **Wrong**: Name includes category prefix

```yaml
---
name: security-owasp  # Don't prefix with category
category: security
---
```

❌ **Wrong**: Wrong category

```yaml
---
name: owasp
category: quality  # Should be 'security' to match directory
---
```

❌ **Wrong**: Write tools in knowledge skill

```yaml
---
name: testing
allowed-tools: [Read, Write, Edit, Grep]  # Knowledge skills should be read-only
---
```

✅ **Correct**: Proper knowledge skill frontmatter

```yaml
---
name: owasp
description: OWASP Top 10 security vulnerabilities and mitigations.
license: Apache-2.0
allowed-tools: [Read, Grep, Glob]
metadata:
  category: security
---
```

---

## Creating New Skills

### Create Knowledge Skill

```bash
cd x-devsecops
make new-skill CATEGORY=security NAME=rbac
```

This scaffolds:
- `skills/security/rbac/SKILL.md` with proper frontmatter template
- `skills/security/rbac/references/` directory
- Validates category is valid: `security|quality|code|data|delivery|operations|meta`
- Validates name matches `^[a-z][-a-z]*$` and does NOT start with `x-`

**Template location**: `.templates/knowledge-skill/SKILL.md`

---

## Validation

Run validation to check frontmatter:

```bash
make validate
```

**Check 6 validates**:
- `name` matches directory name (NOT category-prefixed)
- `category` matches parent directory
- `description` exists and is single-line
- `name` does NOT start with `x-`
- `allowed-tools` warns if Write/Edit present
- `license` is `Apache-2.0`

---

## References

- [Claude Code Skills Documentation](https://docs.anthropic.com/claude-code/skills)
- @core-docs/SKILL_TYPES.md (ccsetup) - Full skill type taxonomy
- .templates/knowledge-skill/SKILL.md - Knowledge skill template
- skills/security/owasp/SKILL.md - Example knowledge skill
- skills/quality/testing/SKILL.md - Example knowledge skill

---

**Version**: 1.0.0
**Last Updated**: 2026-02-12
