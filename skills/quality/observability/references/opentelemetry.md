---
name: OpenTelemetry
description: OpenTelemetry instrumentation for traces, metrics, and logs
category: quality/observability
type: reference
license: Apache-2.0
---

# OpenTelemetry

## Overview

OpenTelemetry (OTel) is the vendor-neutral standard for observability instrumentation. It provides APIs, SDKs, and tools for collecting traces, metrics, and logs.

```
Application (SDK)
  │
  ├── Traces  ─┐
  ├── Metrics ─┼── OTel Collector ──► Backend (Jaeger, Prometheus, etc.)
  └── Logs    ─┘
```

## SDK Setup

### Node.js

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { Resource } = require('@opentelemetry/resources');
const { SEMRESATTRS_SERVICE_NAME } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [SEMRESATTRS_SERVICE_NAME]: 'order-service',
    'deployment.environment': process.env.NODE_ENV,
    'service.version': process.env.APP_VERSION,
  }),
  traceExporter: new OTLPTraceExporter({
    url: 'http://otel-collector:4318/v1/traces',
  }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: 'http://otel-collector:4318/v1/metrics',
    }),
    exportIntervalMillis: 30000,
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

### Python

```python
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

resource = Resource.create({
    "service.name": "order-service",
    "deployment.environment": "production",
})

# Traces
tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317"))
)
trace.set_tracer_provider(tracer_provider)

# Metrics
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint="http://otel-collector:4317"),
    export_interval_millis=30000,
)
metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
```

## Manual Instrumentation

### Creating Spans

```python
tracer = trace.get_tracer("order-service")

@app.post("/orders")
async def create_order(order: OrderRequest):
    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("order.amount", order.amount)
        span.set_attribute("order.items_count", len(order.items))

        # Nested span for database operation
        with tracer.start_as_current_span("save_to_database") as db_span:
            db_span.set_attribute("db.system", "postgresql")
            db_span.set_attribute("db.operation", "INSERT")
            result = await db.orders.insert(order)

        # Nested span for external call
        with tracer.start_as_current_span("notify_payment") as pay_span:
            pay_span.set_attribute("peer.service", "payment-service")
            await payment_service.charge(order)

        span.set_status(StatusCode.OK)
        return result
```

### Recording Errors

```python
with tracer.start_as_current_span("process_payment") as span:
    try:
        result = payment_gateway.charge(amount)
        span.set_status(StatusCode.OK)
    except PaymentError as e:
        span.set_status(StatusCode.ERROR, str(e))
        span.record_exception(e)
        span.set_attribute("payment.error_code", e.code)
        raise
```

### Custom Metrics

```python
meter = metrics.get_meter("order-service")

# Counter
order_counter = meter.create_counter(
    "orders.created",
    description="Total orders created",
    unit="1",
)

# Histogram
order_duration = meter.create_histogram(
    "orders.processing_duration",
    description="Order processing duration",
    unit="ms",
)

# Usage
order_counter.add(1, {"payment_method": "credit_card", "status": "success"})
order_duration.record(duration_ms, {"order_type": "standard"})
```

## OTel Collector Configuration

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 5s
    send_batch_size: 1000

  memory_limiter:
    check_interval: 1s
    limit_mib: 512
    spike_limit_mib: 128

  attributes:
    actions:
      - key: environment
        value: production
        action: upsert

exporters:
  otlp/jaeger:
    endpoint: jaeger:4317
    tls:
      insecure: true

  prometheus:
    endpoint: 0.0.0.0:8889

  loki:
    endpoint: http://loki:3100/loki/api/v1/push

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, attributes]
      exporters: [otlp/jaeger]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [loki]
```

## Context Propagation

Ensure trace context flows across service boundaries:

```python
# HTTP client with automatic propagation
from opentelemetry.instrumentation.requests import RequestsInstrumentor
RequestsInstrumentor().instrument()

# Headers automatically added:
# traceparent: 00-<trace-id>-<span-id>-<flags>
# tracestate: <vendor-specific data>
```

## Semantic Conventions

Use standard attribute names for consistency:

| Attribute | Example | Standard |
|-----------|---------|----------|
| `http.method` | GET, POST | HTTP conventions |
| `http.status_code` | 200, 500 | HTTP conventions |
| `db.system` | postgresql, redis | Database conventions |
| `db.operation` | SELECT, INSERT | Database conventions |
| `messaging.system` | kafka, rabbitmq | Messaging conventions |
| `rpc.system` | grpc | RPC conventions |

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| No resource attributes | Can't filter by service | Always set service.name |
| Tracing every request | High storage cost | Sample (1-10% in production) |
| Missing error recording | Lost debugging context | Always record_exception() |
| No batch processing | Performance degradation | Use BatchSpanProcessor |
| Synchronous export | Blocks request handling | Use async/batch exporters |
