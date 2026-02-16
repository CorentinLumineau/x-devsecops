---
name: error-handling
description: Error handling patterns and exception management. Fail fast, meaningful errors, recovery.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# Error Handling

Robust error handling patterns for reliable software.

## Principles

| Principle | Description |
|-----------|-------------|
| Fail fast | Detect and report errors early |
| Meaningful messages | Help users understand and fix |
| Don't swallow errors | Always handle or propagate |
| Graceful degradation | Partial functionality > crash |

## Error Types

| Type | Handling | Example |
|------|----------|---------|
| Expected | Handle explicitly | Validation errors |
| Unexpected | Log and recover | System failures |
| Fatal | Crash gracefully | Out of memory |

## Error Handling Patterns

### Try-Catch Best Practices
```
✅ Catch specific exceptions
✅ Log with context
✅ Re-throw if can't handle
❌ Empty catch blocks
❌ Catch all exceptions
```

### Result Pattern
```
Return Result<T, E> instead of throwing:
- Success: { ok: true, value: T }
- Failure: { ok: false, error: E }
```

### Error Boundary
```
Wrap components/operations:
- Catch errors at boundary
- Display fallback UI
- Log for debugging
```

## Error Message Guidelines

| Component | Include |
|-----------|---------|
| What happened | Clear description |
| Why it happened | Root cause if known |
| How to fix | Actionable guidance |
| Context | Request ID, timestamp |

## Logging Strategy

| Level | Use For |
|-------|---------|
| Error | Failures needing attention |
| Warn | Issues that may need attention |
| Info | Normal operations |
| Debug | Detailed troubleshooting |

### Log Content
```
✅ Error message
✅ Stack trace (for debugging)
✅ Request context
✅ User ID (anonymized)
❌ Passwords or secrets
❌ Full request bodies with PII
```

## HTTP Error Responses

| Code | Meaning | Use When |
|------|---------|----------|
| 400 | Bad Request | Validation failed |
| 401 | Unauthorized | Not authenticated |
| 403 | Forbidden | No permission |
| 404 | Not Found | Resource missing |
| 422 | Unprocessable | Business logic error |
| 500 | Server Error | Unexpected failure |

## Checklist

- [ ] All errors are caught or propagated
- [ ] No empty catch blocks
- [ ] Meaningful error messages
- [ ] Appropriate logging level
- [ ] Sensitive data not exposed
- [ ] User-friendly error display
- [ ] Error recovery where possible

## When to Load References

- **For async error handling**: See `references/async-errors.md`
- **For API error responses**: See `references/api-errors.md`
- **For error monitoring**: See `references/monitoring.md`

## Related Skills

- **@skills/code-code-quality/** - SOLID principles, refactoring, and code review
- **@skills/code-design-patterns/** - GoF design patterns
- **@skills/code-api-design/** - REST API and SDK design best practices
