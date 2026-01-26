---
title: Deployment Strategies Reference
category: delivery
type: reference
version: "1.0.0"
---

# Deployment Strategies

> Part of the delivery/ci-cd knowledge skill

## Overview

Deployment strategies determine how new versions are released to production. This reference covers common patterns including blue-green, canary, and rolling deployments.

## Quick Reference (80/20)

| Strategy | Risk | Rollback | Use Case |
|----------|------|----------|----------|
| Blue-Green | Low | Instant | Full releases |
| Canary | Low | Fast | Gradual validation |
| Rolling | Medium | Gradual | Zero downtime |
| Recreate | High | Full redeploy | Stateful apps |
| A/B Testing | Low | Instant | Feature testing |

## Patterns

### Pattern 1: Blue-Green Deployment

**When to Use**: Zero-downtime deployments with instant rollback

**Example**:
```yaml
# Kubernetes blue-green deployment
apiVersion: v1
kind: Service
metadata:
  name: app
spec:
  selector:
    app: myapp
    version: blue  # Switch between blue/green
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
        - name: app
          image: myapp:1.0.0
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
        - name: app
          image: myapp:1.1.0
```

```bash
#!/bin/bash
# blue-green-deploy.sh

CURRENT_COLOR=$(kubectl get service app -o jsonpath='{.spec.selector.version}')
NEW_COLOR=$([[ "$CURRENT_COLOR" == "blue" ]] && echo "green" || echo "blue")

echo "Current: $CURRENT_COLOR, Deploying to: $NEW_COLOR"

# Deploy new version to inactive environment
kubectl set image deployment/app-$NEW_COLOR app=myapp:$NEW_VERSION

# Wait for rollout
kubectl rollout status deployment/app-$NEW_COLOR --timeout=300s

# Health check
for i in {1..10}; do
  if curl -sf "http://app-$NEW_COLOR:8080/health"; then
    echo "Health check passed"
    break
  fi
  sleep 5
done

# Switch traffic
kubectl patch service app -p "{\"spec\":{\"selector\":{\"version\":\"$NEW_COLOR\"}}}"

echo "Traffic switched to $NEW_COLOR"

# Rollback function
rollback() {
  echo "Rolling back to $CURRENT_COLOR"
  kubectl patch service app -p "{\"spec\":{\"selector\":{\"version\":\"$CURRENT_COLOR\"}}}"
}
```

**Anti-Pattern**: Not testing the inactive environment before switching.

### Pattern 2: Canary Deployment

**When to Use**: Gradual rollout with traffic splitting

**Example**:
```yaml
# Istio canary deployment
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app
spec:
  hosts:
    - app
  http:
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: app
            subset: canary
    - route:
        - destination:
            host: app
            subset: stable
          weight: 90
        - destination:
            host: app
            subset: canary
          weight: 10
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: app
spec:
  host: app
  subsets:
    - name: stable
      labels:
        version: stable
    - name: canary
      labels:
        version: canary
```

```typescript
// Canary deployment controller
interface CanaryConfig {
  steps: number[];           // Traffic percentages: [5, 10, 25, 50, 100]
  analysisInterval: number;  // Seconds between steps
  metrics: MetricThreshold[];
}

class CanaryController {
  constructor(
    private config: CanaryConfig,
    private metricsClient: MetricsClient,
    private trafficManager: TrafficManager
  ) {}

  async deploy(newVersion: string): Promise<DeploymentResult> {
    // Deploy canary instances
    await this.deployCanary(newVersion);

    for (const percentage of this.config.steps) {
      // Update traffic split
      await this.trafficManager.setCanaryWeight(percentage);
      console.log(`Canary traffic: ${percentage}%`);

      // Wait and analyze
      await this.sleep(this.config.analysisInterval * 1000);

      const analysis = await this.analyzeMetrics();

      if (!analysis.healthy) {
        console.error('Canary unhealthy, rolling back');
        await this.rollback();
        return { success: false, reason: analysis.failureReason };
      }

      console.log(`Analysis passed at ${percentage}%`);
    }

    // Promote canary to stable
    await this.promoteCanary();
    return { success: true };
  }

  private async analyzeMetrics(): Promise<AnalysisResult> {
    const results = await Promise.all(
      this.config.metrics.map(async (threshold) => {
        const value = await this.metricsClient.query(threshold.query);

        return {
          metric: threshold.name,
          value,
          threshold: threshold.value,
          passed: this.evaluateThreshold(value, threshold)
        };
      })
    );

    const failed = results.filter(r => !r.passed);

    return {
      healthy: failed.length === 0,
      failureReason: failed.length > 0
        ? `Failed metrics: ${failed.map(f => f.metric).join(', ')}`
        : undefined,
      metrics: results
    };
  }

  private async rollback(): Promise<void> {
    await this.trafficManager.setCanaryWeight(0);
    await this.deleteCanary();
  }
}

// Usage
const canary = new CanaryController({
  steps: [5, 10, 25, 50, 100],
  analysisInterval: 300, // 5 minutes
  metrics: [
    { name: 'error_rate', query: 'rate(errors[5m])', value: 0.01, op: 'lt' },
    { name: 'latency_p99', query: 'histogram_quantile(0.99, latency)', value: 500, op: 'lt' },
    { name: 'success_rate', query: 'rate(success[5m])', value: 0.99, op: 'gt' }
  ]
}, metricsClient, trafficManager);

await canary.deploy('v1.2.0');
```

**Anti-Pattern**: Canary without metrics analysis.

### Pattern 3: Rolling Deployment

**When to Use**: Gradual instance replacement

**Example**:
```yaml
# Kubernetes rolling update
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 2        # Allow 2 extra pods during update
      maxUnavailable: 1  # Keep at least 9 pods running
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: myapp:1.0.0
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
      terminationGracePeriodSeconds: 30
```

```bash
# Rolling deploy with kubectl
kubectl set image deployment/app app=myapp:1.1.0

# Watch rollout status
kubectl rollout status deployment/app

# Rollback if needed
kubectl rollout undo deployment/app

# Check history
kubectl rollout history deployment/app

# Rollback to specific revision
kubectl rollout undo deployment/app --to-revision=2

# Pause/resume rollout
kubectl rollout pause deployment/app
# Make fixes...
kubectl rollout resume deployment/app
```

**Anti-Pattern**: No readiness probes, causing traffic to unhealthy pods.

### Pattern 4: Progressive Delivery with Argo Rollouts

**When to Use**: Advanced deployment orchestration

**Example**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: app
spec:
  replicas: 10
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: app
          image: myapp:1.0.0
          ports:
            - containerPort: 8080
  strategy:
    canary:
      # Traffic management
      canaryService: app-canary
      stableService: app-stable
      trafficRouting:
        istio:
          virtualService:
            name: app
            routes:
              - primary

      # Canary steps
      steps:
        - setWeight: 5
        - pause: { duration: 5m }

        - setWeight: 10
        - analysis:
            templates:
              - templateName: success-rate

        - setWeight: 25
        - pause: { duration: 10m }

        - setWeight: 50
        - analysis:
            templates:
              - templateName: success-rate
              - templateName: latency

        - setWeight: 100

      # Automatic rollback
      analysis:
        successfulRunHistoryLimit: 3
        unsuccessfulRunHistoryLimit: 3

---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
    - name: success-rate
      interval: 1m
      successCondition: result[0] >= 0.99
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{status=~"2.*",app="{{args.app}}"}[5m]))
            /
            sum(rate(http_requests_total{app="{{args.app}}"}[5m]))
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: latency
spec:
  metrics:
    - name: latency-p99
      interval: 1m
      successCondition: result[0] < 500
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            histogram_quantile(0.99,
              sum(rate(http_request_duration_seconds_bucket{app="{{args.app}}"}[5m]))
              by (le)
            ) * 1000
```

**Anti-Pattern**: Manual analysis instead of automated metrics.

### Pattern 5: Feature Flag Deployment

**When to Use**: Decoupling deployment from release

**Example**:
```typescript
// Feature flag service integration
interface FeatureFlag {
  key: string;
  enabled: boolean;
  rolloutPercentage?: number;
  targetUsers?: string[];
  targetGroups?: string[];
}

class FeatureFlagService {
  constructor(private client: FeatureFlagClient) {}

  async isEnabled(
    flagKey: string,
    context: EvaluationContext
  ): Promise<boolean> {
    const flag = await this.client.getFlag(flagKey);

    if (!flag || !flag.enabled) return false;

    // Check user targeting
    if (flag.targetUsers?.includes(context.userId)) {
      return true;
    }

    // Check group targeting
    if (flag.targetGroups?.some(g => context.groups.includes(g))) {
      return true;
    }

    // Percentage rollout
    if (flag.rolloutPercentage !== undefined) {
      const hash = this.hashUser(context.userId, flagKey);
      return hash < flag.rolloutPercentage;
    }

    return flag.enabled;
  }

  private hashUser(userId: string, flagKey: string): number {
    // Consistent hashing for stable rollout
    const combined = `${userId}-${flagKey}`;
    let hash = 0;
    for (let i = 0; i < combined.length; i++) {
      hash = ((hash << 5) - hash) + combined.charCodeAt(i);
      hash = hash & hash;
    }
    return Math.abs(hash) % 100;
  }
}

// Usage in application
class PaymentService {
  constructor(private featureFlags: FeatureFlagService) {}

  async processPayment(order: Order, user: User): Promise<PaymentResult> {
    const context = { userId: user.id, groups: user.groups };

    // New payment flow behind feature flag
    if (await this.featureFlags.isEnabled('new-payment-flow', context)) {
      return this.newPaymentFlow(order);
    }

    return this.legacyPaymentFlow(order);
  }
}

// Deployment pipeline
// 1. Deploy code with feature behind flag (disabled)
// 2. Enable for internal users
// 3. Enable for beta users (10%)
// 4. Gradually increase rollout (25%, 50%, 100%)
// 5. Remove flag and old code
```

**Anti-Pattern**: Long-lived feature flags becoming technical debt.

### Pattern 6: Database Migration Strategy

**When to Use**: Coordinating schema changes with deployments

**Example**:
```typescript
// Expand-Contract migration pattern
// Phase 1: Expand - Add new column
await db.query(`
  ALTER TABLE users
  ADD COLUMN full_name VARCHAR(255)
`);

// Phase 2: Migrate - Backfill data
await db.query(`
  UPDATE users
  SET full_name = CONCAT(first_name, ' ', last_name)
  WHERE full_name IS NULL
`);

// Phase 3: Deploy new code
// Application writes to both old and new columns
class UserRepository {
  async updateName(userId: string, firstName: string, lastName: string): Promise<void> {
    await db.query(`
      UPDATE users
      SET first_name = $1,
          last_name = $2,
          full_name = $3
      WHERE id = $4
    `, [firstName, lastName, `${firstName} ${lastName}`, userId]);
  }

  // Read from new column with fallback
  async getDisplayName(userId: string): Promise<string> {
    const result = await db.query(`
      SELECT COALESCE(full_name, CONCAT(first_name, ' ', last_name)) as display_name
      FROM users
      WHERE id = $1
    `, [userId]);
    return result.rows[0].display_name;
  }
}

// Phase 4: Contract - Remove old columns (after all instances updated)
await db.query(`
  ALTER TABLE users
  DROP COLUMN first_name,
  DROP COLUMN last_name
`);
```

```yaml
# Flyway migrations
# V1__add_full_name.sql
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);

# V2__backfill_full_name.sql
UPDATE users SET full_name = CONCAT(first_name, ' ', last_name);

# V3__make_full_name_not_null.sql (after code deployed)
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;

# V4__drop_old_name_columns.sql (after verification)
ALTER TABLE users DROP COLUMN first_name;
ALTER TABLE users DROP COLUMN last_name;
```

**Anti-Pattern**: Breaking schema changes without backward compatibility.

## Checklist

- [ ] Deployment strategy matches risk tolerance
- [ ] Health checks configured for all instances
- [ ] Rollback procedure documented and tested
- [ ] Traffic splitting for canary deployments
- [ ] Metrics-based promotion criteria
- [ ] Database migrations are backward compatible
- [ ] Feature flags for risky changes
- [ ] Deployment pipeline fully automated
- [ ] Post-deployment verification automated
- [ ] Alerting configured for deployment failures

## References

- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Feature Flags Best Practices](https://launchdarkly.com/blog/feature-flags-best-practices/)
