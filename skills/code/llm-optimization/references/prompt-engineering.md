# Prompt Engineering Reference

Patterns for effective LLM prompting in development workflows.

## Context Management

### System Prompt Structure

```
[Role] You are a {specific role} with expertise in {domain}.

[Context] The project uses {stack}. Key constraints: {constraints}.

[Task] {Clear, specific instruction}

[Format] Respond with {output format}.

[Examples] (if needed)
```

### Context Window Optimization

```typescript
// Prioritize context by relevance
function buildPromptContext(task: string, files: FileInfo[]): string {
  const sections = [
    // 1. Most relevant: directly referenced files
    formatDirectFiles(files.filter(f => f.directlyReferenced)),

    // 2. Interface definitions (compact, high-value)
    formatInterfaces(files.filter(f => f.isInterface)),

    // 3. Related implementation (summarized if large)
    formatSummaries(files.filter(f => f.isRelated)),
  ];

  return sections.join('\n\n');
}
```

**Priority ordering for context**:
1. Error messages / stack traces (highest signal)
2. Directly relevant code (function being modified)
3. Type definitions and interfaces
4. Related tests
5. Configuration files
6. Documentation (lowest priority, summarize)

## Token Efficiency

### Concise Prompts

```
# BAD: Verbose (wastes tokens)
"I would really appreciate it if you could please take a look at
the following code and let me know if there are any issues with it
that you think might be problematic."

# GOOD: Direct (fewer tokens, same result)
"Review this code for bugs and performance issues."
```

### Structured Output Requests

```
# Request structured output to reduce parsing overhead
"Respond as JSON:
{
  "issues": [{"file": "", "line": 0, "severity": "", "message": ""}],
  "summary": ""
}"
```

## Few-Shot Patterns

### Code Generation

```
Generate a function following this pattern:

Example input:
  createUser(name: string, email: string): Promise<User>

Example output:
  async function createUser(name: string, email: string): Promise<User> {
    validate({ name, email });
    const user = await db.users.create({ name, email });
    await events.emit('user.created', user);
    return user;
  }

Now generate: updateUserEmail(userId: string, newEmail: string): Promise<User>
```

### Code Review

```
Review pattern — for each issue found, respond with:
- File and line
- Severity: critical | warning | suggestion
- Issue description
- Fix suggestion

Example:
- auth.ts:42 | critical | SQL injection via string concatenation | Use parameterized query
```

## Chain-of-Thought

### Debugging

```
Debug this error step by step:

1. What does the error message tell us?
2. What is the call stack showing?
3. What are the possible root causes?
4. What is the most likely cause given the context?
5. What is the fix?

Error: TypeError: Cannot read property 'map' of undefined
Stack: at UserList (UserList.tsx:15)
```

### Architecture Decisions

```
Evaluate this design decision:

1. State the requirements
2. List 2-3 viable options
3. Compare trade-offs (complexity, performance, maintainability)
4. Recommend with justification
```

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Vague instructions | Ambiguous output | Be specific about expected format |
| No examples | Inconsistent results | Add 1-2 few-shot examples |
| Too much context | Dilutes focus | Include only relevant code |
| No constraints | Over-engineered output | Specify scope and boundaries |
| Asking multiple things | Confused responses | One task per prompt |

## Prompt Templates for Development

### Bug Fix

```
Fix the bug described below.

**Error**: {error message}
**File**: {file path}
**Relevant code**: {code snippet}
**Expected behavior**: {what should happen}
**Actual behavior**: {what happens instead}

Provide only the corrected code with a brief explanation.
```

### Code Review

```
Review this diff for:
1. Bugs or logic errors
2. Security issues
3. Performance concerns

Ignore: style, formatting, naming conventions.

{diff}
```

### Test Generation

```
Generate tests for this function.
Framework: {jest/vitest/pytest}
Cover: happy path, edge cases, error cases.
Do not mock: {specific dependencies}.

{function code}
```

## Common Pitfalls

- **Context overflow**: Sending entire files when only a function is relevant; extract minimal context
- **Prompt injection in user input**: Sanitize any user-provided content included in prompts
- **Temperature too high for code**: Use temperature 0-0.2 for code generation, higher for creative tasks
- **Ignoring system prompts**: System prompts set consistent behavior; always define role and constraints
- **No output validation**: Always validate LLM output before using programmatically
