---
name: sre-operations
description: Site Reliability Engineering operations covering SRE principles, incident response, monitoring, observability, and disaster recovery.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "2.0.0"
  category: operations
---

# SRE Operations

Comprehensive SRE operations knowledge covering reliability engineering principles, incident management, monitoring and observability, and disaster recovery.

## Quick Reference (80/20)

| Area | Key Concepts | Impact |
|------|-------------|--------|
| SLO-based alerting | Alert on error budget burn rate, not raw metrics | Eliminates noise, focuses on user impact |
| Golden signals | Latency, traffic, errors, saturation | Covers 80% of monitoring needs |
| Blameless postmortems | Focus on systems, not people; track action items | Prevents recurrence, builds knowledge |
| Toil reduction | Automate repetitive work; keep toil < 50% | Frees engineering time for reliability |
| RTO/RPO planning | Define recovery targets per service tier | Right-sized DR investment |
| 3-2-1 backup rule | 3 copies, 2 media, 1 offsite | Data protection baseline |

## SRE Principles

### SLOs, SLIs, and SLAs

| Concept | Definition | Owner |
|---------|-----------|-------|
| **SLA** | Contractual commitment with consequences | Business |
| **SLO** | Internal reliability target (stricter than SLA) | Engineering |
| **SLI** | Measured metric that feeds the SLO | Monitoring |

**Setting Effective SLOs**:

```yaml
service: payment-api
slos:
  - name: availability
    sli: successful_requests / total_requests
    target: 99.95%
    window: 30d
  - name: latency
    sli: requests_under_300ms / total_requests
    target: 99.0%
    window: 30d
```

**Rules of thumb**:
- Start with 99.9% availability (allows ~43 min/month downtime)
- Set SLO stricter than SLA by at least 0.05%
- Use rolling windows (30d) not calendar months
- Measure from the user perspective

### Error Budgets

The error budget is `1 - SLO target`. For a 99.9% SLO, the error budget is 0.1%.

**Budget policies**:
- Budget remaining > 50%: ship features freely
- Budget remaining 20-50%: require extra review for risky changes
- Budget exhausted: freeze deployments, focus on reliability

**Burn rate alerts**:
- 14.4x burn rate over 1h = page (budget gone in ~1 day)
- 6x burn rate over 6h = page (budget gone in ~5 days)
- 1x burn rate over 3d = ticket (on track to exhaust)

### Toil Reduction

Toil is manual, repetitive, automatable work that scales linearly with service growth.

**Identification checklist**:
- Manual (human performs it)
- Repetitive (done more than twice)
- Automatable (could be scripted)
- Reactive (triggered by events, not planned)
- No lasting value (doesn't improve the system)

**Reduction strategies**:
1. Automate the most frequent toil first (Pareto)
2. Build self-healing systems (auto-restart, auto-scale)
3. Improve deployment pipelines to reduce rollback toil
4. Create runbooks, then automate runbook steps

## Incident Response

### Severity Levels

| Level | Description | Response Time | Resolution SLA |
|-------|-------------|---------------|----------------|
| P1 | Critical - Service down | 5 minutes | 4 hours |
| P2 | Major - Degraded service | 15 minutes | 8 hours |
| P3 | Minor - Limited impact | 1 hour | 24 hours |
| P4 | Low - No immediate impact | 4 hours | 72 hours |

### Incident Lifecycle

```
Detect -> Triage -> Mitigate -> Resolve -> Review
```

| Phase | Activities |
|-------|------------|
| Detect | Alerts, user reports, monitoring |
| Triage | Assess severity, assign owner |
| Mitigate | Stop bleeding, temporary fixes |
| Resolve | Root cause fix, full recovery |
| Review | Post-mortem, improvements |

### Response Roles

| Role | Responsibility |
|------|----------------|
| Incident Commander | Coordinates response |
| Technical Lead | Directs technical work |
| Communications | Updates stakeholders |
| Scribe | Documents timeline |

### Runbook Template

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

### Communication Templates

**Initial**:
```
INCIDENT: [Brief description]
SEVERITY: P[1-4]
IMPACT: [What's affected]
STATUS: Investigating
UPDATES: [channel] every [interval]
```

**Resolution**:
```
RESOLVED: [Brief description]
DURATION: [start] - [end]
ROOT CAUSE: [brief]
FOLLOW-UP: Post-mortem scheduled [date]
```

### Post-Mortem Structure

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

## Monitoring and Observability

### Three Pillars

| Pillar | Purpose | Tools |
|--------|---------|-------|
| Metrics | Numerical measurements | Prometheus, Datadog |
| Logs | Event records | ELK, Loki |
| Traces | Request flows | Jaeger, Zipkin |

### Golden Signals

| Signal | Question | Metric Example |
|--------|----------|----------------|
| Latency | How long? | p50, p95, p99 response time |
| Traffic | How much? | Requests per second |
| Errors | How many fail? | Error rate percentage |
| Saturation | How full? | CPU, memory, queue depth |

### Alerting Strategy

| Alert Type | When | Action |
|------------|------|--------|
| Page | Service degraded | Immediate response |
| Notify | Needs attention | Review during hours |
| Log | Informational | No action required |

**Alert best practices**:
- Alert on symptoms (user impact), not causes
- Include runbook link in every alert
- Every alert must be actionable
- Avoid noisy alerts that cause alert fatigue
- Use multi-window burn rate alerting for SLOs

### Logging Levels

| Level | Use For |
|-------|---------|
| ERROR | Failures requiring attention |
| WARN | Issues that may need attention |
| INFO | Normal operations |
| DEBUG | Detailed troubleshooting |

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

## Disaster Recovery

### RTO/RPO Definitions

| Concept | Definition | Key Question |
|---------|-----------|--------------|
| RTO | Recovery Time Objective | How long until service restored? |
| RPO | Recovery Point Objective | How much data loss is acceptable? |

### Recovery Tiers

| Tier | Strategy | RTO | RPO | Cost |
|------|----------|-----|-----|------|
| 1 | Active-active multi-region | < 1 min | ~0 | Very high |
| 2 | Hot standby + replication | < 15 min | < 1 min | High |
| 3 | Warm standby + snapshots | < 1 hr | < 15 min | Medium |
| 4 | Cold backup + restore | < 24 hr | < 1 hr | Low |
| 5 | Backup only | Days | Hours-days | Minimal |

### Backup Rule of 3-2-1

```
3 copies of data
2 different storage media
1 offsite copy
```

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

## Checklist

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

## When to Load References

### Incident Response
- **For escalation paths and matrices**: See `references/escalation.md`
- **For post-mortem templates and blameless culture**: See `references/post-mortem.md`
- **For runbook templates and automation**: See `references/runbook-templates.md`

### Monitoring
- **For Prometheus setup and PromQL**: See `references/prometheus.md`
- **For alerting rules and routing**: See `references/alerting.md`
- **For dashboard patterns (RED, USE, SLO)**: See `references/dashboards.md`

### SRE Practices
- **For SLO framework and implementation**: See `references/slo-framework.md`
- **For error budget policies and burn rates**: See `references/error-budgets.md`
- **For toil reduction patterns**: See `references/toil-reduction.md`

### Disaster Recovery
- **For backup strategies and verification**: See `references/backup-strategies.md`
- **For failover patterns and circuit breakers**: See `references/failover-patterns.md`

## Related Skills

- See `@skills/quality-observability` for OpenTelemetry and distributed tracing
- See `@skills/quality-testing` for testing practices
- See `@skills/delivery-cicd` for CI/CD and deployment strategies
- See `@skills/security-owasp` for security incident context
