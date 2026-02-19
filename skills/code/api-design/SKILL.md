---
name: api-design
description: Use when designing or reviewing REST APIs, GraphQL schemas, or SDK interfaces. Covers resource naming, versioning, pagination, client libraries, and code generation best practices.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# API Design

Best practices for designing clean, consistent APIs and SDK client libraries.

## REST Principles

| Principle | Description |
|-----------|-------------|
| Resources | Nouns, not verbs |
| HTTP Methods | GET, POST, PUT, PATCH, DELETE |
| Stateless | No server-side session |
| HATEOAS | Links for discoverability |

## URL Structure

```
/users              (collection)
/users/123          (resource)
/users/123/posts    (nested)
```

## HTTP Methods

| Method | Use For | Idempotent |
|--------|---------|------------|
| GET | Read resources | Yes |
| POST | Create resource | No |
| PUT | Replace resource | Yes |
| PATCH | Partial update | Yes |
| DELETE | Remove resource | Yes |

## Response Codes

| Code | Meaning |
|------|---------|
| 200 | OK |
| 201 | Created |
| 204 | No Content |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Unprocessable Entity |
| 500 | Server Error |

## Pagination

```json
{
  "data": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "hasNext": true
  }
}
```

Query params: `?page=1&limit=20` or `?cursor=abc123`

## Versioning

| Strategy | Example |
|----------|---------|
| URL path | `/v1/users` |
| Header | `Accept: application/vnd.api.v1+json` |
| Query | `?version=1` |

**Recommended**: URL path (explicit, discoverable)

## Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Email is invalid",
    "details": [
      { "field": "email", "message": "Must be valid email" }
    ]
  }
}
```

## GraphQL Considerations

| Aspect | Best Practice |
|--------|---------------|
| Schema | Type-safe, documented |
| Queries | Avoid over-fetching |
| Mutations | Clear input/output |
| N+1 | Use DataLoader |

## SDK Design Patterns

> See [references/sdk-patterns.md](references/sdk-patterns.md) for SDK design principles, error handling, retry logic, versioning, builder pattern, and OpenAPI code generation.

## API Design Checklist

- [ ] Resources are nouns
- [ ] HTTP methods used correctly
- [ ] Consistent naming (plural, lowercase, hyphens)
- [ ] Proper status codes
- [ ] Pagination for lists
- [ ] Versioning strategy
- [ ] Error response format
- [ ] Rate limiting
- [ ] Authentication documented
- [ ] SDK follows language idioms
- [ ] Retry logic for transient failures
- [ ] OpenAPI spec validated

## When to Load References

- **For OpenAPI specification patterns**: See `references/openapi.md`
- **For GraphQL schema design**: See `references/graphql.md`
- **For rate limiting strategies**: See `references/rate-limiting.md`
- **For SDK design patterns**: See `references/sdk-patterns.md`
- **For OpenAPI code generation and SDK tooling**: See `references/openapi-codegen.md`

## Related Skills

- **@skills/code-error-handling/** - Error handling patterns and exception management
- **@skills/code-code-quality/** - SOLID principles, refactoring, and code review
- **@skills/code-design-patterns/** - GoF design patterns
- **@skills/security-secure-coding/** - API security (CORS, authentication, rate limiting)
- **security/secure-coding** - Rate limiting and API security from a security perspective (OWASP Top 10)
