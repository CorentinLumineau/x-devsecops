---
name: Canary Releases
description: Progressive canary deployment patterns with automated promotion
category: delivery/deployment-strategies
type: reference
license: Apache-2.0
---

# Canary Releases

## How It Works

Route a small percentage of production traffic to the new version, monitor, and gradually increase.

```
Step 1: 5% canary
  ┌────────────┐     95%    ┌─────────┐
  │   Router   │ ──────────►│  v1.2   │
  │            │     5%     ├─────────┤
  │            │ ──────────►│  v1.3   │ (canary)
  └────────────┘            └─────────┘

Step 2: 25% canary (if metrics OK)
Step 3: 50% canary (if metrics OK)
Step 4: 100% (promote)
```

## Kubernetes Canary with Istio

```yaml
# VirtualService for traffic splitting
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
    - myapp.example.com
  http:
    - route:
        - destination:
            host: myapp
            subset: stable
          weight: 95
        - destination:
            host: myapp
            subset: canary
          weight: 5

---
# DestinationRule defining subsets
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: myapp
spec:
  host: myapp
  subsets:
    - name: stable
      labels:
        version: v1.2
    - name: canary
      labels:
        version: v1.3
```

## Argo Rollouts Canary

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      steps:
        - setWeight: 5
        - pause: { duration: 10m }
        - setWeight: 25
        - pause: { duration: 10m }
        - setWeight: 50
        - pause: { duration: 10m }
        - setWeight: 100

      # Automatic analysis
      analysis:
        templates:
          - templateName: success-rate
        startingStep: 1
        args:
          - name: service-name
            value: myapp

      # Anti-affinity: canary and stable on different nodes
      canaryMetadata:
        labels:
          role: canary
      stableMetadata:
        labels:
          role: stable
```

### Analysis Template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 2m
      successCondition: result[0] >= 0.99
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",
              status!~"5.*", role="canary"}[5m]))
            /
            sum(rate(http_requests_total{service="{{args.service-name}}",
              role="canary"}[5m]))

    - name: latency-p99
      interval: 2m
      successCondition: result[0] < 0.3
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{
                service="{{args.service-name}}", role="canary"}[5m]))
              by (le))
```

## Canary Promotion Criteria

### Automated Checks

| Metric | Condition | Action on Fail |
|--------|-----------|----------------|
| Error rate | canary <= stable + 0.1% | Rollback |
| p99 latency | canary <= stable * 1.1 | Rollback |
| CPU usage | canary <= stable * 1.5 | Pause |
| Memory usage | canary <= stable * 1.2 | Pause |
| Business metric | conversion >= baseline * 0.95 | Rollback |

### Comparison Methods

```python
def should_promote(canary_metrics, stable_metrics):
    """Compare canary against stable baseline."""
    checks = {
        "error_rate": canary_metrics.error_rate <= stable_metrics.error_rate * 1.01,
        "latency_p99": canary_metrics.latency_p99 <= stable_metrics.latency_p99 * 1.10,
        "success_rate": canary_metrics.success_rate >= 0.999,
    }

    if all(checks.values()):
        return "promote"
    elif any(v is False for v in checks.values()):
        failed = [k for k, v in checks.items() if not v]
        return f"rollback: failed checks {failed}"
    return "wait"
```

## Traffic Routing Strategies

### Percentage-Based

Simple weight distribution. All users have equal chance of hitting canary.

### Header-Based

Route specific users to canary for testing:

```yaml
http:
  - match:
      - headers:
          x-canary:
            exact: "true"
    route:
      - destination:
          host: myapp
          subset: canary
  - route:
      - destination:
          host: myapp
          subset: stable
```

### User-Segment Based

Route internal users or beta testers first:

```python
def route_request(user):
    if user.is_internal:
        return "canary"
    if user.in_beta_program:
        return "canary"
    if hash(user.id) % 100 < canary_percentage:
        return "canary"
    return "stable"
```

## Observability Requirements

A canary deployment requires solid observability:

- Per-version metrics (label by version/role)
- Real-time dashboards comparing canary vs stable
- Automated anomaly detection
- Distributed tracing with version tagging
- Log aggregation filtered by version

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| No baseline comparison | Can't detect regression | Always compare to stable |
| Too fast promotion | Miss slow-burn issues | Minimum 10 min per step |
| Sticky sessions to canary | Biased metrics | Use random routing |
| No automated rollback | Human delay on failure | Automate with analysis |
| Insufficient canary traffic | Not statistically significant | Minimum 5% or 100 RPS |
