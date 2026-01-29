---
name: Error Budgets
description: Error budget policies, calculation, and operational decision-making
category: operations/sre-practices
type: reference
license: Apache-2.0
---

# Error Budgets

## What Is an Error Budget?

The error budget quantifies how much unreliability a service can tolerate:

```
Error Budget = 1 - SLO Target

Example: 99.9% SLO
  Error Budget = 0.1%
  In 30 days = 43.2 minutes of downtime allowed
  In requests = 1 failure per 1,000 requests
```

## Budget Calculation

### Time-Based

| SLO Target | Monthly Budget | Quarterly Budget | Annual Budget |
|-----------|----------------|------------------|---------------|
| 99.99% | 4.3 min | 13 min | 52.6 min |
| 99.95% | 21.6 min | 65 min | 4.38 hours |
| 99.9% | 43.2 min | 2.16 hours | 8.76 hours |
| 99.5% | 3.6 hours | 10.8 hours | 43.8 hours |
| 99.0% | 7.2 hours | 21.6 hours | 87.6 hours |

### Request-Based

```python
def calculate_error_budget(total_requests, slo_target):
    """Calculate allowed failed requests."""
    budget_fraction = 1 - slo_target
    allowed_failures = total_requests * budget_fraction
    return allowed_failures

# Example: 1M requests/day, 99.9% SLO
# Allowed failures = 1,000,000 * 0.001 = 1,000 per day
```

## Error Budget Policy

Define actions based on remaining budget:

### Tiered Policy

```yaml
error_budget_policy:
  service: payment-api
  window: 30d

  tiers:
    - name: green
      condition: "budget_remaining > 50%"
      actions:
        - "Normal development velocity"
        - "Standard change review process"
        - "Feature releases permitted"

    - name: yellow
      condition: "budget_remaining 20-50%"
      actions:
        - "Extra review for risky changes"
        - "No experimental features"
        - "Increase monitoring coverage"
        - "Review recent incidents"

    - name: red
      condition: "budget_remaining < 20%"
      actions:
        - "Feature freeze except reliability work"
        - "All changes require SRE approval"
        - "Daily error budget review"
        - "Prioritize reliability improvements"

    - name: exhausted
      condition: "budget_remaining <= 0%"
      actions:
        - "Full deployment freeze"
        - "All engineering on reliability"
        - "Incident review for budget consumers"
        - "Escalate to leadership"
```

## Burn Rate Alerting

Burn rate measures how fast the error budget is being consumed relative to the SLO window.

```
Burn Rate = (Error Rate) / (Error Budget Rate)

Where Error Budget Rate = (1 - SLO) / Window
```

### Multi-Window Alerting Strategy

| Burn Rate | Short Window | Long Window | Action | Budget Consumed |
|-----------|-------------|-------------|--------|-----------------|
| 14.4x | 1h | 5m | Page | 100% in 2.5 days |
| 6x | 6h | 30m | Page | 100% in 5 days |
| 3x | 1d | 2h | Ticket | 100% in 10 days |
| 1x | 3d | 6h | Ticket | Normal consumption |

### Why Multi-Window?

Single-window alerts produce false positives. Multi-window (long for significance, short for recency) ensures:
- Long window: enough data to avoid noise
- Short window: problem is still happening now

```python
def should_alert(error_rate, slo_target, window_seconds, threshold):
    """Check if burn rate exceeds threshold."""
    budget_rate = (1 - slo_target)
    burn_rate = error_rate / budget_rate
    return burn_rate > threshold
```

## Budget Attribution

Track which changes consumed the error budget:

```yaml
budget_consumption_log:
  - date: "2024-01-15"
    incident: "INC-1234"
    duration_minutes: 12
    budget_consumed_percent: 28
    cause: "Database migration timeout"
    team: "platform"

  - date: "2024-01-22"
    incident: "INC-1238"
    duration_minutes: 5
    budget_consumed_percent: 12
    cause: "Bad config rollout"
    team: "backend"
```

## Error Budget and Feature Velocity

The error budget creates a balance:

```
High Reliability          Low Reliability
(budget available)        (budget exhausted)
     |                         |
     v                         v
Ship features faster     Focus on reliability
     |                         |
     v                         v
More risk of errors      Fewer errors, slower
     |                         |
     v                         v
Budget decreases         Budget recovers
```

This feedback loop self-corrects: teams that ship too fast burn budget and must slow down; teams that are too cautious accumulate unused budget.

## Common Pitfalls

| Pitfall | Impact | Mitigation |
|---------|--------|------------|
| No enforcement | SLO becomes aspirational | Automate deployment gates |
| Shared budgets | One team burns another's budget | Per-team attribution |
| Gaming metrics | Hiding real failures | Measure at user edge |
| Ignoring partial failures | Degraded experience untracked | Include latency SLOs |
| No escalation path | Budget exhaustion ignored | Policy with leadership escalation |
