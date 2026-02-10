---
name: deployment-strategies
description: Deployment strategies for safe, zero-downtime releases.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---

# Deployment Strategies

Safe release strategies for zero-downtime deployments.

## Quick Reference (80/20)

Choose the right strategy (80% of deployment success):

| Strategy | Risk | Complexity | Best For |
|----------|------|------------|----------|
| Rolling update | Low | Low | Stateless services |
| Blue/Green | Low | Medium | Critical services, fast rollback |
| Canary | Very low | High | High-traffic, risk-averse |
| A/B Testing | Low | High | Feature validation with data |

## Strategy Comparison

| Feature | Rolling | Blue/Green | Canary |
|---------|---------|-----------|--------|
| Zero downtime | Yes | Yes | Yes |
| Rollback speed | Slow (re-roll) | Instant (swap) | Fast (route 0%) |
| Resource cost | 1x | 2x | 1x + canary |
| Mixed versions | During rollout | Never | During rollout |
| Database changes | Complex | Complex | Complex |
| Smoke testing | Limited | Full env | Partial traffic |

## Rolling Update

Replace instances incrementally:

```yaml
# Kubernetes rolling update
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1         # 1 extra pod during update
      maxUnavailable: 0    # Never reduce below desired count
```

**Flow**: v1,v1,v1,v1 -> v2,v1,v1,v1 -> v2,v2,v1,v1 -> v2,v2,v2,v1 -> v2,v2,v2,v2

**When to use**: Stateless services, non-breaking changes
**When to avoid**: Breaking API changes, database schema changes

## Blue/Green Deployment

Two identical environments; switch traffic at once:

```
         ┌─── Blue (v1) ← Active
Router ──┤
         └─── Green (v2) ← Staging

After verification:

         ┌─── Blue (v1) ← Idle
Router ──┤
         └─── Green (v2) ← Active
```

**Steps**:
1. Deploy v2 to inactive environment
2. Run full test suite against v2
3. Switch router/load balancer to v2
4. Monitor for errors
5. Keep v1 as instant rollback

## Canary Release

Route small traffic percentage to new version, gradually increase:

```
Step 1:  v1 (95%) ← Users    v2 (5%) ← Canary
Step 2:  v1 (75%)            v2 (25%)
Step 3:  v1 (50%)            v2 (50%)
Step 4:  v1 (0%)             v2 (100%)
```

**Promotion criteria**:
- Error rate <= baseline + 0.1%
- p99 latency <= baseline + 10%
- No increase in 5xx responses
- Business metrics stable

## Rollback Strategy

| Strategy | Rollback Method | Speed |
|----------|----------------|-------|
| Rolling | Re-deploy previous version | Minutes |
| Blue/Green | Switch router back | Seconds |
| Canary | Route 0% to canary | Seconds |
| Feature flag | Toggle flag off | Instant |

**Rollback checklist**:
- [ ] Database migrations are backward-compatible
- [ ] API changes are backward-compatible
- [ ] Feature flags can disable new code paths
- [ ] Previous version artifacts are retained
- [ ] Monitoring alerts detect regression

## Database Migration Safety

All deployment strategies require backward-compatible database changes:

```
Deploy v2 (adds column) → Both v1 and v2 work
Migrate traffic to v2   → Confirm v2 stable
Remove v1 code          → Clean up old column later
```

**Rule**: Expand-then-contract. Never remove or rename in the same deploy.

## When to Load References

- **For blue/green details**: See `references/blue-green.md`
- **For canary patterns**: See `references/canary-releases.md`
- **For rollback patterns**: See `references/rollback-patterns.md`

## Cross-References

- **CI/CD pipelines**: See `delivery/ci-cd` skill
- **Feature flags**: See `delivery/feature-flags` skill
- **Infrastructure**: See `delivery/infrastructure` skill
