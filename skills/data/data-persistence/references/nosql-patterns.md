# NoSQL Database Patterns

Detailed modeling patterns for MongoDB and DynamoDB.

## MongoDB Document Modeling

| Factor | Embed | Reference |
|--------|-------|-----------|
| Size | <16MB doc limit | No limit |
| Access | Always together | Independent access |
| Updates | Infrequent | Frequent updates |
| Cardinality | 1:1, 1:few | 1:many, many:many |

```javascript
// Embedded (1:1, 1:few)
{
  _id: ObjectId("..."),
  name: "John",
  address: { street: "123 Main St", city: "Boston" }
}

// Referenced (1:many, many:many)
{ _id: ObjectId("user1"), name: "John" }
{ _id: ObjectId("order1"), user_id: ObjectId("user1"), total: 99.99 }
```

## DynamoDB Single Table Design

| Pattern | Use Case |
|---------|----------|
| `TYPE#ID` | Entity lookup |
| `PARENT#CHILD` | Hierarchical data |
| `DATE#ID` | Time-based queries |
| `begins_with` | Range queries on sort key |

```javascript
// Access patterns drive table design
// Get user: PK="USER#123", SK="PROFILE"
// Get user orders: PK="USER#123", SK begins_with "ORDER#"
```

## Schema Versioning

```javascript
{
  _id: ObjectId("..."),
  schemaVersion: 2,
  name: "John",
  preferences: { theme: "dark" }  // Added in v2
}

// Migrate on read
if (doc.schemaVersion < 2) {
  doc.preferences = defaults;
  doc.schemaVersion = 2;
}
```
