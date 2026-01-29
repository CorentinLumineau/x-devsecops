---
name: RabbitMQ Patterns
description: RabbitMQ exchange types, routing patterns, and reliability configurations
category: data/message-queues
type: reference
license: Apache-2.0
---

# RabbitMQ Patterns

## Architecture Overview

```
Producer → [Exchange] → Binding → [Queue] → Consumer
```

Unlike Kafka's log-based model, RabbitMQ is a traditional message broker: messages are delivered to consumers and removed from the queue upon acknowledgment.

## Exchange Types

| Exchange | Routing | Use Case |
|----------|---------|----------|
| Direct | Exact key match | Task routing by type |
| Fanout | All bound queues | Broadcast events |
| Topic | Pattern match (`*.log.#`) | Flexible routing |
| Headers | Header attributes | Complex routing rules |

### Direct Exchange

```python
# Producer: route to specific queue by key
channel.basic_publish(
    exchange='tasks',
    routing_key='email',
    body=json.dumps({"to": "user@example.com", "subject": "Hello"})
)

# Consumer: bind to specific routing key
channel.queue_bind(exchange='tasks', queue='email-queue', routing_key='email')
```

### Topic Exchange

```python
# Routing key pattern: <facility>.<severity>
# * matches one word, # matches zero or more words

# Bind to all errors
channel.queue_bind(exchange='logs', queue='error-queue', routing_key='*.error')

# Bind to all auth events
channel.queue_bind(exchange='logs', queue='auth-queue', routing_key='auth.#')

# Publish
channel.basic_publish(
    exchange='logs',
    routing_key='auth.error',  # Matches both bindings above
    body=json.dumps({"message": "Login failed"})
)
```

### Fanout Exchange

```python
# All bound queues receive every message (routing key ignored)
channel.exchange_declare(exchange='events', exchange_type='fanout')

# Each service binds its own queue
channel.queue_bind(exchange='events', queue='notification-queue')
channel.queue_bind(exchange='events', queue='analytics-queue')
channel.queue_bind(exchange='events', queue='audit-queue')
```

## Reliability Patterns

### Publisher Confirms

```python
channel.confirm_delivery()

try:
    channel.basic_publish(
        exchange='orders',
        routing_key='new',
        body=message,
        properties=pika.BasicProperties(
            delivery_mode=2,  # Persistent message
            content_type='application/json'
        )
    )
except pika.exceptions.UnroutableError:
    handle_unroutable(message)
```

### Consumer Acknowledgments

```python
def callback(ch, method, properties, body):
    try:
        process_message(body)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        # Requeue on transient failure
        ch.basic_nack(
            delivery_tag=method.delivery_tag,
            requeue=is_transient(e)
        )

channel.basic_consume(
    queue='orders',
    on_message_callback=callback,
    auto_ack=False  # Manual acknowledgment
)
```

### Durable Queues and Messages

```python
# Durable queue survives broker restart
channel.queue_declare(queue='orders', durable=True)

# Persistent message survives broker restart
channel.basic_publish(
    exchange='',
    routing_key='orders',
    body=message,
    properties=pika.BasicProperties(delivery_mode=2)
)
```

## Dead Letter Exchange (DLX)

```python
# Declare DLQ
channel.queue_declare(queue='orders-dlq', durable=True)
channel.queue_bind(exchange='dlx', queue='orders-dlq', routing_key='orders')

# Main queue with DLX configuration
channel.queue_declare(
    queue='orders',
    durable=True,
    arguments={
        'x-dead-letter-exchange': 'dlx',
        'x-dead-letter-routing-key': 'orders',
        'x-message-ttl': 30000,      # 30s TTL
        'x-max-length': 100000        # Max queue size
    }
)
```

Messages go to DLX when:
- Consumer rejects with `requeue=False`
- Message TTL expires
- Queue max length exceeded

## Work Queue Pattern

Distribute tasks among multiple workers with fair dispatch:

```python
# Fair dispatch: don't give a worker more than 1 unacked message
channel.basic_qos(prefetch_count=1)

# Multiple workers consume from same queue
channel.basic_consume(queue='tasks', on_message_callback=process_task)
```

## Priority Queues

```python
channel.queue_declare(
    queue='tasks',
    arguments={'x-max-priority': 10}
)

# High priority message
channel.basic_publish(
    exchange='',
    routing_key='tasks',
    body=urgent_task,
    properties=pika.BasicProperties(priority=9)
)

# Normal priority message
channel.basic_publish(
    exchange='',
    routing_key='tasks',
    body=normal_task,
    properties=pika.BasicProperties(priority=1)
)
```

## Retry with Exponential Backoff

```python
# Use per-message TTL with multiple retry queues
retry_queues = {
    'retry-1s':  {'x-message-ttl': 1000,  'x-dead-letter-exchange': '', 'x-dead-letter-routing-key': 'main-queue'},
    'retry-5s':  {'x-message-ttl': 5000,  'x-dead-letter-exchange': '', 'x-dead-letter-routing-key': 'main-queue'},
    'retry-30s': {'x-message-ttl': 30000, 'x-dead-letter-exchange': '', 'x-dead-letter-routing-key': 'main-queue'},
}

def on_failure(channel, method, properties, retry_count):
    if retry_count >= 3:
        channel.basic_publish(exchange='', routing_key='dlq', body=properties.body)
    else:
        queue = list(retry_queues.keys())[retry_count]
        headers = {'x-retry-count': retry_count + 1}
        channel.basic_publish(
            exchange='', routing_key=queue, body=properties.body,
            properties=pika.BasicProperties(headers=headers)
        )
    channel.basic_ack(delivery_tag=method.delivery_tag)
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| auto_ack=True | Message loss on crash | Use manual ack |
| No prefetch limit | One slow consumer starved | Set prefetch_count=1 |
| Non-durable queue | Data loss on restart | Set durable=True |
| No DLX | Poison messages block queue | Configure dead letter exchange |
| Unbounded queues | Memory exhaustion | Set x-max-length |
