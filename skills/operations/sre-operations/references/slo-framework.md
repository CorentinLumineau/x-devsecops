---
name: SLO Framework
description: Comprehensive guide to defining and implementing Service Level Objectives
category: operations/sre-practices
type: reference
license: Apache-2.0
---

# SLO Framework

## Choosing SLIs

Select SLIs that reflect the user experience:

| Service Type | Primary SLI | Secondary SLI |
|-------------|-------------|---------------|
| Request-driven (API) | Availability, latency | Throughput, error rate |
| Pipeline (batch) | Freshness, correctness | Throughput |
| Storage | Durability, availability | Latency |

## SLI Measurement Points

```
User -> [Load Balancer] -> [App Server] -> [Database]
         ^                  ^               ^
         Best (closest      Good            Worst (misses
         to user)                           network issues)
```

Always measure as close to the user as possible. Load balancer logs or synthetic probes are preferred over application-level metrics.

## SLO Definition Template

```yaml
service: user-auth-service
team: platform
slos:
  - name: availability
    description: "Proportion of successful authentication requests"
    sli:
      type: request-based
      good_events: "HTTP status < 500"
      total_events: "All HTTP requests excluding health checks"
    target: 99.95%
    window:
      type: rolling
      duration: 30d
    alerting:
      burn_rate_short: { rate: 14.4, window: 1h, severity: page }
      burn_rate_medium: { rate: 6.0, window: 6h, severity: page }
      burn_rate_long: { rate: 1.0, window: 3d, severity: ticket }

  - name: latency
    description: "Proportion of requests served within 200ms"
    sli:
      type: request-based
      good_events: "Response time < 200ms"
      total_events: "All HTTP requests"
    target: 99.0%
    window:
      type: rolling
      duration: 30d
```

## SLO Review Process

### Weekly Review

- Check error budget remaining
- Review any budget-consuming incidents
- Adjust deployment velocity if budget is low

### Quarterly Review

- Validate SLO targets still match user expectations
- Adjust targets based on actual performance data
- Review whether SLIs still represent user experience
- Retire or add SLOs as services evolve

## Common SLO Targets by Tier

| Tier | Availability | Latency (p99) | Use Case |
|------|-------------|----------------|----------|
| Critical | 99.99% | < 100ms | Payment, auth |
| Standard | 99.9% | < 300ms | Core features |
| Best-effort | 99.5% | < 1s | Internal tools |

## SLO Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| 100% target | No room for change | Use 99.9% or lower |
| Too many SLOs | Alert fatigue | 2-4 per service max |
| Internal-only SLI | Misses real failures | Measure at user edge |
| Calendar windows | Resets incentives monthly | Use rolling windows |
| No error budget policy | SLO is ignored | Define budget actions |

## Implementing SLOs with Prometheus

```yaml
# Recording rule for availability SLI
groups:
  - name: slo-availability
    rules:
      - record: sli:availability:ratio_rate30d
        expr: |
          sum(rate(http_requests_total{code!~"5.."}[30d]))
          /
          sum(rate(http_requests_total[30d]))

      - record: slo:availability:error_budget_remaining
        expr: |
          1 - (
            (1 - sli:availability:ratio_rate30d)
            /
            (1 - 0.999)
          )
```

```yaml
# Alert on burn rate
groups:
  - name: slo-alerts
    rules:
      - alert: HighErrorBurnRate
        expr: |
          (
            sum(rate(http_requests_total{code=~"5.."}[1h]))
            /
            sum(rate(http_requests_total[1h]))
          ) > (14.4 * 0.001)
        for: 2m
        labels:
          severity: page
        annotations:
          summary: "Error budget burning at 14.4x normal rate"
```

## Communicating SLOs

- Publish SLO dashboards visible to all teams
- Include error budget in sprint planning
- Report SLO performance in service reviews
- Use error budget as input for prioritization decisions
