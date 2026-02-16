---
name: Event-Driven Architecture
description: Event-driven design patterns, event sourcing, and CQRS
category: data/message-queues
type: reference
license: Apache-2.0
---

# Event-Driven Architecture

## Core Concepts

### Event Types

| Type | Purpose | Example |
|------|---------|---------|
| Domain Event | Business fact that occurred | `OrderPlaced`, `PaymentReceived` |
| Integration Event | Cross-service communication | `UserCreated` (broadcast) |
| Command Event | Request to perform action | `ProcessPayment` |
| Change Data Capture | Database change notification | Row insert/update/delete |

### Event vs Command

```
Event (past tense, fact):       "OrderWasPlaced"
  - Cannot be rejected
  - Multiple consumers
  - Producer doesn't know consumers

Command (imperative, request):  "PlaceOrder"
  - Can be rejected
  - Single handler
  - Sender expects result
```

## Event-Driven Patterns

### Event Notification

Services publish events; consumers react independently.

```
Order Service  →  "OrderPlaced"  →  Email Service (send confirmation)
                                 →  Inventory Service (reserve stock)
                                 →  Analytics Service (record sale)
```

Pros: Loose coupling, easy to add consumers
Cons: No guarantee of processing, hard to trace flow

### Event-Carried State Transfer

Events carry enough data so consumers don't need to call back.

```json
{
  "type": "CustomerAddressChanged",
  "data": {
    "customerId": "C-123",
    "oldAddress": { "city": "Boston", "state": "MA" },
    "newAddress": { "city": "Austin", "state": "TX" }
  }
}
```

Pros: Reduces inter-service calls, consumers are self-sufficient
Cons: Larger events, potential data staleness

### Event Sourcing

Store state as a sequence of events rather than current state.

```
Account Event Store:
  1. AccountOpened     { balance: 0 }
  2. MoneyDeposited    { amount: 100 }
  3. MoneyWithdrawn    { amount: 30 }
  4. MoneyDeposited    { amount: 50 }

Current state (replay): balance = 0 + 100 - 30 + 50 = 120
```

```python
class Account:
    def __init__(self):
        self.balance = 0
        self.events = []

    def apply(self, event):
        if event["type"] == "MoneyDeposited":
            self.balance += event["amount"]
        elif event["type"] == "MoneyWithdrawn":
            self.balance -= event["amount"]
        self.events.append(event)

    def rebuild(self, events):
        for event in events:
            self.apply(event)
```

**When to use**: Audit requirements, complex business logic, temporal queries
**When to avoid**: Simple CRUD, no audit needs, high-frequency updates

### CQRS (Command Query Responsibility Segregation)

Separate read and write models:

```
Commands (writes)          Queries (reads)
    |                          |
    v                          v
Write Model               Read Model
    |                          ^
    v                          |
Event Store  → Events →  Projection
```

```python
# Write side: processes commands, emits events
class OrderCommandHandler:
    def handle_place_order(self, command):
        order = Order()
        order.place(command.items, command.customer_id)
        event_store.save(order.events)
        event_bus.publish(order.events)

# Read side: builds query-optimized projections
class OrderProjection:
    def on_order_placed(self, event):
        db.execute("""
            INSERT INTO order_summary (id, customer, total, status)
            VALUES (?, ?, ?, 'placed')
        """, [event.order_id, event.customer_id, event.total])
```

## Saga Pattern

Manage distributed transactions across services:

### Choreography (event-based)

```
Order Service → OrderCreated
  → Payment Service → PaymentProcessed
    → Inventory Service → StockReserved
      → Shipping Service → ShipmentScheduled

Compensation (on failure):
  ShipmentFailed → StockReleased → PaymentRefunded → OrderCancelled
```

### Orchestration (coordinator-based)

```python
class OrderSaga:
    def execute(self, order):
        try:
            payment = payment_service.charge(order.amount)
            inventory = inventory_service.reserve(order.items)
            shipping = shipping_service.schedule(order)
        except PaymentFailed:
            raise  # Nothing to compensate
        except InventoryFailed:
            payment_service.refund(payment.id)
            raise
        except ShippingFailed:
            inventory_service.release(inventory.id)
            payment_service.refund(payment.id)
            raise
```

| Approach | Pros | Cons |
|----------|------|------|
| Choreography | Loose coupling, simple | Hard to track, circular risk |
| Orchestration | Clear flow, easy to debug | Central point of failure |

## Outbox Pattern

Ensure atomicity between database write and event publish:

```sql
-- In a single transaction:
BEGIN;
  INSERT INTO orders (id, status) VALUES ('ORD-1', 'placed');
  INSERT INTO outbox (id, topic, payload, created_at)
    VALUES (uuid(), 'orders', '{"type":"OrderPlaced",...}', NOW());
COMMIT;
```

A separate relay process polls the outbox and publishes to the message broker, then marks entries as published.

## Idempotency

Every consumer must handle duplicate events:

```python
class IdempotentConsumer:
    def handle(self, event):
        if self.store.exists(event.id):
            return  # Already processed

        self.process(event)
        self.store.mark_processed(event.id, ttl=7*24*3600)
        self.ack(event)
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| No idempotency | Duplicate processing | Dedup by event ID |
| Missing compensation | Inconsistent state | Design sagas with rollback |
| Event ordering assumptions | Race conditions | Partition by entity ID |
| Overly large events | Performance, coupling | Use claim-check pattern |
| No schema versioning | Breaking consumers | Use schema registry |
| Sync-over-async | Defeats purpose | Embrace eventual consistency |
