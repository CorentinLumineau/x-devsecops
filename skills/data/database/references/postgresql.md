---
title: PostgreSQL
category: data
type: reference
version: 1.0.0
---

# PostgreSQL

## Overview

PostgreSQL configuration, query optimization, and operational patterns for production workloads. Covers connection management, indexing strategies, JSON operations, and high availability setup.

## 80/20 Quick Reference

| Aspect | Key Practice | Impact |
|--------|--------------|--------|
| Connections | Use pgBouncer pooling | 10x connection efficiency |
| Indexing | Composite indexes, INCLUDE columns | 100x query speedup |
| JSON | JSONB with GIN indexes | Flexible schema + performance |
| Partitioning | Range partition large tables | Manageable table sizes |
| Replication | Streaming + logical for read replicas | High availability |

## Connection Pooling

### When to Use
Implement connection pooling for any application with more than 10 concurrent database connections or serverless/container workloads.

### Example

```yaml
# pgbouncer.ini
[databases]
myapp = host=postgres.internal port=5432 dbname=production

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Pool settings
pool_mode = transaction  # Best for web apps
default_pool_size = 20
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3

# Connection limits
max_client_conn = 1000
max_db_connections = 100

# Timeouts
server_idle_timeout = 60
client_idle_timeout = 0
query_timeout = 30

# Logging
log_connections = 1
log_disconnections = 1
log_pooler_errors = 1
stats_period = 60
```

```typescript
// Application connection configuration
import { Pool } from 'pg';

const pool = new Pool({
  host: process.env.PGBOUNCER_HOST,
  port: 6432,
  database: 'myapp',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,

  // Pool settings (per-process)
  max: 10,  // pgBouncer handles actual pooling
  min: 2,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,

  // Statement timeout
  statement_timeout: 30000,

  // Application name for debugging
  application_name: 'myapp-api',
});

// Health check
export async function checkDatabaseHealth(): Promise<boolean> {
  const client = await pool.connect();
  try {
    await client.query('SELECT 1');
    return true;
  } finally {
    client.release();
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  await pool.end();
  process.exit(0);
});
```

### Anti-Patterns
- Opening new connection per request
- Session pool mode with prepared statements
- Not setting statement timeouts

---

## Indexing Strategies

### When to Use
Design indexes based on query patterns, considering write overhead and storage costs.

### Example

```sql
-- Composite index for common query pattern
-- Query: SELECT * FROM orders WHERE user_id = ? AND status = ? ORDER BY created_at DESC
CREATE INDEX CONCURRENTLY idx_orders_user_status_created
ON orders (user_id, status, created_at DESC);

-- Covering index (INCLUDE) to avoid table lookup
-- Query: SELECT id, total, created_at FROM orders WHERE user_id = ? AND status = 'completed'
CREATE INDEX CONCURRENTLY idx_orders_user_completed_covering
ON orders (user_id)
INCLUDE (id, total, created_at)
WHERE status = 'completed';

-- Partial index for common filter
-- Query: SELECT * FROM orders WHERE status = 'pending' AND created_at > NOW() - INTERVAL '24 hours'
CREATE INDEX CONCURRENTLY idx_orders_pending_recent
ON orders (created_at DESC)
WHERE status = 'pending';

-- GIN index for array contains
-- Query: SELECT * FROM products WHERE tags @> ARRAY['electronics', 'sale']
CREATE INDEX CONCURRENTLY idx_products_tags
ON products USING GIN (tags);

-- GIN index for JSONB containment
-- Query: SELECT * FROM events WHERE metadata @> '{"type": "click"}'
CREATE INDEX CONCURRENTLY idx_events_metadata
ON events USING GIN (metadata jsonb_path_ops);

-- Expression index for case-insensitive search
-- Query: SELECT * FROM users WHERE LOWER(email) = 'user@example.com'
CREATE INDEX CONCURRENTLY idx_users_email_lower
ON users (LOWER(email));

-- BRIN index for time-series data (much smaller than B-tree)
-- Query: SELECT * FROM logs WHERE created_at BETWEEN ? AND ?
CREATE INDEX CONCURRENTLY idx_logs_created_brin
ON logs USING BRIN (created_at);
```

```sql
-- Index analysis queries

-- Unused indexes (potential removal candidates)
SELECT
    schemaname || '.' || relname AS table,
    indexrelname AS index,
    pg_size_pretty(pg_relation_size(i.indexrelid)) AS size,
    idx_scan AS scans
FROM pg_stat_user_indexes ui
JOIN pg_index i ON ui.indexrelid = i.indexrelid
WHERE idx_scan < 50
  AND NOT indisunique
  AND NOT indisprimary
ORDER BY pg_relation_size(i.indexrelid) DESC;

-- Missing indexes (high sequential scans)
SELECT
    schemaname || '.' || relname AS table,
    seq_scan,
    seq_tup_read,
    idx_scan,
    CASE WHEN seq_scan > 0
         THEN seq_tup_read / seq_scan
         ELSE 0
    END AS avg_rows_per_seq_scan
FROM pg_stat_user_tables
WHERE seq_scan > 100
  AND seq_tup_read / GREATEST(seq_scan, 1) > 1000
ORDER BY seq_tup_read DESC;

-- Index bloat estimation
SELECT
    schemaname || '.' || relname AS table,
    indexrelname AS index,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size,
    ROUND(100 * pg_relation_size(indexrelid) /
          NULLIF(pg_relation_size(relid), 0), 2) AS index_table_ratio
FROM pg_stat_user_indexes
WHERE pg_relation_size(indexrelid) > 10 * 1024 * 1024
ORDER BY pg_relation_size(indexrelid) DESC;
```

### Anti-Patterns
- Index on every column
- Missing composite indexes for multi-column WHERE
- Not using CONCURRENTLY for production indexes

---

## JSONB Operations

### When to Use
Use JSONB for semi-structured data, flexible schemas, and document-like storage while maintaining query performance.

### Example

```sql
-- Table with JSONB column
CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}',
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- GIN index for containment queries
CREATE INDEX idx_events_payload ON events USING GIN (payload);
CREATE INDEX idx_events_metadata ON events USING GIN (metadata jsonb_path_ops);

-- Expression index for specific JSON path
CREATE INDEX idx_events_user_id ON events ((payload->>'user_id'));

-- Containment query (uses GIN index)
SELECT * FROM events
WHERE payload @> '{"action": "purchase", "category": "electronics"}';

-- JSON path query (PostgreSQL 12+)
SELECT * FROM events
WHERE payload @? '$.items[*] ? (@.price > 100)';

-- Extract and filter
SELECT
    id,
    payload->>'user_id' AS user_id,
    payload->'items' AS items,
    (payload->>'total')::numeric AS total
FROM events
WHERE event_type = 'order'
  AND (payload->>'total')::numeric > 100;

-- Aggregate JSON data
SELECT
    payload->>'category' AS category,
    COUNT(*) AS event_count,
    SUM((payload->>'amount')::numeric) AS total_amount
FROM events
WHERE event_type = 'purchase'
  AND created_at > NOW() - INTERVAL '7 days'
GROUP BY payload->>'category';

-- Update nested JSON
UPDATE events
SET payload = jsonb_set(
    payload,
    '{processed}',
    'true'::jsonb
)
WHERE id = 123;

-- Append to JSON array
UPDATE events
SET payload = jsonb_set(
    payload,
    '{tags}',
    COALESCE(payload->'tags', '[]'::jsonb) || '["new-tag"]'::jsonb
)
WHERE id = 123;

-- Remove key from JSON
UPDATE events
SET payload = payload - 'temp_data'
WHERE event_type = 'processed';
```

```typescript
// TypeScript JSONB patterns
import { Pool } from 'pg';

interface EventPayload {
  userId: string;
  action: string;
  items?: Array<{ id: string; price: number }>;
  metadata?: Record<string, unknown>;
}

class EventRepository {
  constructor(private pool: Pool) {}

  async create(
    eventType: string,
    payload: EventPayload
  ): Promise<number> {
    const result = await this.pool.query(
      `INSERT INTO events (event_type, payload)
       VALUES ($1, $2)
       RETURNING id`,
      [eventType, JSON.stringify(payload)]
    );
    return result.rows[0].id;
  }

  async findByPayloadMatch(
    match: Partial<EventPayload>
  ): Promise<Event[]> {
    // Uses GIN index with @> operator
    const result = await this.pool.query(
      `SELECT * FROM events WHERE payload @> $1`,
      [JSON.stringify(match)]
    );
    return result.rows;
  }

  async updatePayloadField(
    id: number,
    path: string[],
    value: unknown
  ): Promise<void> {
    await this.pool.query(
      `UPDATE events
       SET payload = jsonb_set(payload, $2, $3::jsonb)
       WHERE id = $1`,
      [id, `{${path.join(',')}}`, JSON.stringify(value)]
    );
  }

  async aggregateByField(
    field: string,
    since: Date
  ): Promise<{ [key: string]: number }> {
    const result = await this.pool.query(
      `SELECT payload->>$1 AS field_value, COUNT(*) AS count
       FROM events
       WHERE created_at > $2
       GROUP BY payload->>$1`,
      [field, since]
    );
    return Object.fromEntries(
      result.rows.map(r => [r.field_value, parseInt(r.count)])
    );
  }
}
```

### Anti-Patterns
- Using JSON instead of JSONB (no binary optimization)
- Not indexing frequently queried JSON paths
- Storing relational data as JSON

---

## Table Partitioning

### When to Use
Partition tables exceeding 10GB or with time-series data requiring efficient archival and purging.

### Example

```sql
-- Range partitioning for time-series data
CREATE TABLE events (
    id BIGSERIAL,
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create partitions for each month
CREATE TABLE events_2024_01 PARTITION OF events
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE events_2024_02 PARTITION OF events
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Default partition for unexpected data
CREATE TABLE events_default PARTITION OF events DEFAULT;

-- Automatic partition management
CREATE OR REPLACE FUNCTION create_monthly_partition()
RETURNS void AS $$
DECLARE
    start_date DATE;
    end_date DATE;
    partition_name TEXT;
BEGIN
    -- Create partition for next month
    start_date := DATE_TRUNC('month', NOW() + INTERVAL '1 month');
    end_date := start_date + INTERVAL '1 month';
    partition_name := 'events_' || TO_CHAR(start_date, 'YYYY_MM');

    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS %I PARTITION OF events
         FOR VALUES FROM (%L) TO (%L)',
        partition_name, start_date, end_date
    );

    -- Create indexes on new partition
    EXECUTE format(
        'CREATE INDEX IF NOT EXISTS %I ON %I (event_type, created_at DESC)',
        partition_name || '_event_type_idx', partition_name
    );

    RAISE NOTICE 'Created partition: %', partition_name;
END;
$$ LANGUAGE plpgsql;

-- Schedule with pg_cron
SELECT cron.schedule('create_partition', '0 0 25 * *', 'SELECT create_monthly_partition()');

-- Drop old partitions (data retention)
CREATE OR REPLACE FUNCTION drop_old_partitions(retention_months INTEGER)
RETURNS void AS $$
DECLARE
    partition_record RECORD;
    cutoff_date DATE;
BEGIN
    cutoff_date := DATE_TRUNC('month', NOW() - (retention_months || ' months')::INTERVAL);

    FOR partition_record IN
        SELECT inhrelid::regclass::text AS partition_name
        FROM pg_inherits
        WHERE inhparent = 'events'::regclass
    LOOP
        -- Extract date from partition name and compare
        IF partition_record.partition_name ~ 'events_\d{4}_\d{2}' THEN
            IF TO_DATE(
                SUBSTRING(partition_record.partition_name FROM 'events_(\d{4}_\d{2})'),
                'YYYY_MM'
            ) < cutoff_date THEN
                EXECUTE format('DROP TABLE %I', partition_record.partition_name);
                RAISE NOTICE 'Dropped partition: %', partition_record.partition_name;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Schedule monthly cleanup (keep 12 months)
SELECT cron.schedule('cleanup_partitions', '0 2 1 * *', 'SELECT drop_old_partitions(12)');
```

```sql
-- List partitioning for categorical data
CREATE TABLE orders (
    id BIGSERIAL,
    user_id BIGINT NOT NULL,
    status VARCHAR(20) NOT NULL,
    total NUMERIC(10, 2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (id, status)
) PARTITION BY LIST (status);

CREATE TABLE orders_pending PARTITION OF orders
    FOR VALUES IN ('pending', 'processing');

CREATE TABLE orders_completed PARTITION OF orders
    FOR VALUES IN ('completed', 'shipped', 'delivered');

CREATE TABLE orders_cancelled PARTITION OF orders
    FOR VALUES IN ('cancelled', 'refunded');
```

### Anti-Patterns
- Partitioning small tables (<1GB)
- Too many partitions (>1000)
- Not including partition key in queries

---

## High Availability Setup

### When to Use
Configure streaming replication and automatic failover for production databases requiring high availability.

### Example

```yaml
# Primary server (postgresql.conf)
listen_addresses = '*'
port = 5432

# WAL settings for replication
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 1GB
hot_standby = on

# Synchronous replication (strong consistency)
synchronous_commit = on
synchronous_standby_names = 'FIRST 1 (replica1, replica2)'

# Archive for PITR
archive_mode = on
archive_command = 'aws s3 cp %p s3://postgres-wal-archive/%f'

# Performance
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 256MB
maintenance_work_mem = 1GB
```

```yaml
# Replica server (postgresql.conf)
hot_standby = on
max_standby_streaming_delay = 30s
hot_standby_feedback = on

# Recovery settings (standby.signal file present)
primary_conninfo = 'host=primary.internal port=5432 user=replicator password=secret application_name=replica1'
primary_slot_name = 'replica1_slot'
restore_command = 'aws s3 cp s3://postgres-wal-archive/%f %p'
recovery_target_timeline = 'latest'
```

```yaml
# Patroni for automatic failover
scope: postgres-cluster
namespace: /db/
name: postgres-node1

restapi:
  listen: 0.0.0.0:8008
  connect_address: postgres-node1:8008

etcd3:
  hosts:
    - etcd1:2379
    - etcd2:2379
    - etcd3:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: on
        max_wal_senders: 10
        max_replication_slots: 10

  initdb:
    - encoding: UTF8
    - data-checksums

postgresql:
  listen: 0.0.0.0:5432
  connect_address: postgres-node1:5432
  data_dir: /var/lib/postgresql/data
  authentication:
    replication:
      username: replicator
      password: secret
    superuser:
      username: postgres
      password: secret

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
```

```typescript
// Application connection with failover awareness
import { Pool } from 'pg';

class PostgresClient {
  private pool: Pool;

  constructor() {
    this.pool = new Pool({
      // Multiple hosts for failover
      host: process.env.PGHOST, // HAProxy or Patroni endpoint
      port: parseInt(process.env.PGPORT || '5432'),
      database: process.env.PGDATABASE,
      user: process.env.PGUSER,
      password: process.env.PGPASSWORD,

      // Connection settings
      max: 20,
      connectionTimeoutMillis: 5000,
      idleTimeoutMillis: 30000,

      // Retry on connection failure
      keepAlive: true,
      keepAliveInitialDelayMillis: 10000,
    });

    // Handle connection errors
    this.pool.on('error', (err) => {
      console.error('Unexpected pool error:', err);
      // Connection will be re-established on next query
    });
  }

  async query<T>(
    sql: string,
    params?: unknown[],
    options?: { readOnly?: boolean }
  ): Promise<T[]> {
    const client = await this.pool.connect();
    try {
      // Set read-only for replica routing (via HAProxy)
      if (options?.readOnly) {
        await client.query('SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY');
      }
      const result = await client.query(sql, params);
      return result.rows;
    } finally {
      client.release();
    }
  }

  async healthCheck(): Promise<{
    primary: boolean;
    replicationLag: number;
  }> {
    const [pgState] = await this.query<{
      is_primary: boolean;
      lag_bytes: number;
    }>(`
      SELECT
        NOT pg_is_in_recovery() AS is_primary,
        COALESCE(
          pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()),
          0
        ) AS lag_bytes
    `);

    return {
      primary: pgState.is_primary,
      replicationLag: pgState.lag_bytes,
    };
  }
}
```

### Anti-Patterns
- Synchronous replication without considering latency
- No monitoring of replication lag
- Single point of failure in failover coordination

---

## Query Optimization

### When to Use
Analyze and optimize slow queries using EXPLAIN ANALYZE and systematic tuning.

### Example

```sql
-- Enable query statistics
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Find slowest queries
SELECT
    substring(query, 1, 100) AS query_preview,
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_ms,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND((100 * total_exec_time / SUM(total_exec_time) OVER ())::numeric, 2) AS percent_total
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- Analyze query plan
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.*, u.email
FROM orders o
JOIN users u ON u.id = o.user_id
WHERE o.status = 'pending'
  AND o.created_at > NOW() - INTERVAL '24 hours'
ORDER BY o.created_at DESC
LIMIT 100;

-- Optimized query with index hints
/*
  Original: Seq Scan on orders, 500ms
  Optimized: Index Scan using idx_orders_status_created, 5ms

  Added index:
  CREATE INDEX idx_orders_status_created ON orders (status, created_at DESC)
  WHERE status = 'pending';
*/

-- CTE optimization (materialized vs non-materialized)
WITH recent_orders AS MATERIALIZED (
    -- Force materialization to prevent repeated computation
    SELECT * FROM orders
    WHERE created_at > NOW() - INTERVAL '7 days'
)
SELECT u.id, u.email, COUNT(*) AS order_count
FROM users u
JOIN recent_orders ro ON ro.user_id = u.id
GROUP BY u.id, u.email
HAVING COUNT(*) > 5;

-- Batch operations for better performance
WITH batch_ids AS (
    SELECT unnest($1::bigint[]) AS id
)
UPDATE orders o
SET status = 'processing',
    updated_at = NOW()
FROM batch_ids b
WHERE o.id = b.id
  AND o.status = 'pending';
```

```typescript
// Query builder with optimization hints
class QueryBuilder {
  async findOrdersOptimized(
    filters: OrderFilters,
    pagination: Pagination
  ): Promise<Order[]> {
    // Build query with proper index usage
    const conditions: string[] = [];
    const params: unknown[] = [];
    let paramIndex = 1;

    // Status filter (use partial index)
    if (filters.status) {
      conditions.push(`status = $${paramIndex++}`);
      params.push(filters.status);
    }

    // Date range (use BRIN or B-tree index)
    if (filters.since) {
      conditions.push(`created_at >= $${paramIndex++}`);
      params.push(filters.since);
    }

    // User filter (should be first in composite index)
    if (filters.userId) {
      conditions.push(`user_id = $${paramIndex++}`);
      params.push(filters.userId);
    }

    const whereClause = conditions.length > 0
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

    // Use keyset pagination for large offsets
    const paginationClause = pagination.cursor
      ? `AND (created_at, id) < ($${paramIndex++}, $${paramIndex++})`
      : '';

    if (pagination.cursor) {
      params.push(pagination.cursor.createdAt, pagination.cursor.id);
    }

    const query = `
      SELECT *
      FROM orders
      ${whereClause}
      ${paginationClause}
      ORDER BY created_at DESC, id DESC
      LIMIT $${paramIndex}
    `;
    params.push(pagination.limit);

    const result = await this.pool.query(query, params);
    return result.rows;
  }
}
```

### Anti-Patterns
- Using OFFSET for deep pagination
- SELECT * when only few columns needed
- Not analyzing query plans before optimization

---

## Checklist

### Connection Setup
- [ ] pgBouncer configured for connection pooling
- [ ] Transaction pool mode for web applications
- [ ] Statement timeout configured
- [ ] Application name set for debugging

### Indexing
- [ ] Composite indexes match query patterns
- [ ] Partial indexes for common filters
- [ ] INCLUDE columns for covering indexes
- [ ] Regular index bloat monitoring

### High Availability
- [ ] Streaming replication configured
- [ ] Automatic failover (Patroni/repmgr)
- [ ] WAL archiving for PITR
- [ ] Replication lag monitoring

### Performance
- [ ] pg_stat_statements enabled
- [ ] Slow query logging configured
- [ ] Regular VACUUM and ANALYZE
- [ ] Table partitioning for large tables

---

## References

- PostgreSQL Documentation: https://www.postgresql.org/docs/current/
- pgBouncer: https://www.pgbouncer.org/
- Patroni HA: https://github.com/zalando/patroni
- pg_stat_statements: https://www.postgresql.org/docs/current/pgstatstatements.html
- Citus for Sharding: https://www.citusdata.com/
