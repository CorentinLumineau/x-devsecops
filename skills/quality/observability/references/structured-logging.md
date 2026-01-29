---
name: Structured Logging
description: JSON structured logging patterns, log levels, and correlation
category: quality/observability
type: reference
license: Apache-2.0
---

# Structured Logging

## Why Structured Logging?

```
# Unstructured (hard to parse, search, filter):
2024-01-15 10:30:00 ERROR Failed to process order ORD-5678 for user U-1234: timeout

# Structured JSON (machine-parseable, searchable):
{"timestamp":"2024-01-15T10:30:00Z","level":"error","message":"Failed to process order",
 "order_id":"ORD-5678","user_id":"U-1234","error":"timeout","service":"order-api"}
```

## Log Schema

Define a consistent schema across all services:

```json
{
  "timestamp": "2024-01-15T10:30:00.123Z",
  "level": "info|warn|error|debug",
  "message": "Human-readable description",
  "service": "service-name",
  "version": "1.2.3",
  "environment": "production",
  "trace_id": "abc123",
  "span_id": "def456",
  "request_id": "req-789",
  "user_id": "U-1234",
  "duration_ms": 145,
  "error": {
    "type": "ErrorClassName",
    "message": "Detailed error message",
    "stack": "stack trace (non-prod only)"
  },
  "context": {}
}
```

## Implementation

### Node.js (Pino)

```javascript
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level(label) { return { level: label }; }
  },
  base: {
    service: 'order-api',
    version: process.env.APP_VERSION,
    environment: process.env.NODE_ENV,
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  // Redact sensitive fields
  redact: ['req.headers.authorization', 'user.email', 'body.password'],
});

// Usage
logger.info({ order_id: 'ORD-5678', amount: 99.99 }, 'Order created');
logger.error({ err, order_id: 'ORD-5678' }, 'Order processing failed');
```

### Python (structlog)

```python
import structlog

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
)

logger = structlog.get_logger(service="order-api")

# Bind context for request lifecycle
log = logger.bind(request_id="req-123", user_id="U-1234")
log.info("order_created", order_id="ORD-5678", amount=99.99)
log.error("order_failed", order_id="ORD-5678", error="timeout")
```

### Go (zerolog)

```go
package main

import (
    "os"
    "github.com/rs/zerolog"
    "github.com/rs/zerolog/log"
)

func init() {
    zerolog.TimeFieldFormat = zerolog.TimeFormatUnix
    log.Logger = zerolog.New(os.Stdout).With().
        Str("service", "order-api").
        Str("version", os.Getenv("APP_VERSION")).
        Timestamp().
        Logger()
}

func processOrder(orderID string) {
    log.Info().
        Str("order_id", orderID).
        Float64("amount", 99.99).
        Msg("Order created")
}
```

## Log Levels

| Level | When to Use | Example |
|-------|-------------|---------|
| `error` | Operation failed, needs attention | Payment gateway timeout |
| `warn` | Degraded but still functioning | Cache miss, retry succeeded |
| `info` | Significant business events | Order created, user signed in |
| `debug` | Diagnostic details | SQL query, cache hit/miss |
| `trace` | Verbose debugging (rarely in prod) | Function entry/exit |

**Rules**:
- Production default: `info`
- Never log at `debug` in production by default
- `error` should be actionable (someone should investigate)
- `warn` means degraded but not broken

## Correlation IDs

Pass a trace/correlation ID through the entire request chain:

```python
# Middleware to extract or generate correlation ID
@app.middleware("http")
async def correlation_middleware(request, call_next):
    trace_id = request.headers.get("X-Trace-ID", str(uuid4()))

    # Bind to structlog context for all logs in this request
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(
        trace_id=trace_id,
        request_path=request.url.path,
        method=request.method,
    )

    response = await call_next(request)
    response.headers["X-Trace-ID"] = trace_id
    return response
```

## Sensitive Data Handling

Never log:

| Field | Risk | Alternative |
|-------|------|-------------|
| Passwords | Credential exposure | Log "password changed" event |
| API keys/tokens | Access compromise | Log key ID or last 4 chars |
| Credit cards | Financial fraud | Log last 4 digits only |
| SSN/ID numbers | Identity theft | Log "verified" boolean |
| Email/phone | Privacy violation | Log hashed or masked |
| Session tokens | Session hijacking | Log session ID prefix |

```python
# Redaction helper
def redact(value, visible_chars=4):
    if not value or len(value) <= visible_chars:
        return "***"
    return "***" + value[-visible_chars:]

# Usage
logger.info("payment_processed",
    card=redact("4111111111111234"),  # "***1234"
    amount=99.99
)
```

## Log Aggregation Query Patterns

### Finding Errors for a Request

```
# Elasticsearch / OpenSearch
{
  "query": {
    "bool": {
      "must": [
        {"term": {"trace_id": "abc123"}},
        {"term": {"level": "error"}}
      ]
    }
  },
  "sort": [{"timestamp": "asc"}]
}
```

### Error Rate by Service

```
# Loki LogQL
sum(rate({level="error"}[5m])) by (service)
/
sum(rate({level=~"info|warn|error"}[5m])) by (service)
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| Logging PII | Compliance violation | Redact sensitive fields |
| No correlation ID | Can't trace requests | Add middleware to inject ID |
| Inconsistent field names | Can't query across services | Define shared schema |
| Too verbose in production | Storage cost, noise | Default to info level |
| Logging in hot loops | Performance degradation | Log aggregates, not each iteration |
| Stack traces in production | Information disclosure | Only in non-prod or error level |
