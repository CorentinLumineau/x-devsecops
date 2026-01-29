---
name: Distributed Tracing
description: Distributed tracing patterns for understanding request flow across services
category: quality/observability
type: reference
license: Apache-2.0
---

# Distributed Tracing

## Core Concepts

```
Trace (single request journey)
├── Span A: API Gateway (entry point)
│   ├── Span B: Auth Service
│   └── Span C: Order Service
│       ├── Span D: Database Query
│       └── Span E: Payment Service
│           └── Span F: External Gateway
```

| Concept | Definition |
|---------|-----------|
| Trace | Complete request journey, identified by trace_id |
| Span | Single operation within a trace |
| Parent Span | Span that called the current span |
| Baggage | Key-value pairs propagated across services |
| Context | Trace information passed between services |

## Trace Anatomy

```json
{
  "traceId": "abc123def456789",
  "spans": [
    {
      "spanId": "span-001",
      "parentSpanId": null,
      "operationName": "HTTP GET /orders/123",
      "serviceName": "api-gateway",
      "startTime": "2024-01-15T10:30:00.000Z",
      "duration": 150,
      "status": "OK",
      "tags": {
        "http.method": "GET",
        "http.url": "/orders/123",
        "http.status_code": 200
      }
    },
    {
      "spanId": "span-002",
      "parentSpanId": "span-001",
      "operationName": "order_service.get_order",
      "serviceName": "order-service",
      "startTime": "2024-01-15T10:30:00.010Z",
      "duration": 85,
      "status": "OK",
      "tags": {
        "order.id": "ORD-123"
      },
      "logs": [
        {"timestamp": "...", "event": "cache_miss"}
      ]
    }
  ]
}
```

## Context Propagation

### W3C Trace Context (Standard)

```
HTTP Headers:
  traceparent: 00-<trace-id>-<parent-span-id>-<flags>
  tracestate: vendor1=value1,vendor2=value2

Example:
  traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
               ^^ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ^^^^^^^^^^^^^^^^ ^^
               ver         trace-id (32 hex)       span-id (16 hex) flags
```

### Propagation Code

```python
from opentelemetry.propagate import inject, extract
from opentelemetry.trace import get_current_span
import requests

# Inject context into outgoing request
def call_external_service(url, data):
    headers = {}
    inject(headers)  # Adds traceparent header

    return requests.post(url, json=data, headers=headers)

# Extract context from incoming request (middleware)
def tracing_middleware(request):
    context = extract(request.headers)

    with tracer.start_as_current_span(
        "handle_request",
        context=context
    ) as span:
        # Process request
        pass
```

## Sampling Strategies

Tracing every request is expensive. Use sampling:

| Strategy | Description | Use Case |
|----------|-------------|----------|
| Head-based | Decide at trace start | Simple, consistent |
| Tail-based | Decide after trace complete | Keep errors/slow requests |
| Rate-based | Fixed N traces/second | Predictable storage |
| Priority | Always trace certain requests | Debug specific users |

### Head-Based Sampling

```python
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased, ParentBased

# Sample 10% of traces
sampler = ParentBased(
    root=TraceIdRatioBased(0.1),  # 10% of root spans
)

# Parent-based: if parent is sampled, child is sampled
# Ensures complete traces (no orphan spans)
```

### Priority Sampling

```python
class PrioritySampler:
    def should_sample(self, context, trace_id, name, kind, attributes, links):
        # Always sample errors
        if attributes.get("error"):
            return Decision.RECORD_AND_SAMPLE

        # Always sample specific users (debugging)
        if attributes.get("user.id") in DEBUG_USERS:
            return Decision.RECORD_AND_SAMPLE

        # Always sample slow requests
        if attributes.get("http.latency_ms", 0) > 1000:
            return Decision.RECORD_AND_SAMPLE

        # Otherwise, 5% sampling
        if random.random() < 0.05:
            return Decision.RECORD_AND_SAMPLE

        return Decision.DROP
```

## Span Best Practices

### What to Trace

| Always Trace | Sometimes Trace | Don't Trace |
|-------------|-----------------|-------------|
| HTTP requests | CPU-bound functions | Simple getters |
| Database queries | Cache operations | Logging statements |
| External API calls | Pub/sub operations | Utility functions |
| Queue operations | File I/O | Loop iterations |

### Adding Context

```python
with tracer.start_as_current_span("process_payment") as span:
    # Attributes: indexed, searchable key-value pairs
    span.set_attribute("payment.method", "credit_card")
    span.set_attribute("payment.amount", 99.99)
    span.set_attribute("payment.currency", "USD")

    # Events: timestamped logs within the span
    span.add_event("validation_complete", {"rules_checked": 5})
    span.add_event("gateway_called", {"gateway": "stripe"})

    # Status: OK, ERROR, or UNSET
    span.set_status(StatusCode.OK)
```

### Error Recording

```python
with tracer.start_as_current_span("database_query") as span:
    try:
        result = db.execute(query)
    except DatabaseError as e:
        span.set_status(StatusCode.ERROR, str(e))
        span.record_exception(e)
        span.set_attribute("db.error_code", e.code)
        raise
```

## Service Dependencies

Traces reveal service topology:

```
api-gateway
  └── calls → auth-service (12ms avg)
  └── calls → order-service (45ms avg)
                └── calls → inventory-db (8ms avg)
                └── calls → payment-service (30ms avg)
                              └── calls → stripe-api (25ms avg)
```

Use tracing data to:
- Identify critical path bottlenecks
- Detect cascading failures
- Plan capacity (which services need scaling)
- Find N+1 query problems

## Trace Analysis Queries

### Find Slow Traces

```
# Jaeger query
service=order-service AND duration>500ms

# Tempo/TraceQL
{duration > 500ms} | select(span.service)
```

### Error Rate by Operation

```promql
# Prometheus metrics from traces
sum(rate(trace_span_total{status="error"}[5m])) by (operation)
/
sum(rate(trace_span_total[5m])) by (operation)
```

### Identify Bottlenecks

```
# Find spans that are >50% of trace duration
SELECT
  trace_id,
  span_name,
  duration,
  duration / trace_duration * 100 as pct_of_trace
FROM spans
WHERE pct_of_trace > 50
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| No context propagation | Broken traces | Use standard W3C headers |
| Tracing everything | High cost, noise | Sample 1-10% in production |
| Missing error recording | No failure visibility | Always record_exception() |
| Synchronous export | Latency overhead | Use batch/async exporters |
| No service.name | Can't filter by service | Always set resource attributes |
| Ignoring baggage | Lost request context | Propagate user_id, tenant_id |
