# Incident Response Templates

Templates, checklists, and detailed operational guidance for incident management, monitoring, and disaster recovery.

---

## Runbook Template

```markdown
# Runbook: [Service/Scenario]

## Symptoms
- What alerts fire
- What users report

## Diagnosis
1. Check [metrics dashboard]
2. Review [logs location]
3. Verify [dependent services]

## Mitigation
1. [Immediate action]
2. [Rollback steps if applicable]

## Resolution
1. [Root cause fix steps]
2. [Verification steps]

## Contacts
- Primary: [name/channel]
- Escalation: [name/channel]
```

---

## Communication Templates

### Initial Notification

```
INCIDENT: [Brief description]
SEVERITY: P[1-4]
IMPACT: [What's affected]
STATUS: Investigating
UPDATES: [channel] every [interval]
```

### Resolution Notification

```
RESOLVED: [Brief description]
DURATION: [start] - [end]
ROOT CAUSE: [brief]
FOLLOW-UP: Post-mortem scheduled [date]
```

---

## Post-Mortem Structure

| Section | Content |
|---------|---------|
| Summary | What happened |
| Timeline | Chronological events |
| Root Cause | Why it happened (use 5-whys) |
| Impact | Users/services/revenue affected |
| What Went Well | Positive aspects |
| What Went Wrong | Areas to improve |
| Action Items | Specific improvements with owners |

**Blameless principles**:
- Focus on systems, not people
- Document within 48 hours
- Share widely across the organization
- Track action item completion

---

## Monitoring Detail

### Structured Logging

```json
{
  "timestamp": "2026-01-23T10:30:00Z",
  "level": "error",
  "service": "api",
  "traceId": "abc123",
  "message": "Database connection failed",
  "error": "connection timeout"
}
```

### Dashboard Essentials

| Dashboard | Metrics |
|-----------|---------|
| Service health | Error rate, latency, traffic (RED method) |
| Infrastructure | CPU, memory, disk, network (USE method) |
| SLO tracking | Budget remaining, burn rate, compliance |
| Business | Conversions, active users |
| Dependencies | External service health |

### On-Call Best Practices

- Maximum 25% of time on-call per engineer
- Handoff documentation between rotations
- Escalation path defined and tested
- Compensation or time-off for pages
- Alert quality reviews: every page should be actionable

---

## Disaster Recovery Detail

### Recovery Tiers

| Tier | Strategy | RTO | RPO | Cost |
|------|----------|-----|-----|------|
| 1 | Active-active multi-region | < 1 min | ~0 | Very high |
| 2 | Hot standby + replication | < 15 min | < 1 min | High |
| 3 | Warm standby + snapshots | < 1 hr | < 15 min | Medium |
| 4 | Cold backup + restore | < 24 hr | < 1 hr | Low |
| 5 | Backup only | Days | Hours-days | Minimal |

### DR Testing Cadence

| Test Type | Frequency | Scope |
|-----------|-----------|-------|
| Tabletop exercise | Quarterly | Walk through runbook |
| Component failover | Monthly | Single component |
| Full DR drill | Annually | Complete failover |
| Chaos engineering | Continuous | Random fault injection |

### Cloud DR Patterns

| Pattern | AWS | GCP | Azure |
|---------|-----|-----|-------|
| Cross-region replication | S3 CRR, RDS read replicas | Cloud Storage dual-region | GRS, geo-replication |
| Automated failover | Route 53 health checks | Cloud DNS | Traffic Manager |
| IaC recovery | CloudFormation StackSets | Deployment Manager | ARM templates |
| Database backup | RDS automated snapshots | Cloud SQL backups | Azure SQL geo-restore |

---

## Operational Checklists

### SRE Practices
- [ ] SLOs defined and tracked for all critical services
- [ ] Error budget policies documented and enforced
- [ ] Toil tracked and kept below 50%
- [ ] On-call rotation established with handoff procedures

### Incident Response
- [ ] Incident severity levels defined
- [ ] Stakeholder notification process established
- [ ] Response roles assigned
- [ ] Communication channel templates ready
- [ ] Timeline documented during incidents
- [ ] Post-mortem scheduled within 48 hours
- [ ] Action items tracked to completion

### Monitoring
- [ ] Golden signals monitored for all services
- [ ] Alerts are actionable with runbook links
- [ ] Logs are structured (JSON)
- [ ] Traces enabled for request flows
- [ ] Dashboards accessible to the team
- [ ] SLO-based burn rate alerting configured

### Disaster Recovery
- [ ] RTO/RPO defined per service
- [ ] Backup strategy follows 3-2-1 rule
- [ ] Failover procedures automated
- [ ] DR runbooks created and accessible
- [ ] DR tests scheduled and executed regularly
- [ ] Recovery procedures validated
- [ ] Dependencies mapped
