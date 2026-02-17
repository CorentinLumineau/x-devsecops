---
name: sre-operations
description: Site Reliability Engineering operations covering SRE principles, incident response, monitoring, observability, and disaster recovery.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
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

### Response Roles

| Role | Responsibility |
|------|----------------|
| Incident Commander | Coordinates response |
| Technical Lead | Directs technical work |
| Communications | Updates stakeholders |
| Scribe | Documents timeline |

For runbook templates, communication templates, and post-mortem structure, see `references/incident-templates.md`.

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

**Alert best practices**: Alert on symptoms (user impact), include runbook links, every alert must be actionable, use multi-window burn rate alerting for SLOs.

### Logging Levels

| Level | Use For |
|-------|---------|
| ERROR | Failures requiring attention |
| WARN | Issues that may need attention |
| INFO | Normal operations |
| DEBUG | Detailed troubleshooting |

For dashboards, structured logging examples, and on-call practices, see `references/incident-templates.md`.

## Disaster Recovery

### RTO/RPO Definitions

| Concept | Definition | Key Question |
|---------|-----------|--------------|
| RTO | Recovery Time Objective | How long until service restored? |
| RPO | Recovery Point Objective | How much data loss is acceptable? |

### Backup Rule of 3-2-1

```
3 copies of data
2 different storage media
1 offsite copy
```

For recovery tiers, DR testing cadence, cloud DR patterns, and full checklists, see `references/incident-templates.md`.

## When to Load References

### Incident Response
- **For escalation paths and matrices**: See `references/escalation.md`
- **For post-mortem templates and blameless culture**: See `references/post-mortem.md`
- **For runbook templates and automation**: See `references/runbook-templates.md`
- **For operational templates and checklists**: See `references/incident-templates.md`

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
- See `@skills/delivery-ci-cd-delivery` for CI/CD and deployment strategies
- See `@skills/security-secure-coding` for security incident context
