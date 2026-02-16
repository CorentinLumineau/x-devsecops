---
title: Event-Driven Architecture Reference
category: meta
type: reference
version: "1.0.0"
---

# Event-Driven Architecture

> Part of the meta/architecture-patterns knowledge skill

## Overview

Event-driven architecture (EDA) uses events as the primary mechanism for communication between components. Events represent facts that have occurred, enabling loose coupling, scalability, and real-time responsiveness.

## Quick Reference (80/20)

| Concept | Definition |
|---------|-----------|
| Event | Immutable fact that something happened |
| Event Producer | Component that emits events |
| Event Consumer | Component that reacts to events |
| Event Broker | Infrastructure that routes events |
| Event Sourcing | Storing state as sequence of events |

## Patterns

### Pattern 1: Event Types

**When to Use**: Choosing the right event granularity

**Example**:
```typescript
// Domain Event - business-meaningful occurrence
interface OrderPlaced {
  type: "OrderPlaced";
  orderId: string;
  customerId: string;
  items: Array<{ productId: string; quantity: number; price: number }>;
  totalAmount: number;
  occurredAt: string;  // ISO 8601
}

// Integration Event - cross-service notification
interface OrderPlacedIntegration {
  type: "order.placed";
  version: "1.0";
  source: "order-service";
  id: string;           // Unique event ID
  time: string;
  data: {
    orderId: string;
    customerId: string;
    totalAmount: number;
  };
  // Does NOT include internal details like item prices
}

// Change Data Capture (CDC) Event - database change
interface CDCEvent {
  before: { status: "pending" } | null;
  after: { status: "confirmed" };
  source: {
    table: "orders";
    db: "orders_db";
    connector: "debezium";
  };
  op: "u";  // c=create, u=update, d=delete
  ts_ms: number;
}
```

**Anti-Pattern**: Putting too much data in events (event as database query replacement).

### Pattern 2: Publish-Subscribe with Kafka

**When to Use**: High-throughput, durable event streaming

**Example**:
```python
# producer.py - Publishing events to Kafka
from confluent_kafka import Producer
import json
import uuid
from datetime import datetime

class EventPublisher:
    def __init__(self, bootstrap_servers: str):
        self.producer = Producer({
            "bootstrap.servers": bootstrap_servers,
            "acks": "all",
            "enable.idempotence": True,
            "retries": 5,
        })

    def publish(self, topic: str, event: dict, key: str = None):
        envelope = {
            "id": str(uuid.uuid4()),
            "type": event["type"],
            "source": "order-service",
            "time": datetime.utcnow().isoformat() + "Z",
            "data": event,
        }

        self.producer.produce(
            topic=topic,
            key=key.encode() if key else None,
            value=json.dumps(envelope).encode(),
            callback=self._delivery_callback,
        )
        self.producer.flush()

    def _delivery_callback(self, err, msg):
        if err:
            print(f"Delivery failed: {err}")
        else:
            print(f"Delivered to {msg.topic()} [{msg.partition()}]")

# Usage
publisher = EventPublisher("kafka:9092")
publisher.publish(
    topic="orders",
    event={
        "type": "OrderPlaced",
        "orderId": "ord_123",
        "customerId": "cust_456",
        "totalAmount": 99.99,
    },
    key="ord_123",
)
```

```python
# consumer.py - Consuming events from Kafka
from confluent_kafka import Consumer, KafkaError
import json

class EventConsumer:
    def __init__(self, bootstrap_servers: str, group_id: str, topics: list[str]):
        self.consumer = Consumer({
            "bootstrap.servers": bootstrap_servers,
            "group.id": group_id,
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        })
        self.consumer.subscribe(topics)
        self.handlers = {}

    def register(self, event_type: str, handler):
        self.handlers[event_type] = handler

    def run(self):
        while True:
            msg = self.consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() != KafkaError._PARTITION_EOF:
                    print(f"Error: {msg.error()}")
                continue

            envelope = json.loads(msg.value())
            event_type = envelope.get("type")

            handler = self.handlers.get(event_type)
            if handler:
                try:
                    handler(envelope["data"])
                    self.consumer.commit(msg)
                except Exception as e:
                    print(f"Handler failed for {event_type}: {e}")
                    # Dead letter queue or retry logic
            else:
                print(f"No handler for {event_type}")
                self.consumer.commit(msg)

# Usage
consumer = EventConsumer("kafka:9092", "inventory-service", ["orders"])
consumer.register("OrderPlaced", handle_order_placed)
consumer.run()
```

**Anti-Pattern**: Not committing offsets after processing (risk of duplicate processing or data loss).

### Pattern 3: Event Sourcing

**When to Use**: Full audit trail needed, or complex domain requiring state reconstruction

**Example**:
```python
# event_store.py
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

@dataclass
class StoredEvent:
    aggregate_id: str
    aggregate_type: str
    event_type: str
    data: dict
    version: int
    timestamp: datetime = field(default_factory=datetime.utcnow)

class EventStore:
    def __init__(self):
        self._events: list[StoredEvent] = []

    def append(self, aggregate_id: str, aggregate_type: str,
               events: list[dict], expected_version: int):
        current = self._get_version(aggregate_id)
        if current != expected_version:
            raise ConcurrencyError(
                f"Expected version {expected_version}, got {current}"
            )

        for i, event in enumerate(events):
            self._events.append(StoredEvent(
                aggregate_id=aggregate_id,
                aggregate_type=aggregate_type,
                event_type=event["type"],
                data=event,
                version=expected_version + i + 1,
            ))

    def get_events(self, aggregate_id: str) -> list[StoredEvent]:
        return [e for e in self._events if e.aggregate_id == aggregate_id]

    def _get_version(self, aggregate_id: str) -> int:
        events = self.get_events(aggregate_id)
        return events[-1].version if events else 0


# Aggregate that rebuilds from events
class Order:
    def __init__(self):
        self.id = None
        self.status = None
        self.items = []
        self.total = 0
        self._version = 0
        self._pending_events = []

    def place(self, order_id: str, items: list, total: float):
        self._apply({"type": "OrderPlaced", "orderId": order_id,
                      "items": items, "total": total})

    def confirm(self):
        if self.status != "placed":
            raise ValueError("Can only confirm placed orders")
        self._apply({"type": "OrderConfirmed", "orderId": self.id})

    def cancel(self, reason: str):
        if self.status == "shipped":
            raise ValueError("Cannot cancel shipped orders")
        self._apply({"type": "OrderCancelled", "orderId": self.id,
                      "reason": reason})

    def _apply(self, event: dict):
        self._handle(event)
        self._pending_events.append(event)

    def _handle(self, event: dict):
        if event["type"] == "OrderPlaced":
            self.id = event["orderId"]
            self.items = event["items"]
            self.total = event["total"]
            self.status = "placed"
        elif event["type"] == "OrderConfirmed":
            self.status = "confirmed"
        elif event["type"] == "OrderCancelled":
            self.status = "cancelled"
        self._version += 1

    @classmethod
    def from_events(cls, events: list[StoredEvent]) -> "Order":
        order = cls()
        for event in events:
            order._handle(event.data)
        return order
```

**Anti-Pattern**: Using event sourcing for simple CRUD without audit/temporal requirements.

### Pattern 4: CQRS (Command Query Responsibility Segregation)

**When to Use**: Read and write models have different shapes or scale needs

**Example**:
```
Write Side (Commands)              Read Side (Queries)
┌──────────────┐                   ┌──────────────────┐
│   Command    │   Events          │   Query Handler  │
│   Handler    │──────────────────▶│   (Projection)   │
│              │                   │                  │
│ Domain Model │                   │ Denormalized     │
│ (normalized) │                   │ Read Model       │
└──────┬───────┘                   └────────┬─────────┘
       │                                    │
┌──────▼───────┐                   ┌────────▼─────────┐
│  Write DB    │                   │   Read DB        │
│ (PostgreSQL) │                   │ (Elasticsearch)  │
└──────────────┘                   └──────────────────┘
```

```python
# Read model projection
class OrderDashboardProjection:
    """Maintains denormalized read model for the dashboard."""

    def __init__(self, read_db):
        self.db = read_db

    def handle_order_placed(self, event: dict):
        self.db.upsert("order_dashboard", {
            "order_id": event["orderId"],
            "customer_name": event.get("customerName", ""),
            "total": event["total"],
            "item_count": len(event["items"]),
            "status": "placed",
            "placed_at": event.get("occurredAt"),
            "last_updated": datetime.utcnow(),
        })

    def handle_order_confirmed(self, event: dict):
        self.db.update("order_dashboard",
            {"order_id": event["orderId"]},
            {"status": "confirmed", "last_updated": datetime.utcnow()})

    def handle_order_shipped(self, event: dict):
        self.db.update("order_dashboard",
            {"order_id": event["orderId"]},
            {"status": "shipped",
             "shipped_at": event.get("shippedAt"),
             "tracking": event.get("trackingNumber"),
             "last_updated": datetime.utcnow()})
```

**Anti-Pattern**: Applying CQRS when read and write models are identical (unnecessary complexity).

### Pattern 5: Dead Letter Queue

**When to Use**: Handling events that repeatedly fail processing

**Example**:
```yaml
# AWS SQS dead letter queue configuration
Resources:
  OrderEventsQueue:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: order-events
      VisibilityTimeout: 60
      MessageRetentionPeriod: 1209600  # 14 days
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt OrderEventsDLQ.Arn
        maxReceiveCount: 3

  OrderEventsDLQ:
    Type: AWS::SQS::Queue
    Properties:
      QueueName: order-events-dlq
      MessageRetentionPeriod: 1209600

  DLQAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: order-events-dlq-messages
      MetricName: ApproximateNumberOfMessagesVisible
      Namespace: AWS/SQS
      Dimensions:
        - Name: QueueName
          Value: !GetAtt OrderEventsDLQ.QueueName
      Statistic: Sum
      Period: 300
      EvaluationPeriods: 1
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
      AlarmActions:
        - !Ref OncallTopic
```

**Anti-Pattern**: Silently dropping failed events without alerting or DLQ.

## Checklist

- [ ] Events are immutable facts (past tense naming)
- [ ] Event schema versioned
- [ ] Idempotent consumers (handle duplicates)
- [ ] Dead letter queue for failures
- [ ] Event ordering guaranteed where needed
- [ ] Monitoring for consumer lag
- [ ] Schema registry for event contracts
- [ ] Replay capability for rebuilding state
- [ ] Correlation IDs for tracing
- [ ] Retention policies defined

## References

- Martin Fowler, "Event Sourcing" (2005)
- [Confluent Kafka Documentation](https://docs.confluent.io/)
- Vaughn Vernon, "Implementing Domain-Driven Design" (2013)
