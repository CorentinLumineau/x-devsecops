---
title: Database Migrations
category: data
type: reference
version: 1.0.0
---

# Database Migrations

## Overview

Database schema migration patterns for safe, reversible, and zero-downtime deployments. Covers migration tooling, backward-compatible changes, data migrations, and rollback strategies.

## 80/20 Quick Reference

| Migration Type | Safety Level | Approach |
|----------------|--------------|----------|
| Add column (nullable) | Safe | Direct apply |
| Add column (NOT NULL) | Requires planning | Add nullable, backfill, add constraint |
| Drop column | Dangerous | Stop reading first, then drop |
| Rename column | Dangerous | Add new, copy, drop old |
| Add index | Safe | CONCURRENTLY in production |
| Change data type | Dangerous | New column approach |

## Migration File Structure

### When to Use
Organize migration files with consistent naming and versioning for reliable execution order.

### Example

```
migrations/
├── 20240301_001_create_users_table.sql
├── 20240301_002_add_users_email_index.sql
├── 20240315_001_create_orders_table.sql
├── 20240315_002_add_orders_user_fk.sql
├── 20240401_001_add_users_phone_column.sql
└── README.md
```

```sql
-- migrations/20240301_001_create_users_table.sql

-- Migration: Create users table
-- Author: Jane Developer
-- Date: 2024-03-01
-- Ticket: JIRA-1234

-- +migrate Up
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_users_email ON users (email);

COMMENT ON TABLE users IS 'User accounts for authentication';
COMMENT ON COLUMN users.email IS 'Unique email address for login';

-- +migrate Down
DROP TABLE IF EXISTS users CASCADE;
```

```typescript
// Migration runner with transaction support
import { Pool, PoolClient } from 'pg';
import * as fs from 'fs';
import * as path from 'path';

interface Migration {
  version: string;
  name: string;
  upSql: string;
  downSql: string;
}

class MigrationRunner {
  constructor(private pool: Pool) {}

  async initialize(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        checksum VARCHAR(64) NOT NULL
      )
    `);
  }

  async loadMigrations(dir: string): Promise<Migration[]> {
    const files = fs.readdirSync(dir)
      .filter(f => f.endsWith('.sql'))
      .sort();

    return files.map(file => {
      const content = fs.readFileSync(path.join(dir, file), 'utf-8');
      const [upSql, downSql] = this.parseMigration(content);
      const [version, ...nameParts] = file.replace('.sql', '').split('_');

      return {
        version: version.replace(/^(\d{8})_(\d{3})/, '$1$2'),
        name: nameParts.join('_'),
        upSql,
        downSql
      };
    });
  }

  private parseMigration(content: string): [string, string] {
    const upMatch = content.match(/-- \+migrate Up\n([\s\S]*?)(?=-- \+migrate Down|$)/);
    const downMatch = content.match(/-- \+migrate Down\n([\s\S]*?)$/);

    return [
      upMatch?.[1]?.trim() || '',
      downMatch?.[1]?.trim() || ''
    ];
  }

  async migrate(): Promise<void> {
    const migrations = await this.loadMigrations('./migrations');
    const applied = await this.getAppliedMigrations();

    for (const migration of migrations) {
      if (applied.has(migration.version)) {
        continue;
      }

      console.log(`Applying migration: ${migration.version} - ${migration.name}`);
      await this.applyMigration(migration);
    }
  }

  private async applyMigration(migration: Migration): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Execute migration
      await client.query(migration.upSql);

      // Record migration
      await client.query(
        `INSERT INTO schema_migrations (version, name, checksum)
         VALUES ($1, $2, $3)`,
        [migration.version, migration.name, this.checksum(migration.upSql)]
      );

      await client.query('COMMIT');
      console.log(`Applied: ${migration.version}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async rollback(steps: number = 1): Promise<void> {
    const migrations = await this.loadMigrations('./migrations');
    const applied = await this.getAppliedMigrationsOrdered();

    for (let i = 0; i < steps && i < applied.length; i++) {
      const version = applied[i];
      const migration = migrations.find(m => m.version === version);

      if (!migration) {
        throw new Error(`Migration not found: ${version}`);
      }

      console.log(`Rolling back: ${version} - ${migration.name}`);
      await this.rollbackMigration(migration);
    }
  }

  private async rollbackMigration(migration: Migration): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(migration.downSql);
      await client.query(
        'DELETE FROM schema_migrations WHERE version = $1',
        [migration.version]
      );
      await client.query('COMMIT');
      console.log(`Rolled back: ${migration.version}`);
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private async getAppliedMigrations(): Promise<Set<string>> {
    const result = await this.pool.query(
      'SELECT version FROM schema_migrations'
    );
    return new Set(result.rows.map(r => r.version));
  }

  private async getAppliedMigrationsOrdered(): Promise<string[]> {
    const result = await this.pool.query(
      'SELECT version FROM schema_migrations ORDER BY version DESC'
    );
    return result.rows.map(r => r.version);
  }

  private checksum(content: string): string {
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(content).digest('hex');
  }
}
```

### Anti-Patterns
- No down migration defined
- Missing transaction wrapping
- No checksum validation

---

## Zero-Downtime Migrations

### When to Use
Deploy schema changes without application downtime using expand-contract pattern.

### Example

```sql
-- DANGEROUS: Adding NOT NULL column directly causes table lock
-- ALTER TABLE orders ADD COLUMN shipping_address_id BIGINT NOT NULL;

-- SAFE: Multi-step approach for NOT NULL column

-- Step 1: Add nullable column (instant, no lock)
ALTER TABLE orders ADD COLUMN shipping_address_id BIGINT;

-- Step 2: Backfill data in batches (application still running)
UPDATE orders
SET shipping_address_id = (
    SELECT id FROM addresses
    WHERE addresses.user_id = orders.user_id
    AND addresses.is_default = true
    LIMIT 1
)
WHERE shipping_address_id IS NULL
  AND id BETWEEN 1 AND 10000;

-- Repeat for all batches...

-- Step 3: Add NOT NULL constraint after all data populated
ALTER TABLE orders
ALTER COLUMN shipping_address_id SET NOT NULL;

-- Step 4: Add foreign key constraint (VALIDATE separately for speed)
ALTER TABLE orders
ADD CONSTRAINT fk_orders_shipping_address
FOREIGN KEY (shipping_address_id) REFERENCES addresses(id)
NOT VALID;

-- Validate in background (allows concurrent reads/writes)
ALTER TABLE orders
VALIDATE CONSTRAINT fk_orders_shipping_address;
```

```typescript
// Batch backfill script
class BackfillRunner {
  constructor(
    private pool: Pool,
    private batchSize: number = 10000
  ) {}

  async backfillShippingAddress(): Promise<void> {
    let totalUpdated = 0;
    let hasMore = true;

    while (hasMore) {
      const result = await this.pool.query(`
        WITH batch AS (
          SELECT id
          FROM orders
          WHERE shipping_address_id IS NULL
          LIMIT $1
          FOR UPDATE SKIP LOCKED
        )
        UPDATE orders o
        SET shipping_address_id = (
          SELECT a.id
          FROM addresses a
          WHERE a.user_id = o.user_id
            AND a.is_default = true
          LIMIT 1
        )
        FROM batch b
        WHERE o.id = b.id
        RETURNING o.id
      `, [this.batchSize]);

      totalUpdated += result.rowCount ?? 0;
      hasMore = (result.rowCount ?? 0) === this.batchSize;

      console.log(`Updated ${totalUpdated} rows`);

      // Rate limiting to avoid overloading DB
      await this.sleep(100);
    }

    console.log(`Backfill complete: ${totalUpdated} total rows`);
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
```

```sql
-- SAFE: Adding index concurrently
-- Regular CREATE INDEX locks the table
CREATE INDEX CONCURRENTLY idx_orders_shipping_address
ON orders (shipping_address_id);

-- SAFE: Renaming column (expand-contract pattern)
-- Step 1: Add new column
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);

-- Step 2: Deploy code that writes to BOTH columns
-- Step 3: Backfill new column
UPDATE users SET full_name = name WHERE full_name IS NULL;

-- Step 4: Deploy code that reads from new column
-- Step 5: Stop writing to old column
-- Step 6: Drop old column (after deployment stable)
ALTER TABLE users DROP COLUMN name;
```

### Anti-Patterns
- Large UPDATE without batching
- Adding NOT NULL constraint immediately
- Creating index without CONCURRENTLY

---

## Data Migrations

### When to Use
Migrate data between formats, denormalize for performance, or transform existing records.

### Example

```sql
-- migrations/20240401_001_migrate_address_to_jsonb.sql

-- +migrate Up

-- Step 1: Add new JSONB column
ALTER TABLE users ADD COLUMN address_data JSONB;

-- Step 2: Migrate existing data
UPDATE users
SET address_data = jsonb_build_object(
    'street', address_line1,
    'street2', address_line2,
    'city', city,
    'state', state,
    'postal_code', postal_code,
    'country', country
)
WHERE address_data IS NULL;

-- Step 3: Create index on new column
CREATE INDEX CONCURRENTLY idx_users_address_city
ON users ((address_data->>'city'));

-- Note: Old columns will be dropped in future migration
-- after application fully migrated

-- +migrate Down
DROP INDEX IF EXISTS idx_users_address_city;
ALTER TABLE users DROP COLUMN IF EXISTS address_data;
```

```typescript
// Complex data migration with progress tracking
interface MigrationProgress {
  total: number;
  processed: number;
  errors: number;
  startedAt: Date;
  lastProcessedId: number;
}

class DataMigration {
  private progress: MigrationProgress;

  constructor(
    private pool: Pool,
    private batchSize: number = 1000
  ) {
    this.progress = {
      total: 0,
      processed: 0,
      errors: 0,
      startedAt: new Date(),
      lastProcessedId: 0
    };
  }

  async migrateUserAddresses(): Promise<MigrationProgress> {
    // Get total count
    const countResult = await this.pool.query(
      'SELECT COUNT(*) FROM users WHERE address_data IS NULL'
    );
    this.progress.total = parseInt(countResult.rows[0].count);

    console.log(`Starting migration of ${this.progress.total} users`);

    // Resume from last position if restarting
    let lastId = await this.getCheckpoint() || 0;

    while (true) {
      const batch = await this.fetchBatch(lastId);
      if (batch.length === 0) break;

      await this.processBatch(batch);

      lastId = batch[batch.length - 1].id;
      await this.saveCheckpoint(lastId);

      this.logProgress();
    }

    console.log('Migration complete!');
    return this.progress;
  }

  private async fetchBatch(afterId: number): Promise<UserRow[]> {
    const result = await this.pool.query(`
      SELECT id, address_line1, address_line2, city, state, postal_code, country
      FROM users
      WHERE id > $1 AND address_data IS NULL
      ORDER BY id
      LIMIT $2
    `, [afterId, this.batchSize]);

    return result.rows;
  }

  private async processBatch(batch: UserRow[]): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      for (const user of batch) {
        try {
          const addressData = this.transformAddress(user);
          await client.query(
            'UPDATE users SET address_data = $1 WHERE id = $2',
            [JSON.stringify(addressData), user.id]
          );
          this.progress.processed++;
        } catch (error) {
          console.error(`Error processing user ${user.id}:`, error);
          this.progress.errors++;
          // Continue with other records
        }
      }

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  private transformAddress(user: UserRow): AddressData {
    return {
      street: user.address_line1?.trim() || null,
      street2: user.address_line2?.trim() || null,
      city: user.city?.trim() || null,
      state: user.state?.trim()?.toUpperCase() || null,
      postalCode: this.normalizePostalCode(user.postal_code),
      country: user.country?.trim()?.toUpperCase() || 'US'
    };
  }

  private normalizePostalCode(code: string | null): string | null {
    if (!code) return null;
    // Remove non-alphanumeric, uppercase
    return code.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  }

  private async getCheckpoint(): Promise<number | null> {
    const result = await this.pool.query(`
      SELECT value FROM migration_checkpoints
      WHERE name = 'user_address_migration'
    `);
    return result.rows[0]?.value || null;
  }

  private async saveCheckpoint(lastId: number): Promise<void> {
    await this.pool.query(`
      INSERT INTO migration_checkpoints (name, value, updated_at)
      VALUES ('user_address_migration', $1, NOW())
      ON CONFLICT (name) DO UPDATE SET value = $1, updated_at = NOW()
    `, [lastId]);
  }

  private logProgress(): void {
    const elapsed = (Date.now() - this.progress.startedAt.getTime()) / 1000;
    const rate = this.progress.processed / elapsed;
    const remaining = (this.progress.total - this.progress.processed) / rate;

    console.log(
      `Progress: ${this.progress.processed}/${this.progress.total} ` +
      `(${((this.progress.processed / this.progress.total) * 100).toFixed(1)}%) ` +
      `Rate: ${rate.toFixed(0)}/s, ETA: ${(remaining / 60).toFixed(1)} min`
    );
  }
}
```

### Anti-Patterns
- No checkpointing for resumability
- Transforming data without validation
- No progress visibility

---

## Rollback Strategies

### When to Use
Plan rollback procedures for every migration to enable rapid recovery from failed deployments.

### Example

```typescript
// Migration with automated rollback testing
interface MigrationWithRollback {
  version: string;
  up: (client: PoolClient) => Promise<void>;
  down: (client: PoolClient) => Promise<void>;
  verify: (client: PoolClient) => Promise<boolean>;
}

const migration: MigrationWithRollback = {
  version: '20240401001',

  async up(client: PoolClient): Promise<void> {
    // Add new column
    await client.query(`
      ALTER TABLE orders ADD COLUMN total_with_tax NUMERIC(12, 2)
    `);

    // Populate with calculated values
    await client.query(`
      UPDATE orders
      SET total_with_tax = total * 1.08
      WHERE total_with_tax IS NULL
    `);
  },

  async down(client: PoolClient): Promise<void> {
    await client.query(`
      ALTER TABLE orders DROP COLUMN IF EXISTS total_with_tax
    `);
  },

  async verify(client: PoolClient): Promise<boolean> {
    // Check column exists
    const columnExists = await client.query(`
      SELECT 1 FROM information_schema.columns
      WHERE table_name = 'orders' AND column_name = 'total_with_tax'
    `);

    if (columnExists.rows.length === 0) return false;

    // Check no NULL values
    const nullCount = await client.query(`
      SELECT COUNT(*) FROM orders WHERE total_with_tax IS NULL
    `);

    return parseInt(nullCount.rows[0].count) === 0;
  }
};

// Rollback test runner
class RollbackTester {
  async testRollback(
    migration: MigrationWithRollback
  ): Promise<{ success: boolean; error?: Error }> {
    const client = await this.pool.connect();

    try {
      // Start transaction for isolated testing
      await client.query('BEGIN');

      // Apply migration
      await migration.up(client);

      // Verify it worked
      const upSuccess = await migration.verify(client);
      if (!upSuccess) {
        throw new Error('Migration verification failed');
      }

      // Rollback
      await migration.down(client);

      // Reapply to ensure idempotency
      await migration.up(client);

      // Final verification
      const finalSuccess = await migration.verify(client);
      if (!finalSuccess) {
        throw new Error('Reapplication verification failed');
      }

      // Rollback transaction (cleanup test)
      await client.query('ROLLBACK');

      return { success: true };
    } catch (error) {
      await client.query('ROLLBACK');
      return { success: false, error: error as Error };
    } finally {
      client.release();
    }
  }
}
```

```sql
-- Point-in-Time Recovery (PITR) setup

-- Enable continuous archiving
-- postgresql.conf
archive_mode = on
archive_command = 'aws s3 cp %p s3://db-wal-archive/%f'
wal_level = replica

-- Restore to specific point
-- recovery.signal file
restore_command = 'aws s3 cp s3://db-wal-archive/%f %p'
recovery_target_time = '2024-04-01 14:30:00 UTC'
recovery_target_action = 'promote'
```

```yaml
# Database backup strategy
backup:
  # Full backup weekly
  full:
    schedule: "0 0 * * 0"  # Sunday midnight
    retention: 4  # Keep 4 weeks
    command: |
      pg_dump -Fc -f /backups/full_$(date +%Y%m%d).dump $DATABASE_URL

  # Incremental via WAL archiving
  wal:
    enabled: true
    destination: s3://db-wal-archive/
    retention: 7d

  # Pre-migration backup
  pre_migration:
    enabled: true
    command: |
      pg_dump -Fc -f /backups/pre_migration_$(date +%Y%m%d_%H%M%S).dump $DATABASE_URL

# Restore procedures
restore:
  from_full:
    command: |
      pg_restore -d $DATABASE_URL /backups/full_latest.dump

  from_pitr:
    steps:
      - "Stop application"
      - "Restore base backup"
      - "Apply WAL until target time"
      - "Verify data integrity"
      - "Restart application"
```

### Anti-Patterns
- No rollback testing before production
- Missing backup before migration
- No PITR capability for data loss scenarios

---

## CI/CD Integration

### When to Use
Automate migration execution in deployment pipelines with safety checks.

### Example

```yaml
# .github/workflows/deploy.yml
name: Deploy with Migrations

on:
  push:
    branches: [main]

jobs:
  migrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate migrations
        run: |
          # Check all migrations have down scripts
          for file in migrations/*.sql; do
            if ! grep -q "+migrate Down" "$file"; then
              echo "Missing down migration in $file"
              exit 1
            fi
          done

          # Check for dangerous patterns
          for file in migrations/*.sql; do
            if grep -qi "DROP TABLE\|DROP DATABASE\|TRUNCATE" "$file"; then
              echo "Dangerous command in $file - requires manual review"
              exit 1
            fi
          done

      - name: Run migrations on staging
        env:
          DATABASE_URL: ${{ secrets.STAGING_DATABASE_URL }}
        run: |
          npm run migrate:up

      - name: Run integration tests
        env:
          DATABASE_URL: ${{ secrets.STAGING_DATABASE_URL }}
        run: |
          npm run test:integration

      - name: Create pre-migration backup
        if: github.ref == 'refs/heads/main'
        run: |
          pg_dump -Fc ${{ secrets.PROD_DATABASE_URL }} \
            -f backup_$(date +%Y%m%d_%H%M%S).dump
          aws s3 cp backup_*.dump s3://db-backups/pre-migration/

      - name: Run migrations on production
        if: github.ref == 'refs/heads/main'
        env:
          DATABASE_URL: ${{ secrets.PROD_DATABASE_URL }}
        run: |
          npm run migrate:up

      - name: Verify migration
        run: |
          npm run migrate:verify
```

```typescript
// Migration verification script
async function verifyMigrations(): Promise<void> {
  const applied = await getAppliedMigrations();
  const expected = await getExpectedMigrations();

  // Check all expected migrations are applied
  for (const migration of expected) {
    if (!applied.has(migration.version)) {
      throw new Error(`Migration not applied: ${migration.version}`);
    }
  }

  // Check checksums match
  for (const [version, checksum] of applied) {
    const expected = expectedChecksums.get(version);
    if (expected && expected !== checksum) {
      throw new Error(`Checksum mismatch for ${version}`);
    }
  }

  // Run integrity checks
  await runIntegrityChecks();

  console.log('All migrations verified successfully');
}

async function runIntegrityChecks(): Promise<void> {
  // Check foreign key constraints
  const fkViolations = await pool.query(`
    SELECT conname, conrelid::regclass AS table_name
    FROM pg_constraint
    WHERE contype = 'f'
    AND NOT convalidated
  `);

  if (fkViolations.rows.length > 0) {
    throw new Error(`Unvalidated foreign keys: ${JSON.stringify(fkViolations.rows)}`);
  }

  // Check for invalid indexes
  const invalidIndexes = await pool.query(`
    SELECT indexrelid::regclass AS index_name
    FROM pg_index
    WHERE NOT indisvalid
  `);

  if (invalidIndexes.rows.length > 0) {
    throw new Error(`Invalid indexes: ${JSON.stringify(invalidIndexes.rows)}`);
  }
}
```

### Anti-Patterns
- No staging environment testing
- Missing pre-migration backup
- No automated rollback on failure

---

## Checklist

### Before Writing Migration
- [ ] Change is backward compatible with running code
- [ ] Down migration tested
- [ ] Data migration batched if large table
- [ ] Index creation uses CONCURRENTLY

### Before Deploying
- [ ] Migration tested on staging with production data copy
- [ ] Backup created
- [ ] Rollback plan documented
- [ ] Maintenance window scheduled if needed

### After Deploying
- [ ] Migration status verified
- [ ] Application health checked
- [ ] Performance metrics normal
- [ ] Follow-up migrations scheduled

---

## References

- PostgreSQL ALTER TABLE: https://www.postgresql.org/docs/current/sql-altertable.html
- Zero Downtime Migrations: https://blog.jcoglan.com/2020/12/01/schema-migrations-in-zero-downtime-deployments/
- Expand/Contract Pattern: https://martinfowler.com/bliki/ParallelChange.html
- SQL Migrate: https://github.com/rubenv/sql-migrate
- Flyway: https://flywaydb.org/documentation/
