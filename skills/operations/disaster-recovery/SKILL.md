---
name: disaster-recovery
description: RTO/RPO planning, backup strategies, failover patterns, and DR testing.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: operations
---

# Disaster Recovery

Strategies for business continuity and data protection.

## Quick Reference (80/20)

| Concept | Definition | Typical Target |
|---------|-----------|----------------|
| RTO | Recovery Time Objective | How long until service restored |
| RPO | Recovery Point Objective | How much data loss acceptable |
| Hot standby | Always running replica | RTO: minutes, RPO: seconds |
| Warm standby | Scaled-down replica | RTO: minutes-hours, RPO: minutes |
| Cold standby | Offline backup | RTO: hours-days, RPO: hours |

## Recovery Tiers

| Tier | Strategy | RTO | RPO | Cost |
|------|----------|-----|-----|------|
| 1 | Active-active multi-region | < 1 min | ~0 | Very high |
| 2 | Hot standby + replication | < 15 min | < 1 min | High |
| 3 | Warm standby + snapshots | < 1 hr | < 15 min | Medium |
| 4 | Cold backup + restore | < 24 hr | < 1 hr | Low |
| 5 | Backup only | Days | Hours-days | Minimal |

## Backup Rule of 3-2-1

```
3 copies of data
2 different storage media
1 offsite copy
```

## DR Testing Cadence

| Test Type | Frequency | Scope |
|-----------|-----------|-------|
| Tabletop exercise | Quarterly | Walk through runbook |
| Component failover | Monthly | Single component |
| Full DR drill | Annually | Complete failover |
| Chaos engineering | Continuous | Random fault injection |

## Cloud DR Patterns

| Pattern | AWS | GCP | Azure |
|---------|-----|-----|-------|
| Cross-region replication | S3 CRR, RDS read replicas | Cloud Storage dual-region | GRS, geo-replication |
| Automated failover | Route 53 health checks | Cloud DNS | Traffic Manager |
| IaC recovery | CloudFormation StackSets | Deployment Manager | ARM templates |
| Database backup | RDS automated snapshots | Cloud SQL backups | Azure SQL geo-restore |

## Checklist

- [ ] RTO/RPO defined per service
- [ ] Backup strategy documented
- [ ] Failover procedures automated
- [ ] DR runbooks created and accessible
- [ ] DR tests scheduled and executed
- [ ] Recovery procedures validated
- [ ] Communication plan established
- [ ] Dependencies mapped

## When to Load References

- **For backup strategies**: See `references/backup-strategies.md`
- **For failover patterns**: See `references/failover-patterns.md`
