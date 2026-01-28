# x-devsecops Quality Gates

## Quality Gates

Before merging changes to x-devsecops:

- [ ] Every skill has a `SKILL.md` file
- [ ] No execution steps (HOW) - only knowledge (WHAT)
- [ ] No ccsetup or x-workflows dependencies
- [ ] Security content uses placeholders (no real secrets)
- [ ] External references link to authoritative sources
- [ ] Agent-agnostic (no Claude Code specific syntax)

---

## Skill Structure Template

```
skills/{category}/{skill-name}/
├── SKILL.md              # Main skill definition
├── references/
│   ├── {topic1}.md       # Topic-specific deep dive
│   └── {topic2}.md
└── examples/             # Optional: code examples
    └── {example}.md
```

---

## Version Sync

This repository is included as a submodule in ccsetup. When releasing:

1. Tag release in x-devsecops
2. Update submodule reference in ccsetup
3. Coordinate breaking changes with ccsetup maintainers
