# x-devsecops Skill Creation Rules

## Frontmatter Contract

All knowledge skills MUST have a YAML frontmatter block between `---` markers.

| Field | Required | Constraint |
|-------|----------|------------|
| `name` | Yes | Matches directory name, NO category prefix, NO `x-` prefix |
| `description` | Yes | Single-line string (no YAML `|` or `>`) |
| `license` | Yes | `Apache-2.0` |
| `compatibility` | Yes | `Works with Claude Code, Cursor, Cline, and any skills.sh agent.` |
| `allowed-tools` | Yes | `Read Grep Glob` (read-only; warn if Write/Edit present) |
| `metadata.author` | Yes | `ccsetup contributors` |
| `metadata.version` | Yes | Semver string (e.g., `"1.0.0"`) |
| `metadata.category` | Yes | Must match parent directory |

### Complete Example

```yaml
---
name: rbac
description: Role-based access control patterns and authorization strategies.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---
```

**IMPORTANT**: The `name` field is just the skill name (e.g., `owasp`), NOT the flattened form (NOT `security-owasp`). Category prefixing happens at sync time in ccsetup.

---

## Naming Convention

| Attribute | Rule |
|-----------|------|
| **Directory** | `skills/{category}/{name}/` |
| **Valid categories** | `security`, `quality`, `code`, `data`, `delivery`, `operations`, `meta` |
| **Name regex** | `^[a-z][-a-z]*$` |
| **Forbidden prefix** | `x-` (reserved for workflow skills in x-workflows) |

---

## Required Sections

Knowledge skills MUST have:

1. **Title** (e.g., `# RBAC`)
2. **80/20 Focus table** — the vital few that deliver most impact (Pareto)
3. **Enforcement Definitions** or **Quick Reference** table
4. **When to Load References** section
5. **Related Skills** section

Knowledge skills MUST NOT have:

- Execution steps (phases, numbered instructions) — belongs in x-workflows
- Agent delegation directives
- Workflow chaining rules
- `<instructions>` blocks

---

## Template Usage

Always scaffold with:

```bash
make new-skill CATEGORY=security NAME=rbac
```

Then:
1. Replace `__DESCRIPTION__` with actual description
2. Fill in all TODO markers
3. Add reference files in `references/` directory
4. Run `make validate` before committing

---

## Content Rules

- **Knowledge ONLY** — describe WHAT, not HOW
- **No real credentials** — use placeholders like `your-api-key`, `<token>`
- **Prevention-focused** security content
- **Agent-agnostic** — no Claude Code specific syntax
- **Read-only tools** — knowledge skills should use `Read Grep Glob` only
