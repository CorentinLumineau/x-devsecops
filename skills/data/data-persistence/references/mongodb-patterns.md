# MongoDB Patterns Reference

Advanced MongoDB patterns and best practices.

## Schema Design Patterns

### Attribute Pattern
For documents with many similar but not identical attributes.

```javascript
// Instead of:
{
  product_id: "123",
  color: "red",
  size: "XL",
  material: "cotton",
  brand: "Nike",
  // ... 50 more attributes
}

// Use:
{
  product_id: "123",
  attributes: [
    { k: "color", v: "red" },
    { k: "size", v: "XL" },
    { k: "material", v: "cotton" },
    { k: "brand", v: "Nike" }
  ]
}

// Index for attribute queries
db.products.createIndex({ "attributes.k": 1, "attributes.v": 1 });
```

### Bucket Pattern
For time-series or event data.

```javascript
// Instead of one doc per event:
{
  sensor_id: "s1",
  timestamp: ISODate("2026-01-28T10:00:00Z"),
  value: 42
}

// Bucket by hour:
{
  sensor_id: "s1",
  bucket: "2026-01-28T10",
  count: 60,
  sum: 2520,
  measurements: [
    { t: ISODate("2026-01-28T10:00:00Z"), v: 42 },
    { t: ISODate("2026-01-28T10:01:00Z"), v: 43 },
    // ...
  ]
}
```

### Outlier Pattern
Handle documents that break the pattern.

```javascript
// Main collection: embedded comments (most books have < 50)
{
  _id: "book1",
  title: "Normal Book",
  comments: [
    { user: "u1", text: "Great!" },
    // ... up to ~50 comments
  ]
}

// For popular books, use overflow collection
{
  _id: "book2",
  title: "Viral Book",
  has_extras: true,
  comments: [/* first 50 */]
}

// Overflow collection
{
  book_id: "book2",
  comments: [/* comments 51-100 */]
}
```

### Subset Pattern
Store frequently accessed subset in main doc.

```javascript
// Product with full reviews elsewhere
{
  _id: "prod1",
  name: "Widget",
  price: 29.99,
  review_summary: {
    average: 4.5,
    count: 1234,
    recent: [
      { user: "alice", rating: 5, excerpt: "Amazing..." },
      { user: "bob", rating: 4, excerpt: "Good but..." }
    ]
  }
}

// Full reviews in separate collection
{
  product_id: "prod1",
  user: "alice",
  rating: 5,
  text: "Amazing product! I've been using it for..."
}
```

## Aggregation Patterns

### Lookup with Unwind

```javascript
db.orders.aggregate([
  {
    $lookup: {
      from: "products",
      localField: "product_ids",
      foreignField: "_id",
      as: "products"
    }
  },
  { $unwind: "$products" },
  {
    $group: {
      _id: "$_id",
      total: { $sum: "$products.price" },
      products: { $push: "$products.name" }
    }
  }
]);
```

### Faceted Search

```javascript
db.products.aggregate([
  { $match: { category: "electronics" } },
  {
    $facet: {
      "byBrand": [
        { $group: { _id: "$brand", count: { $sum: 1 } } },
        { $sort: { count: -1 } }
      ],
      "byPriceRange": [
        {
          $bucket: {
            groupBy: "$price",
            boundaries: [0, 50, 100, 500, 1000],
            default: "1000+",
            output: { count: { $sum: 1 } }
          }
        }
      ],
      "results": [
        { $skip: 0 },
        { $limit: 20 }
      ]
    }
  }
]);
```

### Graph Lookup

```javascript
// Find all reports up to 3 levels deep
db.employees.aggregate([
  { $match: { name: "CEO" } },
  {
    $graphLookup: {
      from: "employees",
      startWith: "$_id",
      connectFromField: "_id",
      connectToField: "manager_id",
      as: "reports",
      maxDepth: 3,
      depthField: "level"
    }
  }
]);
```

## Index Strategies

### Compound Index Order
```javascript
// Query pattern: { status: "active", created_at: { $gte: date } }
// Index order: equality before range
db.orders.createIndex({ status: 1, created_at: -1 });

// Covered query
db.orders.find(
  { status: "active", created_at: { $gte: date } },
  { _id: 0, status: 1, created_at: 1, total: 1 }
).hint({ status: 1, created_at: -1, total: 1 });
```

### Partial Index
```javascript
// Only index active documents
db.users.createIndex(
  { email: 1 },
  { partialFilterExpression: { status: "active" } }
);
```

### TTL Index
```javascript
// Auto-delete after 30 days
db.sessions.createIndex(
  { createdAt: 1 },
  { expireAfterSeconds: 2592000 }
);
```

## Transactions

```javascript
const session = client.startSession();

try {
  session.startTransaction();

  await db.accounts.updateOne(
    { _id: "from" },
    { $inc: { balance: -100 } },
    { session }
  );

  await db.accounts.updateOne(
    { _id: "to" },
    { $inc: { balance: 100 } },
    { session }
  );

  await session.commitTransaction();
} catch (error) {
  await session.abortTransaction();
  throw error;
} finally {
  session.endSession();
}
```

## Change Streams

```javascript
const pipeline = [
  { $match: { 'fullDocument.status': 'completed' } }
];

const changeStream = db.orders.watch(pipeline, {
  fullDocument: 'updateLookup'
});

changeStream.on('change', (change) => {
  console.log('Order completed:', change.fullDocument);
});
```
