---
name: llm-optimization
description: Best practices for LLM-assisted development. Prompting, context management, token efficiency.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# LLM Optimization

Best practices for effective LLM-assisted development.

## Context Management

| Practice | Benefit |
|----------|---------|
| Provide relevant files only | Reduces noise |
| Include error messages | Faster diagnosis |
| Share test failures | Clear reproduction |
| Reference documentation | Accurate solutions |

## Effective Prompting

### Be Specific
```
❌ "Fix the bug"
✅ "Fix the null pointer error in UserService.getUser() on line 42"
```

### Provide Context
```
❌ "Write tests"
✅ "Write unit tests for the calculateDiscount function testing edge cases: 0%, 100%, and negative values"
```

### State Constraints
```
✅ "Using TypeScript strict mode and Jest, test the authentication middleware"
```

## Token Efficiency

| Technique | Description |
|-----------|-------------|
| Progressive disclosure | Start high-level, drill down |
| Targeted reads | Read specific files, not entire codebase |
| Summarize context | Brief overview, not full history |
| Clear instructions | Reduce back-and-forth |

## Code Generation Guidelines

| Guideline | Rationale |
|-----------|-----------|
| Review generated code | AI can hallucinate |
| Run tests | Verify functionality |
| Check edge cases | AI may miss them |
| Validate security | Don't blindly trust |

## Iteration Pattern

```
1. Clear request → AI generates
2. Review output → Identify issues
3. Specific feedback → AI refines
4. Repeat until correct
```

## Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| Vague prompts | Be specific |
| No context | Provide relevant info |
| Accepting blindly | Always review |
| Huge dumps | Targeted information |

## Working with AI Assistants

### Do
- Provide clear acceptance criteria
- Include relevant error messages
- Share failing test output
- Reference existing patterns in codebase

### Don't
- Dump entire codebase
- Accept without testing
- Skip code review
- Ignore security implications

## Checklist

- [ ] Prompt is clear and specific
- [ ] Relevant context provided
- [ ] Generated code reviewed
- [ ] Tests pass
- [ ] Security considerations checked
- [ ] Follows existing patterns

## When to Load References

- **For prompt engineering**: See `references/prompting.md`
- **For context strategies**: See `references/context-management.md`
