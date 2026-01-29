---
title: Failover Patterns Reference
category: operations
type: reference
version: "1.0.0"
---

# Failover Patterns

> Part of the operations/disaster-recovery knowledge skill

## Overview

Failover patterns define how systems automatically or manually switch to redundant components when primary systems fail. The choice of pattern depends on RTO requirements and acceptable complexity.

## Quick Reference (80/20)

| Pattern | RTO | Complexity | Data Loss Risk |
|---------|-----|-----------|----------------|
| Active-active | ~0 | Very high | None |
| Active-passive hot | Seconds-minutes | High | Minimal |
| Active-passive warm | Minutes-hours | Medium | Some |
| Pilot light | Hours | Low-medium | Moderate |
| Backup & restore | Hours-days | Low | Higher |

## Patterns

### Pattern 1: Active-Active Multi-Region

**When to Use**: Zero-downtime requirement, global user base

**Example**:
```yaml
# AWS Route 53 active-active routing
# route53.tf
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  # Latency-based routing for active-active
  set_identifier = "us-east-1"
  latency_routing_policy {
    region = "us-east-1"
  }

  alias {
    name                   = aws_lb.api_us_east.dns_name
    zone_id                = aws_lb.api_us_east.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.api_us_east.id
}

resource "aws_route53_record" "api_eu" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.example.com"
  type    = "A"

  set_identifier = "eu-west-1"
  latency_routing_policy {
    region = "eu-west-1"
  }

  alias {
    name                   = aws_lb.api_eu_west.dns_name
    zone_id                = aws_lb.api_eu_west.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.api_eu_west.id
}

resource "aws_route53_health_check" "api_us_east" {
  fqdn              = aws_lb.api_us_east.dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 10

  tags = {
    Name = "api-us-east-health"
  }
}
```

**Trade-off**: Requires conflict resolution for writes (CRDTs, last-writer-wins, or single-leader writes).

### Pattern 2: Active-Passive Hot Standby

**When to Use**: Low RTO with simpler architecture than active-active

**Example**:
```yaml
# Kubernetes - Primary/Standby with automated failover
# Using a StatefulSet with leader election
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: database
spec:
  serviceName: postgres
  replicas: 2
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          env:
            - name: POSTGRES_REPLICATION_MODE
              value: "streaming"
          ports:
            - containerPort: 5432
          readinessProbe:
            exec:
              command:
                - pg_isready
                - -U
                - postgres
            initialDelaySeconds: 5
            periodSeconds: 10
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data

        - name: patroni
          image: patroni:3.0
          env:
            - name: PATRONI_SCOPE
              value: "postgres-cluster"
            - name: PATRONI_KUBERNETES_USE_ENDPOINTS
              value: "true"
          ports:
            - containerPort: 8008
              name: patroni
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Gi
```

```python
# Health check endpoint for failover detection
# health_check.py
import asyncio
import aiohttp
from datetime import datetime, timedelta

class FailoverMonitor:
    def __init__(self, primary_url: str, standby_url: str):
        self.primary_url = primary_url
        self.standby_url = standby_url
        self.failure_count = 0
        self.failure_threshold = 3
        self.check_interval = 5  # seconds
        self.last_healthy = datetime.now()

    async def check_health(self, url: str) -> bool:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    f"{url}/health",
                    timeout=aiohttp.ClientTimeout(total=5)
                ) as resp:
                    return resp.status == 200
        except Exception:
            return False

    async def monitor(self):
        while True:
            primary_healthy = await self.check_health(self.primary_url)

            if primary_healthy:
                self.failure_count = 0
                self.last_healthy = datetime.now()
            else:
                self.failure_count += 1
                print(f"Primary unhealthy: {self.failure_count}/{self.failure_threshold}")

                if self.failure_count >= self.failure_threshold:
                    await self.trigger_failover()
                    self.failure_count = 0

            await asyncio.sleep(self.check_interval)

    async def trigger_failover(self):
        print("FAILOVER: Promoting standby to primary")
        standby_healthy = await self.check_health(self.standby_url)
        if not standby_healthy:
            print("CRITICAL: Standby also unhealthy - manual intervention required")
            return

        # Promote standby (implementation depends on infrastructure)
        async with aiohttp.ClientSession() as session:
            await session.post(f"{self.standby_url}/promote")

        # Update DNS/load balancer
        await self.update_routing(self.standby_url)
        print("FAILOVER COMPLETE: Standby promoted")
```

**Anti-Pattern**: Manual failover procedures that require on-call to execute multi-step runbooks under pressure.

### Pattern 3: Pilot Light

**When to Use**: Cost-effective DR with acceptable RTO of hours

**Example**:
```terraform
# Pilot light - minimal infrastructure always running
# Only core components (DB replicas) are running
# Compute scales up on failover

resource "aws_rds_cluster" "dr_replica" {
  provider = aws.dr-region

  cluster_identifier     = "myapp-dr"
  engine                = "aurora-postgresql"
  engine_version        = "16.1"
  replication_source_arn = aws_rds_cluster.primary.arn

  # Minimal instance for replication
  # Scales up during failover
}

resource "aws_rds_cluster_instance" "dr_replica" {
  provider = aws.dr-region

  identifier         = "myapp-dr-1"
  cluster_identifier = aws_rds_cluster.dr_replica.id
  instance_class     = "db.t3.medium"  # Small during standby
  engine             = "aurora-postgresql"
}

# Auto Scaling Group - 0 instances normally, scales up on failover
resource "aws_autoscaling_group" "dr_app" {
  provider = aws.dr-region

  name                = "myapp-dr"
  min_size            = 0  # No instances normally
  max_size            = 10
  desired_capacity    = 0  # Scaled up during failover

  launch_template {
    id      = aws_launch_template.app_dr.id
    version = "$Latest"
  }
}

# Failover Lambda - triggered by CloudWatch alarm
resource "aws_lambda_function" "failover" {
  function_name = "dr-failover"
  handler       = "failover.handler"
  runtime       = "python3.12"

  environment {
    variables = {
      DR_ASG_NAME    = aws_autoscaling_group.dr_app.name
      DR_DB_CLUSTER  = aws_rds_cluster.dr_replica.id
      DR_REGION      = "us-west-2"
    }
  }
}
```

**Anti-Pattern**: Keeping pilot light infrastructure untested - it often drifts from production configuration.

### Pattern 4: DNS-Based Failover

**When to Use**: Simple failover for stateless services

**Example**:
```yaml
# Cloudflare load balancer with failover
# cloudflare-lb.yaml
load_balancer:
  name: api.example.com
  fallback_pool: us-west-pool
  default_pools:
    - us-east-pool
  region_pools:
    WNAM:
      - us-west-pool
    ENAM:
      - us-east-pool
    WEU:
      - eu-west-pool

pools:
  - id: us-east-pool
    name: US East
    origins:
      - name: primary
        address: api-east.example.com
        enabled: true
    monitor: health-monitor
    notification_email: oncall@example.com
    minimum_origins: 1

  - id: us-west-pool
    name: US West
    origins:
      - name: secondary
        address: api-west.example.com
        enabled: true
    monitor: health-monitor

monitors:
  - id: health-monitor
    type: https
    path: /health
    port: 443
    interval: 15
    retries: 2
    timeout: 5
    expected_codes: "200"
    follow_redirects: false
    allow_insecure: false
    header:
      Host:
        - api.example.com
```

**Anti-Pattern**: Relying solely on DNS TTL for failover speed - clients and resolvers cache aggressively.

### Pattern 5: Circuit Breaker with Fallback

**When to Use**: Application-level resilience against dependency failures

**Example**:
```typescript
// circuit-breaker.ts
enum CircuitState {
  CLOSED = "CLOSED",       // Normal operation
  OPEN = "OPEN",           // Failing, use fallback
  HALF_OPEN = "HALF_OPEN", // Testing recovery
}

interface CircuitBreakerConfig {
  failureThreshold: number;
  recoveryTimeout: number;  // ms
  halfOpenMaxCalls: number;
}

class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failureCount = 0;
  private lastFailureTime = 0;
  private halfOpenCalls = 0;

  constructor(
    private readonly config: CircuitBreakerConfig = {
      failureThreshold: 5,
      recoveryTimeout: 30000,
      halfOpenMaxCalls: 3,
    }
  ) {}

  async execute<T>(
    primaryFn: () => Promise<T>,
    fallbackFn: () => Promise<T>
  ): Promise<T> {
    if (this.state === CircuitState.OPEN) {
      if (Date.now() - this.lastFailureTime > this.config.recoveryTimeout) {
        this.state = CircuitState.HALF_OPEN;
        this.halfOpenCalls = 0;
      } else {
        return fallbackFn();
      }
    }

    if (this.state === CircuitState.HALF_OPEN) {
      if (this.halfOpenCalls >= this.config.halfOpenMaxCalls) {
        return fallbackFn();
      }
      this.halfOpenCalls++;
    }

    try {
      const result = await primaryFn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      return fallbackFn();
    }
  }

  private onSuccess(): void {
    this.failureCount = 0;
    if (this.state === CircuitState.HALF_OPEN) {
      this.state = CircuitState.CLOSED;
    }
  }

  private onFailure(): void {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.failureCount >= this.config.failureThreshold) {
      this.state = CircuitState.OPEN;
    }
  }
}

// Usage
const dbCircuit = new CircuitBreaker({ failureThreshold: 3, recoveryTimeout: 60000, halfOpenMaxCalls: 2 });

async function getUser(id: string): Promise<User> {
  return dbCircuit.execute(
    () => primaryDB.query(`SELECT * FROM users WHERE id = $1`, [id]),
    () => readReplicaDB.query(`SELECT * FROM users WHERE id = $1`, [id])
  );
}
```

**Anti-Pattern**: No fallback defined - circuit breaker just fails fast without providing degraded service.

## Failover Decision Matrix

| Scenario | Recommended Pattern | Key Consideration |
|----------|-------------------|-------------------|
| Global SaaS platform | Active-active | Write conflict resolution |
| Regional application | Active-passive hot | Replication lag |
| Cost-sensitive DR | Pilot light | Spin-up time |
| Stateless microservice | DNS failover | DNS propagation |
| Dependency failure | Circuit breaker | Fallback quality |

## Checklist

- [ ] Failover pattern matches RTO requirement
- [ ] Automated health checks configured
- [ ] Failover triggers defined and tested
- [ ] Runbooks documented for manual steps
- [ ] Data consistency verified post-failover
- [ ] Failback procedures defined
- [ ] Regular failover drills conducted
- [ ] Monitoring for split-brain scenarios
- [ ] Communication plan for stakeholders
- [ ] Post-failover validation automated

## References

- [AWS Multi-Region Architecture](https://docs.aws.amazon.com/whitepapers/latest/disaster-recovery-workloads-on-aws/)
- [Patroni Documentation](https://patroni.readthedocs.io/)
- [Circuit Breaker Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
