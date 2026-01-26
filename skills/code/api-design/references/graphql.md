---
title: GraphQL Schema Design Reference
category: code
type: reference
version: "1.0.0"
---

# GraphQL Schema Design

> Part of the code/api-design knowledge skill

## Overview

GraphQL provides a powerful query language for APIs with a strong type system. This reference covers schema design patterns, best practices for queries and mutations, and performance optimization strategies.

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| Object types | Domain entities |
| Input types | Mutation arguments |
| Interfaces | Shared fields across types |
| Unions | Polymorphic return types |
| Connections | Paginated lists |
| Subscriptions | Real-time updates |

## Patterns

### Pattern 1: Schema Structure

**When to Use**: Organizing GraphQL schema

**Example**:
```graphql
# schema.graphql - Entry point
type Query {
  # User queries
  user(id: ID!): User
  users(filter: UserFilter, pagination: PaginationInput): UserConnection!
  me: User

  # Order queries
  order(id: ID!): Order
  orders(filter: OrderFilter, pagination: PaginationInput): OrderConnection!
}

type Mutation {
  # User mutations
  createUser(input: CreateUserInput!): CreateUserPayload!
  updateUser(id: ID!, input: UpdateUserInput!): UpdateUserPayload!
  deleteUser(id: ID!): DeleteUserPayload!

  # Order mutations
  createOrder(input: CreateOrderInput!): CreateOrderPayload!
  cancelOrder(id: ID!): CancelOrderPayload!
}

type Subscription {
  # Real-time updates
  orderStatusChanged(orderId: ID!): OrderStatusEvent!
  userNotification(userId: ID!): Notification!
}

# Base types
type User {
  id: ID!
  email: String!
  name: String
  status: UserStatus!
  role: UserRole!
  orders(first: Int, after: String): OrderConnection!
  createdAt: DateTime!
  updatedAt: DateTime!
}

enum UserStatus {
  ACTIVE
  INACTIVE
  PENDING
}

enum UserRole {
  ADMIN
  USER
  VIEWER
}

# Custom scalars
scalar DateTime
scalar Email
scalar URL
```

**Anti-Pattern**: Putting all types in a single file without organization.

### Pattern 2: Input and Payload Types

**When to Use**: Mutation arguments and responses

**Example**:
```graphql
# Input types for mutations
input CreateUserInput {
  email: Email!
  password: String!
  name: String
  role: UserRole = USER
}

input UpdateUserInput {
  email: Email
  name: String
  status: UserStatus
  role: UserRole
}

input UserFilter {
  status: UserStatus
  role: UserRole
  search: String
  createdAfter: DateTime
  createdBefore: DateTime
}

# Payload types with errors
type CreateUserPayload {
  user: User
  errors: [CreateUserError!]!
}

type CreateUserError {
  code: CreateUserErrorCode!
  message: String!
  field: String
}

enum CreateUserErrorCode {
  EMAIL_TAKEN
  INVALID_EMAIL
  WEAK_PASSWORD
  VALIDATION_ERROR
}

type UpdateUserPayload {
  user: User
  errors: [UpdateUserError!]!
}

type DeleteUserPayload {
  success: Boolean!
  deletedUserId: ID
  errors: [DeleteUserError!]!
}

# Example mutation with proper error handling
type Mutation {
  createUser(input: CreateUserInput!): CreateUserPayload!
}

# Resolver implementation
const resolvers = {
  Mutation: {
    createUser: async (_, { input }, context) => {
      try {
        // Validate email
        const existingUser = await context.db.users.findByEmail(input.email);
        if (existingUser) {
          return {
            user: null,
            errors: [{
              code: 'EMAIL_TAKEN',
              message: 'A user with this email already exists',
              field: 'email'
            }]
          };
        }

        // Create user
        const user = await context.db.users.create(input);

        return {
          user,
          errors: []
        };
      } catch (error) {
        return {
          user: null,
          errors: [{
            code: 'VALIDATION_ERROR',
            message: error.message
          }]
        };
      }
    }
  }
};
```

**Anti-Pattern**: Throwing errors instead of returning structured error payloads.

### Pattern 3: Connections (Relay-style Pagination)

**When to Use**: Paginated list queries

**Example**:
```graphql
# Pagination input
input PaginationInput {
  first: Int
  after: String
  last: Int
  before: String
}

# Connection pattern
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  cursor: String!
  node: User!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

# Query with connections
type Query {
  users(
    filter: UserFilter
    first: Int
    after: String
    last: Int
    before: String
    orderBy: UserOrderBy
  ): UserConnection!
}

input UserOrderBy {
  field: UserOrderField!
  direction: OrderDirection!
}

enum UserOrderField {
  CREATED_AT
  NAME
  EMAIL
}

enum OrderDirection {
  ASC
  DESC
}
```

```typescript
// Resolver implementation
import { connectionFromArraySlice, cursorToOffset } from 'graphql-relay';

const resolvers = {
  Query: {
    users: async (_, args, context) => {
      const { filter, first = 20, after, orderBy } = args;

      // Decode cursor to offset
      const offset = after ? cursorToOffset(after) + 1 : 0;

      // Build query
      const query = context.db.users
        .where(filter)
        .orderBy(orderBy?.field || 'createdAt', orderBy?.direction || 'DESC')
        .offset(offset)
        .limit(first + 1); // Fetch one extra to check hasNextPage

      const [users, totalCount] = await Promise.all([
        query.execute(),
        context.db.users.count(filter)
      ]);

      const hasNextPage = users.length > first;
      const nodes = hasNextPage ? users.slice(0, -1) : users;

      return {
        edges: nodes.map((user, index) => ({
          cursor: Buffer.from(`cursor:${offset + index}`).toString('base64'),
          node: user
        })),
        pageInfo: {
          hasNextPage,
          hasPreviousPage: offset > 0,
          startCursor: nodes.length > 0
            ? Buffer.from(`cursor:${offset}`).toString('base64')
            : null,
          endCursor: nodes.length > 0
            ? Buffer.from(`cursor:${offset + nodes.length - 1}`).toString('base64')
            : null
        },
        totalCount
      };
    }
  }
};
```

**Anti-Pattern**: Using offset-based pagination instead of cursor-based for large datasets.

### Pattern 4: Interfaces and Unions

**When to Use**: Polymorphic types

**Example**:
```graphql
# Interface for shared fields
interface Node {
  id: ID!
}

interface Timestamped {
  createdAt: DateTime!
  updatedAt: DateTime!
}

type User implements Node & Timestamped {
  id: ID!
  email: String!
  name: String
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Order implements Node & Timestamped {
  id: ID!
  user: User!
  items: [OrderItem!]!
  total: Money!
  createdAt: DateTime!
  updatedAt: DateTime!
}

# Union for search results
union SearchResult = User | Order | Product

type Query {
  node(id: ID!): Node
  search(query: String!): [SearchResult!]!
}

# Union for activity feed
union Activity = OrderCreatedActivity | UserJoinedActivity | CommentActivity

type OrderCreatedActivity {
  id: ID!
  order: Order!
  timestamp: DateTime!
}

type UserJoinedActivity {
  id: ID!
  user: User!
  timestamp: DateTime!
}

type CommentActivity {
  id: ID!
  comment: Comment!
  author: User!
  timestamp: DateTime!
}

type Query {
  activityFeed(first: Int, after: String): ActivityConnection!
}
```

```typescript
// Resolver for union type
const resolvers = {
  SearchResult: {
    __resolveType(obj) {
      if (obj.email) return 'User';
      if (obj.items) return 'Order';
      if (obj.price) return 'Product';
      return null;
    }
  },

  Activity: {
    __resolveType(obj) {
      if (obj.order) return 'OrderCreatedActivity';
      if (obj.user && !obj.comment) return 'UserJoinedActivity';
      if (obj.comment) return 'CommentActivity';
      return null;
    }
  },

  Query: {
    node: async (_, { id }, context) => {
      // Decode global ID to get type and local ID
      const [type, localId] = fromGlobalId(id);

      switch (type) {
        case 'User':
          return context.db.users.findById(localId);
        case 'Order':
          return context.db.orders.findById(localId);
        default:
          return null;
      }
    }
  }
};
```

**Anti-Pattern**: Using a generic "type" field instead of proper unions.

### Pattern 5: DataLoader Pattern (N+1 Prevention)

**When to Use**: Resolving related entities efficiently

**Example**:
```typescript
import DataLoader from 'dataloader';

// Create loaders per request
function createLoaders(db) {
  return {
    userLoader: new DataLoader<string, User>(async (ids) => {
      const users = await db.users.findByIds(ids);
      const userMap = new Map(users.map(u => [u.id, u]));
      return ids.map(id => userMap.get(id) || null);
    }),

    ordersByUserLoader: new DataLoader<string, Order[]>(async (userIds) => {
      const orders = await db.orders.findByUserIds(userIds);
      const orderMap = new Map<string, Order[]>();

      for (const order of orders) {
        const existing = orderMap.get(order.userId) || [];
        existing.push(order);
        orderMap.set(order.userId, existing);
      }

      return userIds.map(id => orderMap.get(id) || []);
    }),

    // Batched loader with caching
    productLoader: new DataLoader<string, Product>(
      async (ids) => {
        const products = await db.products.findByIds(ids);
        const productMap = new Map(products.map(p => [p.id, p]));
        return ids.map(id => productMap.get(id) || null);
      },
      {
        cache: true,
        maxBatchSize: 100
      }
    )
  };
}

// Context factory
function createContext({ req }) {
  const db = getDatabase();
  return {
    db,
    loaders: createLoaders(db),
    user: authenticateRequest(req)
  };
}

// Resolvers using loaders
const resolvers = {
  Order: {
    user: (order, _, context) => {
      return context.loaders.userLoader.load(order.userId);
    },

    items: async (order, _, context) => {
      const items = await context.db.orderItems.findByOrderId(order.id);
      // Prefetch products for all items
      await Promise.all(
        items.map(item => context.loaders.productLoader.load(item.productId))
      );
      return items;
    }
  },

  OrderItem: {
    product: (item, _, context) => {
      return context.loaders.productLoader.load(item.productId);
    }
  },

  User: {
    orders: (user, args, context) => {
      // For connections, load through DataLoader
      return context.loaders.ordersByUserLoader.load(user.id);
    }
  }
};
```

**Anti-Pattern**: Fetching related data in each resolver without batching.

### Pattern 6: Subscriptions

**When to Use**: Real-time updates

**Example**:
```graphql
type Subscription {
  # Subscribe to order status changes
  orderStatusChanged(orderId: ID!): OrderStatusEvent!

  # Subscribe to all user notifications
  userNotification: Notification!

  # Subscribe with filter
  orderCreated(filter: OrderCreatedFilter): Order!
}

type OrderStatusEvent {
  order: Order!
  previousStatus: OrderStatus!
  newStatus: OrderStatus!
  timestamp: DateTime!
}

input OrderCreatedFilter {
  minTotal: Money
  category: ProductCategory
}
```

```typescript
import { PubSub, withFilter } from 'graphql-subscriptions';

const pubsub = new PubSub();

// Event constants
const EVENTS = {
  ORDER_STATUS_CHANGED: 'ORDER_STATUS_CHANGED',
  USER_NOTIFICATION: 'USER_NOTIFICATION',
  ORDER_CREATED: 'ORDER_CREATED'
};

const resolvers = {
  Subscription: {
    orderStatusChanged: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([EVENTS.ORDER_STATUS_CHANGED]),
        (payload, variables, context) => {
          // Only send to subscribers watching this specific order
          return payload.orderStatusChanged.order.id === variables.orderId;
        }
      )
    },

    userNotification: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([EVENTS.USER_NOTIFICATION]),
        (payload, variables, context) => {
          // Only send to the authenticated user
          return payload.userNotification.userId === context.user.id;
        }
      )
    },

    orderCreated: {
      subscribe: withFilter(
        () => pubsub.asyncIterator([EVENTS.ORDER_CREATED]),
        (payload, variables) => {
          const { filter } = variables;
          if (!filter) return true;

          const order = payload.orderCreated;
          if (filter.minTotal && order.total < filter.minTotal) return false;
          if (filter.category && !order.items.some(i => i.category === filter.category)) return false;

          return true;
        }
      )
    }
  },

  Mutation: {
    updateOrderStatus: async (_, { id, status }, context) => {
      const order = await context.db.orders.findById(id);
      const previousStatus = order.status;

      const updatedOrder = await context.db.orders.update(id, { status });

      // Publish event
      pubsub.publish(EVENTS.ORDER_STATUS_CHANGED, {
        orderStatusChanged: {
          order: updatedOrder,
          previousStatus,
          newStatus: status,
          timestamp: new Date()
        }
      });

      return { order: updatedOrder, errors: [] };
    }
  }
};
```

**Anti-Pattern**: Not filtering subscriptions, sending all events to all subscribers.

## Checklist

- [ ] Schema uses descriptive type names
- [ ] Input types defined for all mutations
- [ ] Payload types include error handling
- [ ] Connections used for paginated lists
- [ ] DataLoader used for N+1 prevention
- [ ] Interfaces for shared fields
- [ ] Unions for polymorphic returns
- [ ] Custom scalars for special types
- [ ] Subscriptions properly filtered
- [ ] Schema documented with descriptions

## References

- [GraphQL Specification](https://spec.graphql.org/)
- [Relay Connection Specification](https://relay.dev/graphql/connections.htm)
- [Apollo Server Documentation](https://www.apollographql.com/docs/apollo-server/)
- [GraphQL Best Practices](https://graphql.org/learn/best-practices/)
