---
title: Backup Strategies Reference
category: operations
type: reference
version: "1.0.0"
---

# Backup Strategies

> Part of the operations/disaster-recovery knowledge skill

## Overview

Backup strategies define how data is protected and how quickly it can be restored. Choosing the right strategy depends on RPO requirements, data volume, and budget.

## Quick Reference (80/20)

| Strategy | RPO | Restore Speed | Storage Cost |
|----------|-----|---------------|-------------|
| Continuous replication | ~0 | Fast | High |
| Incremental snapshot | Minutes | Medium | Medium |
| Differential backup | Hours | Medium | Medium |
| Full backup | Hours-days | Slow | High per copy |
| Log shipping | Minutes | Medium | Low |

## Patterns

### Pattern 1: Database Backup Strategy

**When to Use**: Protecting relational databases

**Example**:
```yaml
# PostgreSQL backup configuration
backup:
  # Continuous WAL archiving for point-in-time recovery
  wal_archiving:
    enabled: true
    archive_command: "aws s3 cp %p s3://backups/wal/%f"
    restore_command: "aws s3 cp s3://backups/wal/%f %p"

  # Base backups
  base_backup:
    schedule: "0 2 * * *"  # Daily at 2 AM
    tool: pg_basebackup
    compression: gzip
    retention:
      daily: 7
      weekly: 4
      monthly: 12

  # Logical backups for portability
  logical_backup:
    schedule: "0 3 * * 0"  # Weekly Sunday 3 AM
    tool: pg_dump
    format: custom
    retention: 30 days
```

```bash
#!/bin/bash
# automated-backup.sh - PostgreSQL backup with rotation

set -euo pipefail

DB_NAME="${1:?Database name required}"
BACKUP_DIR="/backups/${DB_NAME}"
S3_BUCKET="s3://company-backups/${DB_NAME}"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup
echo "Starting backup of ${DB_NAME}..."
pg_dump \
  --format=custom \
  --compress=9 \
  --file="${BACKUP_DIR}/${DB_NAME}_${DATE}.dump" \
  "${DB_NAME}"

# Upload to S3
aws s3 cp \
  "${BACKUP_DIR}/${DB_NAME}_${DATE}.dump" \
  "${S3_BUCKET}/${DATE}/" \
  --storage-class STANDARD_IA

# Verify backup integrity
pg_restore \
  --list \
  "${BACKUP_DIR}/${DB_NAME}_${DATE}.dump" > /dev/null 2>&1 \
  && echo "Backup verified successfully" \
  || { echo "Backup verification FAILED"; exit 1; }

# Cleanup old local backups
find "${BACKUP_DIR}" -name "*.dump" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed: ${DB_NAME}_${DATE}.dump"
```

**Anti-Pattern**: Only taking full backups without WAL archiving (no point-in-time recovery).

### Pattern 2: Application State Backup

**When to Use**: Backing up application data beyond databases

**Example**:
```yaml
# Velero backup for Kubernetes
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-app-backup
  namespace: velero
spec:
  schedule: "0 1 * * *"
  template:
    includedNamespaces:
      - production
      - staging
    includedResources:
      - persistentvolumeclaims
      - persistentvolumes
      - configmaps
      - secrets
      - deployments
      - services
      - ingresses
    excludedResources:
      - events
      - pods
    snapshotVolumes: true
    storageLocation: aws-s3
    volumeSnapshotLocations:
      - aws-ebs
    ttl: 720h  # 30 days
    hooks:
      resources:
        - name: pre-backup-db
          includedNamespaces:
            - production
          pre:
            - exec:
                container: postgres
                command:
                  - /bin/bash
                  - -c
                  - "pg_dump -Fc mydb > /backup/pre-snapshot.dump"
                onError: Fail
                timeout: 300s
```

**Anti-Pattern**: Backing up only databases but not configuration, secrets, or application state.

### Pattern 3: Immutable Backups

**When to Use**: Protecting against ransomware and accidental deletion

**Example**:
```json
{
  "Comment": "S3 Object Lock for immutable backups",
  "Rules": [
    {
      "ObjectLockEnabled": "Enabled",
      "DefaultRetention": {
        "Mode": "COMPLIANCE",
        "Days": 365
      }
    }
  ]
}
```

```bash
# Enable object lock on bucket
aws s3api put-object-lock-configuration \
  --bucket company-backups \
  --object-lock-configuration '{
    "ObjectLockEnabled": "Enabled",
    "Rule": {
      "DefaultRetention": {
        "Mode": "GOVERNANCE",
        "Days": 90
      }
    }
  }'

# Upload with retention
aws s3api put-object \
  --bucket company-backups \
  --key "db/backup-2026-01-28.dump" \
  --body backup.dump \
  --object-lock-mode COMPLIANCE \
  --object-lock-retain-until-date "2027-01-28T00:00:00Z"
```

**Anti-Pattern**: Backups stored in the same account/region as production without write protection.

### Pattern 4: Cross-Region Replication

**When to Use**: Protecting against regional failures

**Example**:
```terraform
# Terraform - S3 cross-region replication
resource "aws_s3_bucket" "backup_primary" {
  bucket = "company-backups-us-east-1"

  versioning {
    enabled = true
  }

  replication_configuration {
    role = aws_iam_role.replication.arn

    rules {
      id     = "replicate-all"
      status = "Enabled"

      destination {
        bucket        = aws_s3_bucket.backup_replica.arn
        storage_class = "STANDARD_IA"

        encryption_configuration {
          replica_kms_key_id = aws_kms_key.replica.arn
        }
      }

      source_selection_criteria {
        sse_kms_encrypted_objects {
          enabled = true
        }
      }
    }
  }
}

resource "aws_s3_bucket" "backup_replica" {
  provider = aws.us-west-2
  bucket   = "company-backups-us-west-2"

  versioning {
    enabled = true
  }
}
```

**Anti-Pattern**: All backups in a single region or availability zone.

### Pattern 5: Backup Verification

**When to Use**: Ensuring backups are actually restorable

**Example**:
```bash
#!/bin/bash
# verify-backup.sh - Automated backup verification
set -euo pipefail

BACKUP_FILE="${1:?Backup file required}"
VERIFY_DB="verify_$(date +%s)"

echo "Creating verification database: ${VERIFY_DB}"
createdb "${VERIFY_DB}"

echo "Restoring backup..."
pg_restore \
  --dbname="${VERIFY_DB}" \
  --no-owner \
  --no-privileges \
  "${BACKUP_FILE}"

echo "Running verification queries..."
TABLES=$(psql -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'" "${VERIFY_DB}")
ROWS=$(psql -t -c "SELECT sum(n_live_tup) FROM pg_stat_user_tables" "${VERIFY_DB}")

echo "Tables: ${TABLES}, Total rows: ${ROWS}"

if [ "${TABLES}" -lt 1 ]; then
  echo "VERIFICATION FAILED: No tables found"
  dropdb "${VERIFY_DB}"
  exit 1
fi

echo "Cleanup verification database"
dropdb "${VERIFY_DB}"

echo "VERIFICATION PASSED"
```

**Anti-Pattern**: Never testing backup restoration until an actual disaster occurs.

## Backup Scheduling Matrix

| Data Type | Frequency | Retention | Verification |
|-----------|-----------|-----------|-------------|
| Database (transactional) | Continuous WAL + daily full | 30 days + monthly for 1 year | Weekly restore test |
| Configuration/secrets | On change + daily | 90 days | Monthly |
| Object storage | Cross-region replication | Per policy | Quarterly |
| Application logs | Continuous shipping | 90 days hot, 1 year cold | Monthly |

## Checklist

- [ ] Backup frequency matches RPO
- [ ] 3-2-1 rule followed
- [ ] Immutable backups for critical data
- [ ] Cross-region replication enabled
- [ ] Automated backup verification
- [ ] Retention policies defined
- [ ] Encryption at rest and in transit
- [ ] Backup monitoring and alerting
- [ ] Documented restore procedures
- [ ] Regular restore drills

## References

- [AWS Backup Best Practices](https://docs.aws.amazon.com/prescriptive-guidance/latest/backup-recovery/)
- [Velero Documentation](https://velero.io/docs/)
- [PostgreSQL Backup Guide](https://www.postgresql.org/docs/current/backup.html)
