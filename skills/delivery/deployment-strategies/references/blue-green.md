---
name: Blue/Green Deployments
description: Blue/green deployment patterns with infrastructure examples
category: delivery/deployment-strategies
type: reference
license: Apache-2.0
---

# Blue/Green Deployments

## How It Works

Maintain two identical production environments. Only one serves live traffic at any time.

```
                    ┌──────────────────┐
                    │   Load Balancer   │
                    │  (traffic switch) │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐  ┌────▼──────┐
        │   Blue     │  │   Green    │
        │   (v1.2)   │  │   (v1.3)   │
        │   ACTIVE   │  │   STAGING  │
        └───────────┘  └───────────┘
              │              │
              └──────┬───────┘
                     │
              ┌──────▼──────┐
              │  Shared DB   │
              │  (careful!)  │
              └─────────────┘
```

## Implementation Approaches

### DNS-Based Switch

```bash
# Switch traffic by updating DNS
# Pros: Simple
# Cons: DNS TTL delays (propagation can take minutes)

# Using AWS Route 53
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234 \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "CNAME",
        "TTL": 60,
        "ResourceRecords": [{"Value": "green-env.example.com"}]
      }
    }]
  }'
```

### Load Balancer Switch

```yaml
# Kubernetes Service switch (instant)
apiVersion: v1
kind: Service
metadata:
  name: production
spec:
  selector:
    app: myapp
    version: green    # Switch from "blue" to "green"
  ports:
    - port: 80
      targetPort: 8080
```

### AWS ALB Target Group Switch

```python
import boto3

elbv2 = boto3.client('elbv2')

def switch_to_green(listener_arn, green_target_group_arn):
    elbv2.modify_listener(
        ListenerArn=listener_arn,
        DefaultActions=[{
            'Type': 'forward',
            'TargetGroupArn': green_target_group_arn
        }]
    )

def rollback_to_blue(listener_arn, blue_target_group_arn):
    elbv2.modify_listener(
        ListenerArn=listener_arn,
        DefaultActions=[{
            'Type': 'forward',
            'TargetGroupArn': blue_target_group_arn
        }]
    )
```

## Deployment Pipeline

```yaml
# GitHub Actions blue/green pipeline
name: Blue/Green Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    steps:
      - name: Determine inactive environment
        run: |
          ACTIVE=$(aws ssm get-parameter --name /deploy/active-env --query Parameter.Value --output text)
          if [ "$ACTIVE" = "blue" ]; then
            echo "DEPLOY_TARGET=green" >> $GITHUB_ENV
          else
            echo "DEPLOY_TARGET=blue" >> $GITHUB_ENV
          fi

      - name: Deploy to inactive environment
        run: ./deploy.sh ${{ env.DEPLOY_TARGET }}

      - name: Run smoke tests
        run: ./smoke-test.sh ${{ env.DEPLOY_TARGET }}

      - name: Switch traffic
        run: ./switch-traffic.sh ${{ env.DEPLOY_TARGET }}

      - name: Verify production
        run: ./verify-production.sh

      - name: Update active environment marker
        run: |
          aws ssm put-parameter --name /deploy/active-env \
            --value ${{ env.DEPLOY_TARGET }} --overwrite
```

## Database Considerations

The shared database is the biggest challenge in blue/green deployments.

### Expand-Contract Migration Pattern

```
Phase 1: Expand (deploy to inactive env)
  - Add new columns/tables
  - Keep old columns/tables
  - Both v1 and v2 code works

Phase 2: Switch traffic
  - Route traffic to new environment
  - Old environment idle but ready

Phase 3: Contract (after confidence period)
  - Remove old columns/tables
  - Only after rollback window expires
```

```sql
-- Phase 1: Add new column (backward-compatible)
ALTER TABLE users ADD COLUMN display_name VARCHAR(255);
UPDATE users SET display_name = CONCAT(first_name, ' ', last_name);

-- Phase 3: Remove old columns (after rollback window)
ALTER TABLE users DROP COLUMN first_name;
ALTER TABLE users DROP COLUMN last_name;
```

## Verification Checklist

Before switching traffic:

- [ ] All health checks passing on inactive environment
- [ ] Smoke tests pass against inactive environment
- [ ] Database migrations applied and backward-compatible
- [ ] Configuration verified (env vars, secrets, feature flags)
- [ ] Load test on inactive environment (optional)
- [ ] Monitoring dashboards showing healthy metrics

After switching:

- [ ] Error rate within acceptable range
- [ ] Latency within acceptable range
- [ ] Business metrics stable
- [ ] No increase in support tickets
- [ ] Keep old environment ready for rollback (24-48h minimum)

## Cost Optimization

Blue/green requires 2x infrastructure during deployment:

| Approach | Cost | Trade-off |
|----------|------|-----------|
| Always running both | 2x | Instant switch, wasteful |
| Spin up on deploy | 1x + deploy time | Slower deploy, cost-efficient |
| Spot/preemptible for inactive | ~1.3x | Good balance |
| Container-based (ECS/K8s) | ~1.1x | Shared cluster, minimal overhead |

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| Shared database schema coupling | Can't rollback if migration is destructive | Use expand-contract pattern |
| Long DNS TTL | Slow switchover | Use load balancer switch, not DNS |
| Forgetting to warm up | Cold start latency spike | Pre-warm caches and connections |
| No rollback testing | Rollback fails when needed | Test rollback in staging regularly |
| Stale inactive environment | Drift between environments | Rebuild inactive on every deploy |
