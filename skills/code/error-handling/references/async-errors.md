---
title: Async Error Handling Reference
category: code
type: reference
version: "1.0.0"
---

# Async Error Handling

> Part of the code/error-handling knowledge skill

## Overview

Asynchronous error handling requires different patterns than synchronous code. This reference covers Promise error handling, async/await patterns, and strategies for managing errors in concurrent operations.

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| try/catch with await | Single async operation |
| Promise.allSettled | Multiple independent operations |
| Error boundaries | Isolate failure domains |
| Retry with backoff | Transient failures |
| Circuit breaker | Prevent cascade failures |
| Timeout wrapper | Prevent hanging operations |

## Patterns

### Pattern 1: Basic Async Error Handling

**When to Use**: Single async operations

**Example**:
```typescript
// Always use try/catch with await
async function fetchUser(id: string): Promise<User> {
  try {
    const response = await fetch(`/api/users/${id}`);

    if (!response.ok) {
      throw new HttpError(response.status, `Failed to fetch user ${id}`);
    }

    return await response.json();
  } catch (error) {
    if (error instanceof HttpError) {
      throw error; // Re-throw known errors
    }

    // Wrap unknown errors
    throw new FetchError(`Failed to fetch user: ${error.message}`, { cause: error });
  }
}

// Custom error types
class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

class FetchError extends Error {
  constructor(message: string, options?: ErrorOptions) {
    super(message, options);
    this.name = 'FetchError';
  }
}

// Never leave promises unhandled
async function main(): Promise<void> {
  try {
    const user = await fetchUser('123');
    console.log(user);
  } catch (error) {
    if (error instanceof HttpError && error.statusCode === 404) {
      console.log('User not found');
    } else {
      console.error('Unexpected error:', error);
      throw error; // Re-throw for global handler
    }
  }
}

// Global unhandled rejection handler
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Log and exit or handle appropriately
});
```

**Anti-Pattern**: Using `.catch()` at the end without proper error handling.

### Pattern 2: Concurrent Operation Errors

**When to Use**: Multiple parallel async operations

**Example**:
```typescript
// Promise.all - fails fast on first error
async function fetchAllOrFail(ids: string[]): Promise<User[]> {
  try {
    return await Promise.all(ids.map(id => fetchUser(id)));
  } catch (error) {
    // One failure = all fail
    throw new AggregateError([error], 'Failed to fetch some users');
  }
}

// Promise.allSettled - get all results, handle failures individually
async function fetchAllWithPartialFailure(ids: string[]): Promise<{
  users: User[];
  errors: Array<{ id: string; error: Error }>;
}> {
  const results = await Promise.allSettled(
    ids.map(async (id) => {
      const user = await fetchUser(id);
      return { id, user };
    })
  );

  const users: User[] = [];
  const errors: Array<{ id: string; error: Error }> = [];

  for (const result of results) {
    if (result.status === 'fulfilled') {
      users.push(result.value.user);
    } else {
      // Extract id from the error context
      const match = result.reason.message.match(/user (\w+)/);
      errors.push({
        id: match?.[1] || 'unknown',
        error: result.reason
      });
    }
  }

  return { users, errors };
}

// Promise.any - succeed if any succeeds
async function fetchFromAnySource(id: string): Promise<User> {
  try {
    return await Promise.any([
      fetchFromPrimaryDb(id),
      fetchFromSecondaryDb(id),
      fetchFromCache(id)
    ]);
  } catch (error) {
    if (error instanceof AggregateError) {
      throw new Error(
        `All sources failed: ${error.errors.map(e => e.message).join(', ')}`
      );
    }
    throw error;
  }
}

// Batch processing with error accumulation
async function processBatch<T, R>(
  items: T[],
  processor: (item: T) => Promise<R>,
  options: { continueOnError?: boolean; maxErrors?: number } = {}
): Promise<{
  results: R[];
  errors: Array<{ item: T; error: Error }>;
}> {
  const { continueOnError = true, maxErrors = Infinity } = options;

  const results: R[] = [];
  const errors: Array<{ item: T; error: Error }> = [];

  for (const item of items) {
    try {
      results.push(await processor(item));
    } catch (error) {
      errors.push({ item, error: error as Error });

      if (!continueOnError || errors.length >= maxErrors) {
        throw new BatchProcessingError(
          `Batch processing failed after ${errors.length} errors`,
          results,
          errors
        );
      }
    }
  }

  return { results, errors };
}

class BatchProcessingError extends Error {
  constructor(
    message: string,
    public readonly successfulResults: any[],
    public readonly errors: Array<{ item: any; error: Error }>
  ) {
    super(message);
    this.name = 'BatchProcessingError';
  }
}
```

**Anti-Pattern**: Using Promise.all when partial success is acceptable.

### Pattern 3: Retry with Exponential Backoff

**When to Use**: Transient failures (network, rate limits)

**Example**:
```typescript
interface RetryOptions {
  maxAttempts: number;
  initialDelayMs: number;
  maxDelayMs: number;
  backoffMultiplier: number;
  retryableErrors?: (error: Error) => boolean;
  onRetry?: (attempt: number, error: Error, delayMs: number) => void;
}

async function withRetry<T>(
  operation: () => Promise<T>,
  options: RetryOptions
): Promise<T> {
  const {
    maxAttempts,
    initialDelayMs,
    maxDelayMs,
    backoffMultiplier,
    retryableErrors = () => true,
    onRetry
  } = options;

  let lastError: Error;
  let delay = initialDelayMs;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error as Error;

      // Check if error is retryable
      if (!retryableErrors(lastError)) {
        throw lastError;
      }

      // Check if we have attempts remaining
      if (attempt === maxAttempts) {
        throw new RetryExhaustedError(
          `Operation failed after ${maxAttempts} attempts`,
          lastError,
          attempt
        );
      }

      // Calculate delay with jitter
      const jitter = Math.random() * 0.3 * delay;
      const actualDelay = Math.min(delay + jitter, maxDelayMs);

      onRetry?.(attempt, lastError, actualDelay);

      await sleep(actualDelay);
      delay *= backoffMultiplier;
    }
  }

  throw lastError!;
}

class RetryExhaustedError extends Error {
  constructor(
    message: string,
    public readonly lastError: Error,
    public readonly attempts: number
  ) {
    super(message);
    this.name = 'RetryExhaustedError';
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Predefined retry strategies
const retryStrategies = {
  network: {
    maxAttempts: 3,
    initialDelayMs: 1000,
    maxDelayMs: 10000,
    backoffMultiplier: 2,
    retryableErrors: (error: Error) => {
      return error.message.includes('ECONNREFUSED') ||
             error.message.includes('ETIMEDOUT') ||
             error.message.includes('ENOTFOUND');
    }
  },

  rateLimit: {
    maxAttempts: 5,
    initialDelayMs: 60000, // Start with 1 minute
    maxDelayMs: 300000,    // Max 5 minutes
    backoffMultiplier: 1.5,
    retryableErrors: (error: Error) => {
      return error instanceof HttpError && error.statusCode === 429;
    }
  },

  database: {
    maxAttempts: 3,
    initialDelayMs: 100,
    maxDelayMs: 1000,
    backoffMultiplier: 2,
    retryableErrors: (error: Error) => {
      return error.message.includes('deadlock') ||
             error.message.includes('connection');
    }
  }
};

// Usage
const user = await withRetry(
  () => fetchUser('123'),
  {
    ...retryStrategies.network,
    onRetry: (attempt, error, delay) => {
      console.log(`Retry ${attempt}: ${error.message}. Waiting ${delay}ms`);
    }
  }
);
```

**Anti-Pattern**: Fixed delay retries that can overwhelm recovering services.

### Pattern 4: Timeout Wrapper

**When to Use**: Preventing operations from hanging indefinitely

**Example**:
```typescript
class TimeoutError extends Error {
  constructor(message: string, public readonly timeoutMs: number) {
    super(message);
    this.name = 'TimeoutError';
  }
}

async function withTimeout<T>(
  operation: Promise<T>,
  timeoutMs: number,
  message?: string
): Promise<T> {
  let timeoutId: NodeJS.Timeout;

  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new TimeoutError(
        message || `Operation timed out after ${timeoutMs}ms`,
        timeoutMs
      ));
    }, timeoutMs);
  });

  try {
    return await Promise.race([operation, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId!);
  }
}

// Cancellable timeout with AbortController
async function withCancellableTimeout<T>(
  operation: (signal: AbortSignal) => Promise<T>,
  timeoutMs: number
): Promise<T> {
  const controller = new AbortController();

  const timeoutId = setTimeout(() => {
    controller.abort();
  }, timeoutMs);

  try {
    return await operation(controller.signal);
  } catch (error) {
    if (error.name === 'AbortError') {
      throw new TimeoutError(
        `Operation timed out after ${timeoutMs}ms`,
        timeoutMs
      );
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}

// Usage with fetch
async function fetchWithTimeout(url: string, timeoutMs: number): Promise<Response> {
  return withCancellableTimeout(
    async (signal) => {
      const response = await fetch(url, { signal });
      if (!response.ok) {
        throw new HttpError(response.status, 'Request failed');
      }
      return response;
    },
    timeoutMs
  );
}

// Combining timeout and retry
async function fetchWithRetryAndTimeout(
  url: string,
  options: {
    timeoutMs: number;
    retryOptions: RetryOptions;
  }
): Promise<Response> {
  return withRetry(
    () => withTimeout(
      fetch(url),
      options.timeoutMs,
      `Request to ${url} timed out`
    ),
    options.retryOptions
  );
}
```

**Anti-Pattern**: Operations without timeout that can hang forever.

### Pattern 5: Circuit Breaker

**When to Use**: Preventing cascade failures in distributed systems

**Example**:
```typescript
enum CircuitState {
  CLOSED = 'CLOSED',     // Normal operation
  OPEN = 'OPEN',         // Failing, reject requests
  HALF_OPEN = 'HALF_OPEN' // Testing if recovered
}

interface CircuitBreakerOptions {
  failureThreshold: number;    // Failures before opening
  successThreshold: number;    // Successes to close from half-open
  timeout: number;             // Time to wait before half-open
  volumeThreshold?: number;    // Min requests before calculating rate
}

class CircuitBreaker<T> {
  private state: CircuitState = CircuitState.CLOSED;
  private failures = 0;
  private successes = 0;
  private lastFailureTime = 0;
  private requestCount = 0;

  constructor(
    private operation: () => Promise<T>,
    private options: CircuitBreakerOptions
  ) {}

  async execute(): Promise<T> {
    this.requestCount++;

    // Check if we should transition to half-open
    if (this.state === CircuitState.OPEN) {
      if (Date.now() - this.lastFailureTime >= this.options.timeout) {
        this.state = CircuitState.HALF_OPEN;
        this.successes = 0;
      } else {
        throw new CircuitOpenError('Circuit is open');
      }
    }

    try {
      const result = await this.operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failures = 0;

    if (this.state === CircuitState.HALF_OPEN) {
      this.successes++;
      if (this.successes >= this.options.successThreshold) {
        this.state = CircuitState.CLOSED;
      }
    }
  }

  private onFailure(): void {
    this.failures++;
    this.lastFailureTime = Date.now();

    if (this.state === CircuitState.HALF_OPEN) {
      this.state = CircuitState.OPEN;
    } else if (
      this.requestCount >= (this.options.volumeThreshold || 0) &&
      this.failures >= this.options.failureThreshold
    ) {
      this.state = CircuitState.OPEN;
    }
  }

  getState(): CircuitState {
    return this.state;
  }

  getStats(): {
    state: CircuitState;
    failures: number;
    successes: number;
    requestCount: number;
  } {
    return {
      state: this.state,
      failures: this.failures,
      successes: this.successes,
      requestCount: this.requestCount
    };
  }

  reset(): void {
    this.state = CircuitState.CLOSED;
    this.failures = 0;
    this.successes = 0;
    this.requestCount = 0;
  }
}

class CircuitOpenError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CircuitOpenError';
  }
}

// Usage
const paymentCircuit = new CircuitBreaker(
  () => paymentService.processPayment(order),
  {
    failureThreshold: 5,
    successThreshold: 2,
    timeout: 30000,
    volumeThreshold: 10
  }
);

async function processOrder(order: Order): Promise<void> {
  try {
    await paymentCircuit.execute();
  } catch (error) {
    if (error instanceof CircuitOpenError) {
      // Fall back to alternative payment method or queue
      await queueForLaterProcessing(order);
    } else {
      throw error;
    }
  }
}

// Monitor circuit state
setInterval(() => {
  const stats = paymentCircuit.getStats();
  console.log('Circuit stats:', stats);
}, 10000);
```

**Anti-Pattern**: No circuit breaker, allowing failures to cascade.

### Pattern 6: Error Boundaries

**When to Use**: Isolating failure domains

**Example**:
```typescript
// Error boundary wrapper
async function withErrorBoundary<T>(
  operation: () => Promise<T>,
  options: {
    fallback?: T | (() => Promise<T>);
    onError?: (error: Error) => void;
    shouldCatch?: (error: Error) => boolean;
  } = {}
): Promise<T> {
  const { fallback, onError, shouldCatch = () => true } = options;

  try {
    return await operation();
  } catch (error) {
    const err = error as Error;

    if (!shouldCatch(err)) {
      throw err;
    }

    onError?.(err);

    if (fallback !== undefined) {
      return typeof fallback === 'function'
        ? await (fallback as () => Promise<T>)()
        : fallback;
    }

    throw err;
  }
}

// Domain-specific error boundaries
class ServiceErrorBoundary {
  constructor(
    private serviceName: string,
    private logger: Logger,
    private metrics: MetricsClient
  ) {}

  wrap<T>(operation: () => Promise<T>, operationName: string): Promise<T> {
    return withErrorBoundary(operation, {
      onError: (error) => {
        this.logger.error({
          service: this.serviceName,
          operation: operationName,
          error: error.message,
          stack: error.stack
        });

        this.metrics.increment('service.errors', {
          service: this.serviceName,
          operation: operationName,
          errorType: error.name
        });
      }
    });
  }

  wrapWithFallback<T>(
    operation: () => Promise<T>,
    fallback: T,
    operationName: string
  ): Promise<T> {
    return withErrorBoundary(operation, {
      fallback,
      onError: (error) => {
        this.logger.warn({
          service: this.serviceName,
          operation: operationName,
          message: 'Using fallback due to error',
          error: error.message
        });
      }
    });
  }
}

// Usage
const userServiceBoundary = new ServiceErrorBoundary('user-service', logger, metrics);

// With fallback
const userPreferences = await userServiceBoundary.wrapWithFallback(
  () => fetchUserPreferences(userId),
  defaultPreferences,
  'fetchUserPreferences'
);

// Without fallback (will throw)
const user = await userServiceBoundary.wrap(
  () => fetchUser(userId),
  'fetchUser'
);
```

**Anti-Pattern**: Catching all errors without proper isolation.

## Checklist

- [ ] All async operations have error handling
- [ ] Errors properly typed and categorized
- [ ] Retry logic with exponential backoff
- [ ] Timeouts on all external calls
- [ ] Circuit breakers for critical dependencies
- [ ] Error boundaries isolate failure domains
- [ ] Unhandled rejection handler configured
- [ ] Errors logged with context
- [ ] Graceful degradation where possible
- [ ] Partial failures handled appropriately

## References

- [Error Handling in Node.js](https://nodejs.org/docs/latest/api/errors.html)
- [Promise Error Handling](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises#error_handling)
- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Exponential Backoff](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)
