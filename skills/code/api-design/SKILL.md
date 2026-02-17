---
name: api-design
description: REST API, GraphQL, and SDK design best practices. Resource naming, versioning, pagination, client libraries, code generation.
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

### Core Principles

| Principle | Implementation |
|-----------|----------------|
| Idiomatic | Follow language conventions |
| Consistent | Same patterns throughout |
| Typed | Strong typing, autocomplete |
| Documented | Inline docs, examples |
| Tested | High coverage, integration tests |

### Developer Experience

```typescript
// Good: Fluent, discoverable API
const user = await client.users
  .get('123')
  .include('orders')
  .execute();

// Bad: Complex, unclear API
const user = await client.request(
  'GET', '/users/123', { include: ['orders'] }
);
```

### SDK Error Handling

| Error Type | HTTP Status | Usage |
|------------|-------------|-------|
| ValidationError | 400 | Input validation failures |
| UnauthorizedError | 401 | Authentication required |
| ForbiddenError | 403 | Insufficient permissions |
| NotFoundError | 404 | Resource does not exist |
| RateLimitError | 429 | Too many requests |
| ServerError | 5xx | Internal server errors |

### Retry Logic

| Aspect | Recommendation |
|--------|----------------|
| Strategy | Exponential backoff with jitter |
| Retryable codes | 429, 500, 502, 503, 504 |
| Max retries | 3 (configurable) |
| Max delay | 10 seconds |
| Non-retryable | 400, 401, 403, 404, 422 |

### SDK Versioning

| Change | Version Bump | Example |
|--------|--------------|---------|
| Breaking API change | Major | 1.0.0 -> 1.0.0 |
| New feature, backward compatible | Minor | 1.0.0 -> 1.1.0 |
| Bug fix | Patch | 1.0.0 -> 1.0.1 |

### Client Configuration (Builder Pattern)

```typescript
const client = new APIClient.Builder()
  .baseUrl('https://api.example.com')
  .apiKey(process.env.API_KEY)
  .timeout(5000)
  .retryConfig({ maxRetries: 3 })
  .build();
```

## OpenAPI Code Generation

| Tool | Language Support | Notes |
|------|-----------------|-------|
| openapi-generator-cli | 40+ languages | Most comprehensive |
| @graphql-codegen/cli | TypeScript, Flow | GraphQL-specific |
| oapi-codegen | Go | Go-native |
| swagger-codegen | Java ecosystem | Legacy, use openapi-generator instead |

### Generation Workflow

```
1. Design API spec (openapi.yaml)
2. Validate spec (spectral lint)
3. Generate client code
4. Add wrapper class for DX
5. Add interceptors (auth, logging, retry)
6. Publish as package
```

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
- **For OpenAPI code generation and SDK tooling**: See `references/openapi-codegen.md`

## Related Skills

- **@skills/code-error-handling/** - Error handling patterns and exception management
- **@skills/code-code-quality/** - SOLID principles, refactoring, and code review
- **@skills/code-design-patterns/** - GoF design patterns
- **@skills/security-api-security/** - API security (CORS, authentication, rate limiting)
- **security/secure-coding** - Rate limiting and API security from a security perspective (OWASP Top 10)
