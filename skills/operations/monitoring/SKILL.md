---
name: monitoring
description: Observability patterns. Metrics, logging, tracing, alerting, SLOs.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: operations
---

# Monitoring

Observability and monitoring best practices.

## Three Pillars

| Pillar | Purpose | Tools |
|--------|---------|-------|
| Metrics | Numerical measurements | Prometheus, Datadog |
| Logs | Event records | ELK, Loki |
| Traces | Request flows | Jaeger, Zipkin |

## Golden Signals

| Signal | Question | Metric Example |
|--------|----------|----------------|
| Latency | How long? | p50, p95, p99 response time |
| Traffic | How much? | Requests per second |
| Errors | How many fail? | Error rate percentage |
| Saturation | How full? | CPU, memory, queue depth |

## SLO/SLI/SLA

| Term | Definition | Example |
|------|------------|---------|
| SLI | Service Level Indicator | p99 latency = 200ms |
| SLO | Service Level Objective | 99.9% requests < 200ms |
| SLA | Service Level Agreement | Contractual SLO with penalties |

## Alerting Strategy

| Alert Type | When | Action |
|------------|------|--------|
| Page | Service degraded | Immediate response |
| Notify | Needs attention | Review during hours |
| Log | Informational | No action required |

### Alert Best Practices
```
✅ Alert on symptoms (user impact)
✅ Include runbook link
✅ Actionable (can I fix it now?)
❌ Alert on causes (underlying metrics)
❌ Noisy alerts (alert fatigue)
```

## Logging Levels

| Level | Use For |
|-------|---------|
| ERROR | Failures requiring attention |
| WARN | Issues that may need attention |
| INFO | Normal operations |
| DEBUG | Detailed troubleshooting |

## Structured Logging

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

## Dashboard Essentials

| Dashboard | Metrics |
|-----------|---------|
| Service health | Error rate, latency, traffic |
| Infrastructure | CPU, memory, disk, network |
| Business | Conversions, active users |
| Dependencies | External service health |

## Checklist

- [ ] Golden signals monitored
- [ ] SLOs defined and tracked
- [ ] Alerts are actionable
- [ ] Runbooks linked to alerts
- [ ] Logs are structured
- [ ] Traces enabled for requests
- [ ] Dashboards accessible
- [ ] On-call rotation established

## When to Load References

- **For Prometheus setup**: See `references/prometheus.md`
- **For alerting rules**: See `references/alerting.md`
- **For dashboard patterns**: See `references/dashboards.md`
