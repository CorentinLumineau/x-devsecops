---
name: messaging
description: Use when implementing message queues or event-driven architectures. Covers patterns for decoupled, scalable systems with async communication.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: data
---

# Messaging & Event-Driven Patterns

Asynchronous messaging patterns for decoupled, scalable systems.

## Quick Reference (80/20)

Focus on these three decisions (80% of messaging success):

| Decision | Key Factor | Default Choice |
|----------|-----------|----------------|
| Broker selection | Throughput vs simplicity | Kafka for streams, RabbitMQ for tasks |
| Delivery guarantee | Business requirements | At-least-once + idempotent consumers |
| Error handling | Failure recovery | Dead letter queues with retry |

## Broker Comparison

| Feature | Kafka | RabbitMQ | SQS/SNS |
|---------|-------|----------|---------|
| Model | Log-based stream | Message broker | Managed queue |
| Ordering | Per-partition | Per-queue (FIFO) | FIFO optional |
| Throughput | Very high (millions/s) | High (10K+/s) | High (managed) |
| Retention | Configurable (days/forever) | Until consumed | 14 days max |
| Replay | Yes (offset reset) | No | No |
| Use case | Event streaming, audit logs | Task queues, RPC | Cloud-native async |
| Ops burden | High (ZooKeeper/KRaft) | Medium | None (managed) |

## Core Patterns

### Point-to-Point (Queue)

One producer, one consumer per message. Use for task distribution.

```
Producer --> [Queue] --> Consumer
                     --> Consumer  (competing consumers)
```

### Publish-Subscribe (Topic)

One producer, many consumers. Use for event broadcasting.

```
Producer --> [Topic] --> Consumer A (notifications)
                     --> Consumer B (analytics)
                     --> Consumer C (audit)
```

### Request-Reply

Synchronous-style communication over async transport.

```
Client --> [Request Queue] --> Server
Client <-- [Reply Queue]   <-- Server
```

## Delivery Guarantees

| Guarantee | Behavior | Risk |
|-----------|----------|------|
| At-most-once | Fire and forget | Message loss |
| At-least-once | Retry until ack | Duplicates |
| Exactly-once | Transactional | Performance cost |

**Default recommendation**: At-least-once delivery with idempotent consumers.

### Idempotent Consumer Pattern

```python
def handle_message(message):
    idempotency_key = message.headers["idempotency-key"]

    if already_processed(idempotency_key):
        return  # Skip duplicate

    process(message)
    mark_processed(idempotency_key)
    acknowledge(message)
```

## Dead Letter Queues (DLQ)

Messages that fail processing after retries go to a DLQ for investigation.

```yaml
retry_policy:
  max_retries: 3
  backoff: exponential
  initial_delay: 1s
  max_delay: 30s
  dlq: "orders-dlq"
```

**DLQ handling**:
1. Alert on DLQ depth > 0
2. Inspect failed messages (log reason)
3. Fix the consumer bug
4. Replay messages from DLQ

## Message Design

```json
{
  "id": "evt-uuid-1234",
  "type": "order.created",
  "source": "order-service",
  "time": "2024-01-15T10:30:00Z",
  "datacontenttype": "application/json",
  "data": {
    "orderId": "ORD-5678",
    "amount": 99.99,
    "currency": "USD"
  }
}
```

**Best practices**:
- Include correlation ID for tracing
- Use CloudEvents format for interoperability
- Keep messages small (< 1MB); use claim-check for large payloads
- Version your schemas (Avro, Protobuf, JSON Schema)

## Quick Reference

| Task | Approach |
|------|----------|
| Task distribution | Point-to-point queue with competing consumers |
| Event broadcasting | Publish-subscribe with topic/fanout |
| Reliable delivery | At-least-once + idempotent consumers |
| Failed message handling | Dead letter queues with alerting |
| High throughput streaming | Kafka with partitioning |
| Simple task routing | RabbitMQ with exchanges |
| Cloud-native async | SQS/SNS managed queues |
| Schema evolution | Schema registry (Avro/Protobuf) |

## Checklist

### Design Phase
- [ ] Broker selected based on requirements (Kafka vs RabbitMQ vs managed)
- [ ] Delivery guarantee chosen (default: at-least-once)
- [ ] Message schema defined with versioning
- [ ] Dead letter queue strategy planned

### Implementation
- [ ] Idempotent consumers implemented
- [ ] Retry policy with exponential backoff configured
- [ ] DLQ monitoring and alerting in place
- [ ] Correlation IDs included for tracing

### Operations
- [ ] Consumer lag monitored
- [ ] DLQ depth alerting configured
- [ ] Schema compatibility enforced
- [ ] Capacity planning documented

## When to Load References

- **For Kafka patterns**: See `references/kafka-patterns.md`
- **For RabbitMQ patterns**: See `references/rabbitmq-patterns.md`
- **For event-driven architecture**: See `references/event-driven.md`

## Related Skills

- `data/data-persistence` - Database and caching patterns
- `code/api-design` - API design for service communication
- `code/error-handling` - Error handling patterns
- `operations/observability` - Monitoring and tracing
- `meta/analysis-architecture` - Event-driven architecture patterns from an architectural perspective
