---
title: Database Tuning
category: data
type: reference
version: 1.0.0
---

# Database Tuning

## Overview

Database performance optimization patterns covering query analysis, resource configuration, caching strategies, and monitoring. Focus on PostgreSQL with applicable patterns for other relational databases.

## 80/20 Quick Reference

| Tuning Area | Key Parameter | Impact |
|-------------|---------------|--------|
| Memory | shared_buffers = 25% RAM | Buffer cache efficiency |
| Memory | effective_cache_size = 75% RAM | Query planner decisions |
| Work Memory | work_mem = RAM / (2 * max_connections) | Sort/hash operations |
| Connections | max_connections = reasonable limit | Memory overhead |
| Checkpoints | checkpoint_completion_target = 0.9 | I/O smoothing |
| WAL | wal_buffers = 64MB | Write throughput |

## Memory Configuration

### When to Use
Configure memory parameters based on available system RAM and workload characteristics.

### Example

```ini
# postgresql.conf for 32GB RAM server

# Shared buffers: 25% of RAM for dedicated DB server
# This is PostgreSQL's buffer cache
shared_buffers = 8GB

# Effective cache size: Estimate of OS + shared_buffers cache
# Used by query planner for cost estimation
effective_cache_size = 24GB

# Work memory: Per-operation memory for sorts, hashes, joins
# Be conservative: total_possible = work_mem * max_connections * operations_per_query
work_mem = 256MB

# Maintenance work memory: For VACUUM, CREATE INDEX, etc.
maintenance_work_mem = 2GB

# Huge pages: Reduce TLB pressure for large shared_buffers
huge_pages = try

# Connection limits
max_connections = 200  # Use pgBouncer for more

# Background writer: Spreads buffer writes over time
bgwriter_delay = 200ms
bgwriter_lru_maxpages = 100
bgwriter_lru_multiplier = 2.0
```

```typescript
// Dynamic memory calculator
interface ServerSpecs {
  totalRamGB: number;
  dedicatedDB: boolean;
  maxConnections: number;
  workloadType: 'oltp' | 'olap' | 'mixed';
}

function calculateMemorySettings(specs: ServerSpecs): Record<string, string> {
  const ramBytes = specs.totalRamGB * 1024 * 1024 * 1024;

  // Shared buffers: 25% for dedicated, 15% for shared
  const sharedBuffersRatio = specs.dedicatedDB ? 0.25 : 0.15;
  const sharedBuffers = Math.floor(ramBytes * sharedBuffersRatio);

  // Effective cache size: Assume OS caches remaining RAM
  const effectiveCacheRatio = specs.dedicatedDB ? 0.75 : 0.50;
  const effectiveCacheSize = Math.floor(ramBytes * effectiveCacheRatio);

  // Work memory based on workload
  const workMemMultiplier = {
    'oltp': 0.5,   // Many concurrent short queries
    'olap': 2.0,   // Few concurrent complex queries
    'mixed': 1.0
  };

  // work_mem = (RAM - shared_buffers) / (max_connections * 3 * multiplier)
  const availableForWork = ramBytes - sharedBuffers;
  const workMem = Math.floor(
    (availableForWork / (specs.maxConnections * 3)) * workMemMultiplier[specs.workloadType]
  );

  // Maintenance work memory: 5% of RAM, max 2GB
  const maintenanceWorkMem = Math.min(
    Math.floor(ramBytes * 0.05),
    2 * 1024 * 1024 * 1024
  );

  return {
    shared_buffers: formatBytes(sharedBuffers),
    effective_cache_size: formatBytes(effectiveCacheSize),
    work_mem: formatBytes(workMem),
    maintenance_work_mem: formatBytes(maintenanceWorkMem)
  };
}

function formatBytes(bytes: number): string {
  const gb = bytes / (1024 * 1024 * 1024);
  if (gb >= 1) return `${Math.floor(gb)}GB`;
  const mb = bytes / (1024 * 1024);
  return `${Math.floor(mb)}MB`;
}

// Example usage
const settings = calculateMemorySettings({
  totalRamGB: 32,
  dedicatedDB: true,
  maxConnections: 200,
  workloadType: 'mixed'
});
// Result: { shared_buffers: '8GB', effective_cache_size: '24GB', work_mem: '40MB', ... }
```

### Anti-Patterns
- shared_buffers > 40% of RAM (diminishing returns)
- Very high work_mem with many connections (OOM risk)
- Not setting effective_cache_size (bad query plans)

---

## Query Analysis

### When to Use
Use EXPLAIN ANALYZE to understand query execution and identify optimization opportunities.

### Example

```sql
-- Basic execution plan analysis
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.id, o.total, u.email
FROM orders o
JOIN users u ON u.id = o.user_id
WHERE o.status = 'pending'
  AND o.created_at > NOW() - INTERVAL '24 hours'
ORDER BY o.created_at DESC
LIMIT 100;

/*
Output interpretation:
- Seq Scan: Full table scan (usually bad for large tables)
- Index Scan: Using index (good)
- Index Only Scan: All data from index (best)
- Bitmap Index Scan: Multiple index conditions combined
- Nested Loop: Good for small result sets
- Hash Join: Good for larger joins
- Merge Join: Good for sorted data
- Sort: Expensive if in memory, very expensive if on disk
- Buffers: shared hit (cache) vs read (disk)
*/

-- Extended statistics for better cardinality estimates
CREATE STATISTICS stats_orders_status_date (dependencies)
ON status, created_at FROM orders;

ANALYZE orders;

-- Check if extended statistics help
EXPLAIN (ANALYZE)
SELECT COUNT(*) FROM orders
WHERE status = 'pending' AND created_at > NOW() - INTERVAL '1 day';
```

```typescript
// Query analysis helper
interface QueryPlanNode {
  'Node Type': string;
  'Actual Rows': number;
  'Plan Rows': number;
  'Actual Total Time': number;
  'Shared Hit Blocks': number;
  'Shared Read Blocks': number;
  Plans?: QueryPlanNode[];
}

class QueryAnalyzer {
  async analyzeQuery(sql: string): Promise<QueryAnalysis> {
    const result = await this.pool.query(
      `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ${sql}`
    );

    const plan = result.rows[0]['QUERY PLAN'][0];
    return this.analyzePlan(plan.Plan);
  }

  private analyzePlan(node: QueryPlanNode): QueryAnalysis {
    const issues: string[] = [];
    const recommendations: string[] = [];

    // Check for sequential scans on large tables
    if (node['Node Type'] === 'Seq Scan' && node['Actual Rows'] > 10000) {
      issues.push('Sequential scan on large table');
      recommendations.push('Consider adding index for filter columns');
    }

    // Check for cardinality estimation errors
    const estimationError = Math.abs(
      node['Actual Rows'] - node['Plan Rows']
    ) / Math.max(node['Plan Rows'], 1);

    if (estimationError > 10) {
      issues.push(`Cardinality estimation off by ${estimationError.toFixed(0)}x`);
      recommendations.push('Run ANALYZE or create extended statistics');
    }

    // Check for disk reads
    const hitRatio = node['Shared Hit Blocks'] /
      (node['Shared Hit Blocks'] + node['Shared Read Blocks'] + 0.01);

    if (hitRatio < 0.95) {
      issues.push(`Low buffer cache hit ratio: ${(hitRatio * 100).toFixed(1)}%`);
      recommendations.push('Consider increasing shared_buffers');
    }

    // Recursive analysis
    for (const child of node.Plans || []) {
      const childAnalysis = this.analyzePlan(child);
      issues.push(...childAnalysis.issues);
      recommendations.push(...childAnalysis.recommendations);
    }

    return {
      executionTime: node['Actual Total Time'],
      issues: [...new Set(issues)],
      recommendations: [...new Set(recommendations)]
    };
  }
}
```

```sql
-- Identify slow queries from pg_stat_statements
SELECT
    substring(query, 1, 100) AS query_preview,
    calls,
    ROUND(total_exec_time::numeric / 1000, 2) AS total_seconds,
    ROUND(mean_exec_time::numeric, 2) AS mean_ms,
    ROUND((shared_blks_hit * 100.0 / NULLIF(shared_blks_hit + shared_blks_read, 0))::numeric, 2) AS cache_hit_ratio,
    rows / NULLIF(calls, 0) AS avg_rows
FROM pg_stat_statements
WHERE calls > 100
ORDER BY total_exec_time DESC
LIMIT 20;

-- Find queries causing most disk reads
SELECT
    substring(query, 1, 100) AS query_preview,
    shared_blks_read,
    shared_blks_hit,
    ROUND((shared_blks_read * 8.0 / 1024)::numeric, 2) AS mb_read
FROM pg_stat_statements
WHERE shared_blks_read > 1000
ORDER BY shared_blks_read DESC
LIMIT 20;
```

### Anti-Patterns
- Optimizing without ANALYZE output
- Ignoring buffer statistics
- Not checking cardinality estimates

---

## Checkpoint Tuning

### When to Use
Configure checkpoints to balance recovery time against I/O load and query performance.

### Example

```ini
# postgresql.conf checkpoint settings

# Maximum WAL size before checkpoint (controls checkpoint frequency)
# Larger = fewer checkpoints, longer recovery time
max_wal_size = 4GB

# Minimum WAL size to retain
min_wal_size = 1GB

# Spread checkpoint writes over this fraction of checkpoint interval
# Higher value = smoother I/O, slightly longer checkpoints
checkpoint_completion_target = 0.9

# Write buffers to reduce WAL traffic
wal_buffers = 64MB

# Checkpoint timeout (max interval between checkpoints)
checkpoint_timeout = 15min

# Warning threshold for checkpoint frequency
checkpoint_warning = 30s
```

```sql
-- Monitor checkpoint activity
SELECT
    checkpoints_timed,
    checkpoints_req,
    checkpoint_write_time / 1000 AS write_seconds,
    checkpoint_sync_time / 1000 AS sync_seconds,
    buffers_checkpoint,
    buffers_clean,
    maxwritten_clean,
    buffers_backend,
    buffers_backend_fsync
FROM pg_stat_bgwriter;

/*
Key metrics:
- checkpoints_req high = max_wal_size too small
- checkpoint_write_time high = slow storage
- buffers_backend high = background writer too slow
- buffers_backend_fsync > 0 = serious I/O problem
*/

-- Check WAL generation rate
SELECT
    pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') / 1024 / 1024 / 1024 AS total_wal_gb,
    (pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') /
     EXTRACT(EPOCH FROM (NOW() - pg_postmaster_start_time())))
     / 1024 / 1024 AS wal_mb_per_second;
```

```typescript
// Checkpoint tuning calculator
interface WorkloadMetrics {
  walGenerationMBPerSec: number;
  acceptableRecoveryMinutes: number;
  storageIOPS: number;
  sharedBuffersMB: number;
}

function calculateCheckpointSettings(
  metrics: WorkloadMetrics
): Record<string, string> {
  // max_wal_size based on recovery time target
  // Recovery reads ~100MB/s on typical SSD
  const recoveryMBPerSec = 100;
  const maxWalMB = metrics.acceptableRecoveryMinutes * 60 * recoveryMBPerSec;

  // Ensure at least 5 minutes between checkpoints
  const minWalForInterval = metrics.walGenerationMBPerSec * 5 * 60;
  const recommendedMaxWal = Math.max(maxWalMB, minWalForInterval, 1024);

  // checkpoint_timeout based on WAL generation
  // Want checkpoints triggered by size, not timeout
  const timeToFillWal = recommendedMaxWal / metrics.walGenerationMBPerSec / 60;
  const checkpointTimeout = Math.min(Math.max(timeToFillWal * 1.5, 5), 30);

  // wal_buffers: 3% of shared_buffers, max 64MB
  const walBuffers = Math.min(
    Math.floor(metrics.sharedBuffersMB * 0.03),
    64
  );

  return {
    max_wal_size: `${Math.floor(recommendedMaxWal / 1024)}GB`,
    min_wal_size: `${Math.floor(recommendedMaxWal / 4096)}GB`,
    checkpoint_timeout: `${Math.floor(checkpointTimeout)}min`,
    checkpoint_completion_target: '0.9',
    wal_buffers: `${walBuffers}MB`
  };
}
```

### Anti-Patterns
- Very small max_wal_size (constant checkpoints)
- checkpoint_completion_target = 0.5 (I/O spikes)
- Ignoring checkpoint warnings in logs

---

## Connection Tuning

### When to Use
Optimize connection handling for application workload and available memory.

### Example

```ini
# postgresql.conf connection settings

# Maximum connections (each uses ~10MB RAM)
# Use pgBouncer for more concurrent clients
max_connections = 200

# Reserved for superuser
superuser_reserved_connections = 3

# Statement timeout (prevent runaway queries)
statement_timeout = 30s

# Lock timeout (prevent lock waiting)
lock_timeout = 10s

# Idle transaction timeout
idle_in_transaction_session_timeout = 5min

# TCP keepalive
tcp_keepalives_idle = 60
tcp_keepalives_interval = 10
tcp_keepalives_count = 6
```

```yaml
# pgbouncer.ini for connection pooling
[databases]
* = host=localhost port=5432

[pgbouncer]
listen_port = 6432
listen_addr = *

# Authentication
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Pool mode
# session: Connection bound to client until disconnect
# transaction: Connection returned after each transaction (recommended)
# statement: Connection returned after each statement (limited use)
pool_mode = transaction

# Pool sizing
default_pool_size = 20      # Per database/user pair
min_pool_size = 5
reserve_pool_size = 5
reserve_pool_timeout = 3

# Client limits
max_client_conn = 1000      # Total clients allowed
max_db_connections = 100    # Per database

# Timeouts
server_connect_timeout = 3
server_idle_timeout = 60
server_lifetime = 3600
client_idle_timeout = 0     # Never timeout idle clients
query_timeout = 30

# Logging
log_connections = 0
log_disconnections = 0
log_pooler_errors = 1
stats_period = 60
```

```sql
-- Monitor connection usage
SELECT
    datname AS database,
    state,
    COUNT(*) AS connections,
    MAX(EXTRACT(EPOCH FROM (NOW() - state_change))) AS max_idle_seconds
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY datname, state
ORDER BY datname, state;

-- Find long-running or idle transactions
SELECT
    pid,
    usename,
    datname,
    state,
    query_start,
    EXTRACT(EPOCH FROM (NOW() - query_start)) AS query_seconds,
    LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < NOW() - INTERVAL '30 seconds'
ORDER BY query_start;

-- Connection memory usage estimate
SELECT
    COUNT(*) AS connections,
    pg_size_pretty(COUNT(*) * 10 * 1024 * 1024) AS estimated_memory
FROM pg_stat_activity
WHERE backend_type = 'client backend';
```

### Anti-Patterns
- max_connections > 500 without pooling
- No statement timeout (runaway queries)
- Session pool mode with long-lived connections

---

## Vacuum and Autovacuum

### When to Use
Configure autovacuum to prevent table bloat and maintain query performance.

### Example

```ini
# postgresql.conf autovacuum settings

# Enable autovacuum (should always be on)
autovacuum = on

# Number of autovacuum workers
autovacuum_max_workers = 4

# How often to wake up and check tables
autovacuum_naptime = 30s

# Threshold: vacuum when dead tuples exceed this
autovacuum_vacuum_threshold = 50

# Scale factor: also vacuum when dead > live * scale_factor
autovacuum_vacuum_scale_factor = 0.05  # 5% of table

# Analyze thresholds (similar logic)
autovacuum_analyze_threshold = 50
autovacuum_analyze_scale_factor = 0.05

# Cost-based vacuum delay (prevent I/O saturation)
autovacuum_vacuum_cost_delay = 2ms
autovacuum_vacuum_cost_limit = 1000

# Freeze settings (prevent transaction ID wraparound)
vacuum_freeze_min_age = 50000000
vacuum_freeze_table_age = 150000000
autovacuum_freeze_max_age = 200000000
```

```sql
-- Table-specific autovacuum settings for high-churn tables
ALTER TABLE events SET (
    autovacuum_vacuum_scale_factor = 0.01,  -- Vacuum at 1% dead tuples
    autovacuum_vacuum_threshold = 1000,
    autovacuum_analyze_scale_factor = 0.01,
    autovacuum_vacuum_cost_delay = 0        -- No delay for this table
);

-- Monitor table bloat
SELECT
    schemaname || '.' || relname AS table_name,
    n_live_tup,
    n_dead_tup,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_percent,
    last_vacuum,
    last_autovacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC
LIMIT 20;

-- Check for tables approaching wraparound
SELECT
    schemaname || '.' || relname AS table_name,
    age(relfrozenxid) AS xid_age,
    pg_size_pretty(pg_total_relation_size(oid)) AS total_size
FROM pg_class
JOIN pg_namespace ON pg_class.relnamespace = pg_namespace.oid
WHERE relkind = 'r'
  AND nspname NOT IN ('pg_catalog', 'information_schema')
ORDER BY age(relfrozenxid) DESC
LIMIT 20;

-- Estimate table bloat
WITH constants AS (
    SELECT current_setting('block_size')::numeric AS bs
),
table_stats AS (
    SELECT
        schemaname,
        tablename,
        (SELECT bs FROM constants) * reltuples / NULLIF(relpages, 0) AS avg_tuple_size,
        reltuples,
        relpages
    FROM pg_class
    JOIN pg_stat_user_tables ON relid = pg_class.oid
)
SELECT
    schemaname || '.' || tablename AS table_name,
    pg_size_pretty(relpages * 8192::bigint) AS actual_size,
    pg_size_pretty((reltuples * avg_tuple_size)::bigint) AS estimated_size,
    ROUND(100 * (1 - (reltuples * avg_tuple_size) / NULLIF(relpages * 8192, 0)), 2) AS bloat_percent
FROM table_stats
WHERE relpages > 100
ORDER BY bloat_percent DESC;
```

```typescript
// Bloat monitoring and alerting
class BloatMonitor {
  async checkBloat(): Promise<BloatReport[]> {
    const result = await this.pool.query(`
      SELECT
        schemaname || '.' || relname AS table_name,
        n_live_tup,
        n_dead_tup,
        pg_total_relation_size(relid) AS total_bytes,
        COALESCE(last_autovacuum, last_vacuum) AS last_vacuum
      FROM pg_stat_user_tables
      WHERE n_live_tup + n_dead_tup > 10000
    `);

    return result.rows.map(row => ({
      tableName: row.table_name,
      deadTuplePercent: (row.n_dead_tup / (row.n_live_tup + row.n_dead_tup)) * 100,
      sizeBytes: row.total_bytes,
      hoursSinceVacuum: row.last_vacuum
        ? (Date.now() - new Date(row.last_vacuum).getTime()) / 3600000
        : null
    }));
  }

  async alertOnBloat(threshold: number = 20): Promise<void> {
    const reports = await this.checkBloat();

    for (const report of reports) {
      if (report.deadTuplePercent > threshold) {
        await this.sendAlert({
          severity: report.deadTuplePercent > 50 ? 'critical' : 'warning',
          message: `Table ${report.tableName} has ${report.deadTuplePercent.toFixed(1)}% bloat`,
          recommendation: 'Consider running VACUUM FULL during maintenance window'
        });
      }
    }
  }
}
```

### Anti-Patterns
- Disabling autovacuum
- Very high scale_factor (delayed vacuuming)
- Not monitoring for wraparound

---

## Monitoring Queries

### When to Use
Set up comprehensive monitoring queries for database health dashboards.

### Example

```sql
-- Database overview dashboard
SELECT
    datname AS database,
    pg_size_pretty(pg_database_size(datname)) AS size,
    numbackends AS connections,
    xact_commit AS commits,
    xact_rollback AS rollbacks,
    blks_read,
    blks_hit,
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS cache_hit_ratio
FROM pg_stat_database
WHERE datname NOT LIKE 'template%';

-- Table I/O statistics
SELECT
    schemaname || '.' || relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    idx_tup_fetch,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    n_tup_hot_upd AS hot_updates,
    ROUND(100.0 * n_tup_hot_upd / NULLIF(n_tup_upd, 0), 2) AS hot_update_ratio
FROM pg_stat_user_tables
ORDER BY seq_tup_read DESC
LIMIT 20;

-- Index usage statistics
SELECT
    schemaname || '.' || relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC
LIMIT 20;

-- Lock monitoring
SELECT
    pg_locks.pid,
    pg_stat_activity.usename,
    pg_locks.locktype,
    pg_locks.mode,
    pg_locks.granted,
    pg_class.relname,
    pg_stat_activity.query_start,
    LEFT(pg_stat_activity.query, 100) AS query
FROM pg_locks
JOIN pg_stat_activity ON pg_locks.pid = pg_stat_activity.pid
LEFT JOIN pg_class ON pg_locks.relation = pg_class.oid
WHERE NOT pg_locks.granted
ORDER BY pg_stat_activity.query_start;

-- Replication lag (on primary)
SELECT
    client_addr,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS replay_lag_bytes,
    pg_wal_lsn_diff(sent_lsn, flush_lsn) AS flush_lag_bytes
FROM pg_stat_replication;
```

```typescript
// Prometheus metrics exporter
import { Registry, Gauge, Counter } from 'prom-client';

class PostgresExporter {
  private registry: Registry;
  private dbSizeGauge: Gauge;
  private connectionGauge: Gauge;
  private cacheHitRatio: Gauge;
  private replicationLag: Gauge;

  constructor(private pool: Pool) {
    this.registry = new Registry();

    this.dbSizeGauge = new Gauge({
      name: 'postgres_database_size_bytes',
      help: 'Database size in bytes',
      labelNames: ['database'],
      registers: [this.registry]
    });

    this.connectionGauge = new Gauge({
      name: 'postgres_connections_total',
      help: 'Number of database connections',
      labelNames: ['database', 'state'],
      registers: [this.registry]
    });

    this.cacheHitRatio = new Gauge({
      name: 'postgres_cache_hit_ratio',
      help: 'Buffer cache hit ratio',
      registers: [this.registry]
    });

    this.replicationLag = new Gauge({
      name: 'postgres_replication_lag_bytes',
      help: 'Replication lag in bytes',
      labelNames: ['replica'],
      registers: [this.registry]
    });
  }

  async collect(): Promise<void> {
    // Database sizes
    const sizeResult = await this.pool.query(`
      SELECT datname, pg_database_size(datname) AS size_bytes
      FROM pg_database WHERE datname NOT LIKE 'template%'
    `);
    for (const row of sizeResult.rows) {
      this.dbSizeGauge.set({ database: row.datname }, row.size_bytes);
    }

    // Connections
    const connResult = await this.pool.query(`
      SELECT datname, state, COUNT(*) AS count
      FROM pg_stat_activity
      WHERE backend_type = 'client backend'
      GROUP BY datname, state
    `);
    for (const row of connResult.rows) {
      this.connectionGauge.set(
        { database: row.datname, state: row.state || 'unknown' },
        parseInt(row.count)
      );
    }

    // Cache hit ratio
    const cacheResult = await this.pool.query(`
      SELECT SUM(blks_hit) / NULLIF(SUM(blks_hit) + SUM(blks_read), 0) AS ratio
      FROM pg_stat_database
    `);
    if (cacheResult.rows[0].ratio) {
      this.cacheHitRatio.set(parseFloat(cacheResult.rows[0].ratio));
    }

    // Replication lag
    const replResult = await this.pool.query(`
      SELECT client_addr,
             pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
      FROM pg_stat_replication
    `);
    for (const row of replResult.rows) {
      this.replicationLag.set(
        { replica: row.client_addr },
        parseInt(row.lag_bytes || '0')
      );
    }
  }

  getMetrics(): Promise<string> {
    return this.registry.metrics();
  }
}
```

### Anti-Patterns
- No baseline metrics collection
- Ignoring cache hit ratio
- Not monitoring replication lag

---

## Checklist

### Initial Setup
- [ ] Memory parameters calculated for server RAM
- [ ] Connection limits set appropriately
- [ ] Checkpoint settings tuned for workload
- [ ] Autovacuum configured and enabled

### Ongoing Monitoring
- [ ] pg_stat_statements enabled
- [ ] Slow query logging configured
- [ ] Buffer cache hit ratio tracked
- [ ] Table bloat monitored

### Query Optimization
- [ ] Slow queries identified
- [ ] EXPLAIN ANALYZE used for analysis
- [ ] Indexes created for common patterns
- [ ] Extended statistics where helpful

### Maintenance
- [ ] Regular VACUUM ANALYZE scheduled
- [ ] Index bloat checked
- [ ] Transaction ID wraparound monitored
- [ ] Query performance regression alerts

---

## References

- PostgreSQL Performance Wiki: https://wiki.postgresql.org/wiki/Performance_Optimization
- PGTune Calculator: https://pgtune.leopard.in.ua/
- PostgreSQL Monitoring Guide: https://www.postgresql.org/docs/current/monitoring.html
- pg_stat_statements: https://www.postgresql.org/docs/current/pgstatstatements.html
- Vacuum Documentation: https://www.postgresql.org/docs/current/routine-vacuuming.html
