---
name: nosql
description: NoSQL database patterns for MongoDB, DynamoDB, and document modeling.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: data
---

# NoSQL Databases

Document database patterns and SQL vs NoSQL decision framework.

## 80/20 Focus

Master these (covers 80% of NoSQL decisions):

| Pattern | When to Use |
|---------|-------------|
| Denormalization | Read-heavy, known access patterns |
| Embedding | Related data always accessed together |
| Referencing | Many-to-many, large subdocuments |
| Single Table | DynamoDB, known query patterns |

## SQL vs NoSQL Decision Framework

### Choose SQL When

| Criteria | Why SQL |
|----------|---------|
| Complex queries | JOINs, aggregations |
| ACID required | Financial, transactional |
| Schema stability | Well-defined, rarely changes |
| Reporting | Ad-hoc queries, BI tools |
| Relationships | Complex many-to-many |

### Choose NoSQL When

| Criteria | Why NoSQL |
|----------|-----------|
| Horizontal scale | Distributed, high volume |
| Flexible schema | Evolving, varied structure |
| Simple queries | Key-value, document lookup |
| High write volume | Event logs, time series |
| Hierarchical data | Nested documents |

### Decision Matrix

```
Need complex JOINs? → SQL
Need ACID transactions? → SQL
Need horizontal scaling? → NoSQL
Schema changes frequently? → NoSQL
Read pattern is key-based? → NoSQL
Need ad-hoc queries? → SQL
```

## MongoDB Patterns

### Document Modeling

```javascript
// Embedded (1:1, 1:few)
{
  _id: ObjectId("..."),
  name: "John",
  address: {
    street: "123 Main St",
    city: "Boston",
    zip: "02101"
  }
}

// Referenced (1:many, many:many)
// User document
{
  _id: ObjectId("user1"),
  name: "John"
}

// Orders collection
{
  _id: ObjectId("order1"),
  user_id: ObjectId("user1"),
  total: 99.99
}
```

### Embedding vs Referencing

| Factor | Embed | Reference |
|--------|-------|-----------|
| Size | <16MB doc limit | No limit |
| Access | Always together | Independent |
| Updates | Infrequent | Frequent |
| Cardinality | 1:1, 1:few | 1:many, many:many |

### Index Strategies

```javascript
// Single field
db.users.createIndex({ email: 1 });

// Compound (order matters)
db.orders.createIndex({ user_id: 1, created_at: -1 });

// Multikey (arrays)
db.products.createIndex({ tags: 1 });

// Text search
db.articles.createIndex({ title: "text", body: "text" });
```

### Aggregation Pipeline

```javascript
db.orders.aggregate([
  { $match: { status: "completed" } },
  { $group: {
      _id: "$user_id",
      totalSpent: { $sum: "$total" },
      orderCount: { $sum: 1 }
  }},
  { $sort: { totalSpent: -1 } },
  { $limit: 10 }
]);
```

## DynamoDB Patterns

### Single Table Design

```javascript
// All entities in one table
// PK and SK define access patterns

| PK          | SK              | Type    | Data        |
|-------------|-----------------|---------|-------------|
| USER#123    | PROFILE         | User    | {name, ...} |
| USER#123    | ORDER#001       | Order   | {total, ...}|
| USER#123    | ORDER#002       | Order   | {total, ...}|
| ORDER#001   | ORDER#001       | Order   | {user, ...} |
| PRODUCT#A   | PRODUCT#A       | Product | {price, ...}|
```

### Access Patterns

```javascript
// Get user profile
{ PK: "USER#123", SK: "PROFILE" }

// Get all user orders
{ PK: "USER#123", SK: { begins_with: "ORDER#" } }

// GSI: Orders by date
GSI1PK: "ORDER", GSI1SK: "2026-01-28#ORDER#001"
```

### Key Patterns

| Pattern | Use Case |
|---------|----------|
| `TYPE#ID` | Entity lookup |
| `PARENT#CHILD` | Hierarchical |
| `DATE#ID` | Time-based queries |
| `begins_with` | Range queries |

### Capacity Planning

| Mode | Use Case | Pricing |
|------|----------|---------|
| On-Demand | Variable, unpredictable | Pay per request |
| Provisioned | Steady, predictable | RCU/WCU |
| Auto-scaling | Variable but bounded | RCU/WCU + scaling |

## Data Modeling Best Practices

### Denormalization

```javascript
// Normalized (multiple queries)
User: { _id: "u1", name: "John" }
Order: { _id: "o1", user_id: "u1" }
// Requires JOIN/lookup

// Denormalized (single query)
Order: {
  _id: "o1",
  user: { _id: "u1", name: "John" }  // Embedded copy
}
```

**Trade-offs:**
- ✅ Faster reads
- ❌ Data duplication
- ❌ Update complexity

### Schema Versioning

```javascript
{
  _id: ObjectId("..."),
  schemaVersion: 2,
  name: "John",
  // v2 added 'preferences'
  preferences: { theme: "dark" }
}

// Migration on read
if (doc.schemaVersion < 2) {
  doc.preferences = defaults;
  doc.schemaVersion = 2;
  // Optionally save
}
```

## Query Optimization

### MongoDB

```javascript
// Explain query plan
db.orders.find({ user_id: "u1" }).explain("executionStats");

// Look for:
// - IXSCAN (index scan) vs COLLSCAN (collection scan)
// - nReturned vs docsExamined ratio
// - executionTimeMillis

// Covered query (all fields in index)
db.users.find(
  { email: "a@b.com" },
  { _id: 0, email: 1, name: 1 }
).hint({ email: 1, name: 1 });
```

### DynamoDB

```javascript
// Use Query over Scan
// Bad: Scan (reads entire table)
await dynamodb.scan({ TableName: "Orders" });

// Good: Query (uses keys)
await dynamodb.query({
  TableName: "Orders",
  KeyConditionExpression: "PK = :pk",
  ExpressionAttributeValues: { ":pk": "USER#123" }
});
```

## Checklist

### Design Phase
- [ ] Access patterns documented
- [ ] SQL vs NoSQL decision made
- [ ] Entity relationships mapped
- [ ] Embedding vs referencing decided
- [ ] Index strategy planned

### Implementation
- [ ] Indexes created
- [ ] Schema versioning in place
- [ ] Query patterns optimized
- [ ] Backup strategy configured
- [ ] Monitoring configured

### DynamoDB Specific
- [ ] Single table design considered
- [ ] GSI/LSI planned
- [ ] Capacity mode selected
- [ ] Hot key mitigation

## When to Load References

- **For MongoDB patterns**: See `references/mongodb-patterns.md`
- **For DynamoDB design**: See `references/dynamodb-design.md`
- **For migration patterns**: See `references/sql-to-nosql.md`
