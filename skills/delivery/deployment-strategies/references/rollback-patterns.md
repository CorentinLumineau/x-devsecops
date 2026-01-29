---
name: Rollback Patterns
description: Safe rollback strategies and backward-compatible change patterns
category: delivery/deployment-strategies
type: reference
license: Apache-2.0
---

# Rollback Patterns

## Rollback Decision Framework

```
Incident detected
  │
  ├─ Is it a config issue?
  │   └─ Revert config (fastest, seconds)
  │
  ├─ Is it a feature flag issue?
  │   └─ Toggle flag off (seconds)
  │
  ├─ Is it application code?
  │   ├─ Blue/green? → Switch back (seconds)
  │   ├─ Canary? → Route 0% to canary (seconds)
  │   └─ Rolling? → Redeploy previous version (minutes)
  │
  └─ Is it a database migration?
      └─ Apply reverse migration (minutes to hours)
```

## Rollback Speed by Strategy

| Method | Speed | Complexity | Data Risk |
|--------|-------|-----------|-----------|
| Feature flag toggle | Instant | None | None |
| Config revert | Seconds | Low | None |
| Blue/green switch | Seconds | Low | DB compatibility |
| Canary route to 0% | Seconds | Low | None |
| Container image revert | 1-5 min | Medium | DB compatibility |
| Rolling redeploy | 5-15 min | Medium | Mixed versions |
| Database rollback | 15-60 min | High | Data loss risk |

## Feature Flag Rollback

The fastest and safest rollback mechanism:

```python
# Application code with feature flag
def process_order(order):
    if feature_flags.is_enabled("new-payment-flow", user=order.user):
        return new_payment_flow(order)
    else:
        return legacy_payment_flow(order)

# Rollback: disable flag (instant, no deploy)
# feature_flags.disable("new-payment-flow")
```

### Kill Switch Pattern

```python
class KillSwitch:
    """Emergency circuit breaker for features."""

    def __init__(self, name, default=True):
        self.name = name
        self.default = default

    def is_active(self):
        """Check if feature should be active. Fails closed."""
        try:
            return config_store.get(f"killswitch:{self.name}", self.default)
        except Exception:
            return False  # Fail closed: disable on error

# Usage
payment_switch = KillSwitch("new-payment-flow")
if payment_switch.is_active():
    process_new_way()
else:
    process_old_way()
```

## Container Image Rollback

### Kubernetes

```bash
# Rollback to previous revision
kubectl rollout undo deployment/myapp

# Rollback to specific revision
kubectl rollout undo deployment/myapp --to-revision=3

# Check rollout history
kubectl rollout history deployment/myapp
```

### Docker Compose

```bash
# Tag previous version and redeploy
docker compose pull
docker compose up -d --no-deps myapp
```

## Database Rollback Strategies

### Forward-Only Migrations (Recommended)

Never roll back database changes. Instead, deploy forward with a fix:

```sql
-- v1: Original schema
CREATE TABLE users (name VARCHAR(255));

-- v2: Add column (expand)
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- v3 (if v2 code has bug): Fix forward
-- Deploy fixed code, don't touch schema
```

### Reversible Migrations (When Needed)

```python
# Migration with explicit rollback
class Migration:
    def up(self):
        """Apply change."""
        db.execute("ALTER TABLE orders ADD COLUMN discount DECIMAL(10,2)")

    def down(self):
        """Reverse change."""
        db.execute("ALTER TABLE orders DROP COLUMN discount")
```

**Rules for reversible migrations**:
- Never auto-run `down()` in production
- Require manual approval for schema rollbacks
- Test rollback in staging first
- Only if no data has been written to new columns

### Expand-Contract Pattern

```
Deploy 1: Expand (add new, keep old)
  ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
  -- App writes to both old and new columns

Deploy 2: Migrate data
  UPDATE users SET full_name = first_name || ' ' || last_name
    WHERE full_name IS NULL;

Deploy 3: Switch reads
  -- App reads from new column

Deploy 4: Contract (remove old)
  ALTER TABLE users DROP COLUMN first_name;
  ALTER TABLE users DROP COLUMN last_name;
```

Rollback is safe at any point before Deploy 4.

## API Rollback

### Version Compatibility

```
v1 API (current)  ←→  v1 Database schema
v2 API (new)      ←→  v2 Database schema (backward-compatible)

Rollback: v2 → v1
  - v1 code must still work with v2 schema
  - This is why expand-contract matters
```

### API Versioning for Safe Rollback

```python
# Keep old endpoint working alongside new
@app.route("/api/v1/orders", methods=["GET"])
def get_orders_v1():
    return legacy_format(Order.query.all())

@app.route("/api/v2/orders", methods=["GET"])
def get_orders_v2():
    return new_format(Order.query.all())

# Rollback: clients switch back to v1 endpoint
```

## Rollback Runbook Template

```yaml
rollback_runbook:
  trigger: "Error rate > 5% for 5 minutes after deployment"

  steps:
    - name: "Assess impact"
      action: "Check error rate, affected users, business impact"
      duration: "2 min"

    - name: "Decide rollback method"
      action: "Feature flag > config > blue/green > redeploy"
      duration: "1 min"

    - name: "Execute rollback"
      action: "Run rollback command for chosen method"
      duration: "Varies (see speed table)"

    - name: "Verify recovery"
      action: "Confirm error rate returned to baseline"
      duration: "5 min"

    - name: "Communicate"
      action: "Notify stakeholders, update status page"
      duration: "5 min"

    - name: "Post-incident"
      action: "Schedule postmortem, create follow-up tickets"
      duration: "After recovery"
```

## Automated Rollback

```yaml
# Argo Rollouts automatic rollback
spec:
  strategy:
    canary:
      analysis:
        templates:
          - templateName: error-rate-check
        args:
          - name: threshold
            value: "0.01"
      # Automatically rollback on analysis failure
      abortScaleDownDelaySeconds: 30
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| Destructive migration before rollback window | Can't rollback | Wait 48h before contract phase |
| No previous artifacts retained | Nothing to rollback to | Keep N-2 versions in registry |
| Untested rollback path | Fails when needed | Test rollback in staging monthly |
| Cache invalidation missed | Stale data after rollback | Include cache clear in rollback |
| Async jobs still running old code | Mixed processing | Drain queues before switching |
