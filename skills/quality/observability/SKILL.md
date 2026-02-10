---
name: observability
description: Observability patterns covering the three pillars: logs, metrics, and traces.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Observability

The three pillars of observability for understanding system behavior in production.

## Quick Reference (80/20)

Focus on these three areas (80% of observability value):

| Pillar | Purpose | Key Tool |
|--------|---------|----------|
| Structured logging | Debug individual requests | JSON logs + correlation ID |
| Metrics | Detect anomalies and trends | Prometheus + Grafana |
| Distributed tracing | Understand request flow | OpenTelemetry + Jaeger |

## Three Pillars Overview

| Pillar | Answers | Cardinality | Storage Cost |
|--------|---------|-------------|-------------|
| Logs | What happened? | High (per event) | High |
| Metrics | How is it performing? | Low (aggregated) | Low |
| Traces | Where is the bottleneck? | Medium (per request) | Medium |

## Structured Logging

Replace unstructured text logs with JSON:

```json
{
  "timestamp": "2024-01-15T10:30:00.123Z",
  "level": "error",
  "message": "Payment processing failed",
  "service": "payment-api",
  "trace_id": "abc123def456",
  "span_id": "789ghi",
  "user_id": "U-1234",
  "order_id": "ORD-5678",
  "error": {
    "type": "PaymentGatewayTimeout",
    "message": "Gateway did not respond within 5s"
  },
  "duration_ms": 5012
}
```

**Rules**:
- Always include correlation/trace ID
- Use consistent field names across services
- Never log secrets, tokens, or PII
- Include context (user, request, operation)

## Metrics

### Four Golden Signals

| Signal | What to Measure | Alert Threshold |
|--------|----------------|-----------------|
| Latency | Request duration (p50, p95, p99) | p99 > 500ms |
| Traffic | Requests per second | Deviation > 2 std dev |
| Errors | Error rate (5xx / total) | > 1% |
| Saturation | CPU, memory, queue depth | > 80% capacity |

### RED Method (Request-driven)

- **R**ate: requests per second
- **E**rrors: failed requests per second
- **D**uration: latency distribution

### USE Method (Resource-driven)

- **U**tilization: % time resource is busy
- **S**aturation: queue length / backlog
- **E**rrors: error count

## Distributed Tracing

A trace follows a request across services:

```
Trace: abc123
├── Span: API Gateway (12ms)
│   └── Span: Auth Service (3ms)
├── Span: Order Service (45ms)
│   ├── Span: Database Query (8ms)
│   └── Span: Payment Service (30ms)
│       └── Span: External Gateway (25ms)
└── Span: Notification Service (5ms)
```

**Key concepts**:
- **Trace**: End-to-end request journey
- **Span**: Single operation within a trace
- **Context propagation**: Passing trace ID across services

## Correlation

Connect all three pillars with a shared trace ID:

```
Log:    {"trace_id": "abc123", "message": "Order created"}
Metric: http_requests_total{trace_id="abc123"} (exemplar)
Trace:  Trace abc123 → spans across 4 services
```

## When to Load References

- **For OpenTelemetry setup**: See `references/opentelemetry.md`
- **For structured logging patterns**: See `references/structured-logging.md`
- **For distributed tracing**: See `references/distributed-tracing.md`

## Cross-References

- **SRE practices**: See `operations/sre-practices` skill
- **Monitoring**: See `operations/monitoring` skill
- **Performance**: See `quality/performance` skill
