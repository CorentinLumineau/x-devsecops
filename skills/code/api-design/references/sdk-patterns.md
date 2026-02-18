# SDK Design Patterns

Detailed patterns for building client libraries and SDKs.

## Core Principles

| Principle | Implementation |
|-----------|----------------|
| Idiomatic | Follow language conventions |
| Consistent | Same patterns throughout |
| Typed | Strong typing, autocomplete |
| Documented | Inline docs, examples |
| Tested | High coverage, integration tests |

## Developer Experience

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

## SDK Error Handling

| Error Type | HTTP Status | Usage |
|------------|-------------|-------|
| ValidationError | 400 | Input validation failures |
| UnauthorizedError | 401 | Authentication required |
| ForbiddenError | 403 | Insufficient permissions |
| NotFoundError | 404 | Resource does not exist |
| RateLimitError | 429 | Too many requests |
| ServerError | 5xx | Internal server errors |

## Retry Logic

| Aspect | Recommendation |
|--------|----------------|
| Strategy | Exponential backoff with jitter |
| Retryable codes | 429, 500, 502, 503, 504 |
| Max retries | 3 (configurable) |
| Max delay | 10 seconds |
| Non-retryable | 400, 401, 403, 404, 422 |

## SDK Versioning

| Change | Version Bump | Example |
|--------|--------------|---------|
| Breaking API change | Major | 1.0.0 -> 2.0.0 |
| New feature, backward compatible | Minor | 1.0.0 -> 1.1.0 |
| Bug fix | Patch | 1.0.0 -> 1.0.1 |

## Client Configuration (Builder Pattern)

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
