---
name: sdk-design
description: |
  SDK and API client design patterns, OpenAPI/GraphQL code generation, versioning.
  Activate when designing SDKs, generating clients, or managing API client libraries.
  Triggers: sdk, api client, codegen, openapi, graphql client, versioning, client library.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: code
---

# SDK Design

API client and SDK design patterns.

## 80/20 Focus

Master these (covers 80% of SDK design):

| Pattern | Impact |
|---------|--------|
| Generated clients | Consistency, maintenance |
| Retry logic | Reliability |
| Error handling | Developer experience |
| Versioning | Backward compatibility |

## SDK Design Principles

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

## Code Generation

### OpenAPI Generator

```bash
# Install
npm install @openapitools/openapi-generator-cli -g

# Generate TypeScript client
openapi-generator-cli generate \
  -i ./openapi.yaml \
  -g typescript-axios \
  -o ./generated/client

# Generate with config
openapi-generator-cli generate \
  -i ./openapi.yaml \
  -g typescript-axios \
  -o ./generated/client \
  -c ./codegen-config.yaml
```

**Config Example:**
```yaml
# codegen-config.yaml
npmName: "@company/api-client"
npmVersion: "1.0.0"
withSeparateModelsAndApi: true
modelPackage: models
apiPackage: api
```

### GraphQL Codegen

```bash
# Install
npm install @graphql-codegen/cli

# Generate
npx graphql-codegen --config codegen.ts
```

**Config Example:**
```typescript
// codegen.ts
import { CodegenConfig } from '@graphql-codegen/cli';

const config: CodegenConfig = {
  schema: 'https://api.example.com/graphql',
  documents: ['src/**/*.graphql'],
  generates: {
    './src/generated/': {
      preset: 'client',
      plugins: ['typescript', 'typescript-operations']
    }
  }
};
```

## Error Handling

### Error Types

```typescript
// Base SDK error
class SDKError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode?: number,
    public details?: unknown
  ) {
    super(message);
    this.name = 'SDKError';
  }
}

// Specific errors
class NetworkError extends SDKError {
  constructor(message: string, public cause?: Error) {
    super(message, 'NETWORK_ERROR');
  }
}

class ValidationError extends SDKError {
  constructor(message: string, public fields: Record<string, string>) {
    super(message, 'VALIDATION_ERROR', 400);
  }
}

class RateLimitError extends SDKError {
  constructor(public retryAfter: number) {
    super(`Rate limited. Retry after ${retryAfter}s`, 'RATE_LIMIT', 429);
  }
}
```

### Error Response Mapping

```typescript
function mapError(response: Response): SDKError {
  switch (response.status) {
    case 400:
      return new ValidationError('Validation failed', response.data.errors);
    case 401:
      return new SDKError('Unauthorized', 'UNAUTHORIZED', 401);
    case 403:
      return new SDKError('Forbidden', 'FORBIDDEN', 403);
    case 404:
      return new SDKError('Not found', 'NOT_FOUND', 404);
    case 429:
      return new RateLimitError(response.headers['retry-after']);
    default:
      return new SDKError('Server error', 'SERVER_ERROR', response.status);
  }
}
```

## Retry Logic

### Exponential Backoff

```typescript
interface RetryConfig {
  maxRetries: number;
  baseDelay: number;
  maxDelay: number;
  retryableStatuses: number[];
}

async function withRetry<T>(
  fn: () => Promise<T>,
  config: RetryConfig = {
    maxRetries: 3,
    baseDelay: 1000,
    maxDelay: 10000,
    retryableStatuses: [429, 500, 502, 503, 504]
  }
): Promise<T> {
  let lastError: Error;

  for (let attempt = 0; attempt <= config.maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;

      if (!isRetryable(error, config)) throw error;
      if (attempt === config.maxRetries) throw error;

      const delay = Math.min(
        config.baseDelay * Math.pow(2, attempt),
        config.maxDelay
      );

      await sleep(delay + Math.random() * 1000); // Jitter
    }
  }

  throw lastError!;
}
```

## SDK Versioning

### Semantic Versioning

| Change | Version Bump | Example |
|--------|--------------|---------|
| Breaking API change | Major | 1.0.0 → 2.0.0 |
| New feature, backward compatible | Minor | 1.0.0 → 1.1.0 |
| Bug fix | Patch | 1.0.0 → 1.0.1 |

### API Version Handling

```typescript
class APIClient {
  constructor(
    private config: {
      apiVersion: string;
      baseUrl: string;
    }
  ) {}

  private get headers() {
    return {
      'X-API-Version': this.config.apiVersion,
      'Accept': `application/vnd.api.${this.config.apiVersion}+json`
    };
  }
}

// Usage
const v1Client = new APIClient({ apiVersion: 'v1', baseUrl: '...' });
const v2Client = new APIClient({ apiVersion: 'v2', baseUrl: '...' });
```

### Deprecation Strategy

```typescript
/**
 * @deprecated Use `getUser` instead. Will be removed in v3.0.0
 */
async function fetchUser(id: string) {
  console.warn('fetchUser is deprecated. Use getUser instead.');
  return this.getUser(id);
}
```

## Client Configuration

### Builder Pattern

```typescript
const client = new APIClient.Builder()
  .baseUrl('https://api.example.com')
  .apiKey(process.env.API_KEY)
  .timeout(5000)
  .retryConfig({ maxRetries: 3 })
  .logger(console)
  .build();
```

### Configuration Options

```typescript
interface ClientConfig {
  // Required
  apiKey: string;

  // Optional with defaults
  baseUrl?: string;
  timeout?: number;
  retries?: number;

  // Hooks
  onRequest?: (config: RequestConfig) => RequestConfig;
  onResponse?: (response: Response) => Response;
  onError?: (error: Error) => Error | void;

  // Logging
  logger?: Logger;
  logLevel?: 'debug' | 'info' | 'warn' | 'error';
}
```

## Pagination

### Cursor-Based

```typescript
interface Page<T> {
  data: T[];
  nextCursor?: string;
  hasMore: boolean;
}

async function* paginate<T>(
  fetcher: (cursor?: string) => Promise<Page<T>>
): AsyncGenerator<T> {
  let cursor: string | undefined;

  do {
    const page = await fetcher(cursor);
    for (const item of page.data) {
      yield item;
    }
    cursor = page.nextCursor;
  } while (cursor);
}

// Usage
for await (const user of client.users.list()) {
  console.log(user.name);
}
```

## Testing SDKs

### Mock Strategies

```typescript
// 1. MSW (Mock Service Worker)
import { setupServer } from 'msw/node';

const server = setupServer(
  rest.get('/users/:id', (req, res, ctx) => {
    return res(ctx.json({ id: req.params.id, name: 'Test' }));
  })
);

// 2. Dependency Injection
const client = new APIClient({
  httpClient: mockHttpClient
});

// 3. Recording/Playback
import nock from 'nock';
nock('https://api.example.com')
  .get('/users/123')
  .reply(200, { id: '123', name: 'Test' });
```

## Checklist

### Design
- [ ] Language idioms followed
- [ ] Consistent API surface
- [ ] Strong typing throughout
- [ ] Comprehensive documentation

### Implementation
- [ ] Error types defined
- [ ] Retry logic implemented
- [ ] Timeout handling
- [ ] Rate limit handling
- [ ] Logging/debugging support

### Quality
- [ ] Unit tests (>80% coverage)
- [ ] Integration tests
- [ ] Documentation generated
- [ ] Changelog maintained
- [ ] Examples provided

## When to Load References

- **For OpenAPI patterns**: See `references/openapi-codegen.md`
- **For GraphQL clients**: See `references/graphql-clients.md`
- **For testing patterns**: See `references/sdk-testing.md`
