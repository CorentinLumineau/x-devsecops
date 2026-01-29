---
name: Kafka Patterns
description: Apache Kafka production patterns, partitioning, and consumer group strategies
category: data/message-queues
type: reference
license: Apache-2.0
---

# Kafka Patterns

## Architecture Overview

```
Producers → [Topic: Partition 0] → Consumer Group A (Consumer 1)
            [Topic: Partition 1] → Consumer Group A (Consumer 2)
            [Topic: Partition 2] → Consumer Group A (Consumer 3)
                                 → Consumer Group B (all partitions)
```

Each partition is an ordered, append-only log. Consumer groups enable parallel processing while maintaining per-partition ordering.

## Topic Design

### Partitioning Strategy

| Strategy | Key | Use Case |
|----------|-----|----------|
| By entity ID | `user-id`, `order-id` | Ordering per entity |
| By region | `region-code` | Geographic locality |
| Round-robin | None (null key) | Maximum parallelism |
| Custom | Business logic | Domain-specific ordering |

```java
// Partition by order ID ensures all events for an order go to same partition
ProducerRecord<String, OrderEvent> record = new ProducerRecord<>(
    "orders",           // topic
    order.getId(),      // key (determines partition)
    orderEvent          // value
);
producer.send(record);
```

### Partition Count

```
Rule of thumb:
  partitions = max(target_throughput / producer_throughput_per_partition,
                   target_throughput / consumer_throughput_per_partition)

Example:
  Target: 100K msg/s
  Producer per partition: 50K msg/s
  Consumer per partition: 20K msg/s
  Partitions = max(100K/50K, 100K/20K) = max(2, 5) = 5
  With headroom: 6-8 partitions
```

Start with fewer partitions (6-12) and increase as needed. Reducing partitions requires topic recreation.

## Producer Patterns

### Idempotent Producer

```java
Properties props = new Properties();
props.put("enable.idempotence", "true");     // Prevents duplicates
props.put("acks", "all");                     // Wait for all replicas
props.put("retries", Integer.MAX_VALUE);      // Retry on failure
props.put("max.in.flight.requests.per.connection", 5);  // Safe with idempotence
```

### Transactional Producer

```java
producer.initTransactions();
try {
    producer.beginTransaction();
    producer.send(new ProducerRecord<>("topic-a", key, value1));
    producer.send(new ProducerRecord<>("topic-b", key, value2));
    producer.commitTransaction();
} catch (Exception e) {
    producer.abortTransaction();
}
```

## Consumer Patterns

### Consumer Group Management

```java
Properties props = new Properties();
props.put("group.id", "order-processor");
props.put("auto.offset.reset", "earliest");   // Start from beginning if no offset
props.put("enable.auto.commit", "false");      // Manual commit for reliability

KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Collections.singletonList("orders"));

while (true) {
    ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, String> record : records) {
        process(record);
    }
    consumer.commitSync();  // Commit after processing
}
```

### Handling Rebalances

```java
consumer.subscribe(topics, new ConsumerRebalanceListener() {
    @Override
    public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
        // Commit current offsets before rebalance
        consumer.commitSync();
        flushBuffers();
    }

    @Override
    public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
        // Initialize state for newly assigned partitions
        loadState(partitions);
    }
});
```

## Schema Management

Use Avro with Schema Registry for type-safe evolution:

```json
{
  "type": "record",
  "name": "OrderCreated",
  "namespace": "com.example.events",
  "fields": [
    {"name": "orderId", "type": "string"},
    {"name": "amount", "type": "double"},
    {"name": "currency", "type": "string", "default": "USD"},
    {"name": "metadata", "type": ["null", "string"], "default": null}
  ]
}
```

**Compatibility rules**:
- BACKWARD: new schema can read old data (safe default)
- FORWARD: old schema can read new data
- FULL: both directions

## Operational Patterns

### Compacted Topics

Use for maintaining latest state per key (like a changelog):

```
Key: user-123 → {name: "Alice"}     (offset 0)
Key: user-456 → {name: "Bob"}       (offset 1)
Key: user-123 → {name: "Alice S."}  (offset 2)
Key: user-123 → null                (offset 3, tombstone = delete)

After compaction:
Key: user-456 → {name: "Bob"}
```

### Consumer Lag Monitoring

```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group order-processor --describe

# Alert when lag exceeds threshold
# lag > partition_count * 10000 → warning
# lag > partition_count * 100000 → critical
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| Too many partitions | Memory overhead, slow rebalance | Start with 6-12 per topic |
| Auto-commit enabled | Data loss on crash | Use manual commit |
| No schema registry | Breaking changes | Use Avro + Schema Registry |
| Long processing in poll | Consumer timeout/rebalance | Process async, commit sync |
| No monitoring | Silent lag buildup | Monitor consumer lag |
