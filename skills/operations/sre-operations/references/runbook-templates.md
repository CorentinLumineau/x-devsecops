---
title: Runbook Templates Reference
category: operations
type: reference
version: "1.0.0"
---

# Runbook Templates

> Part of the operations/incident-response knowledge skill

## Overview

Runbooks provide standardized procedures for operational tasks and incident response. This reference covers runbook structure, templates, and automation patterns.

## Quick Reference (80/20)

| Section | Purpose |
|---------|---------|
| Overview | What the runbook addresses |
| Prerequisites | Required access and tools |
| Symptoms | How to identify the issue |
| Resolution | Step-by-step fix |
| Verification | Confirm resolution |
| Escalation | When to escalate |

## Patterns

### Pattern 1: Incident Response Runbook

**When to Use**: Responding to production incidents

**Example**:
```markdown
# Runbook: High API Latency

## Overview

This runbook addresses situations where API response times exceed acceptable thresholds (P99 > 500ms).

**Severity**: P1 - Critical
**On-Call Team**: Platform Engineering
**Last Updated**: 2024-01-15
**Author**: @platform-team

## Prerequisites

- [ ] Access to Grafana dashboards
- [ ] kubectl access to production cluster
- [ ] AWS Console access (read)
- [ ] PagerDuty access

## Symptoms

- API latency alerts firing (P99 > 500ms for 5+ minutes)
- Customer complaints about slow responses
- Increased error rates (timeouts)
- Health check failures

## Diagnostic Steps

### Step 1: Assess Scope

```bash
# Check which endpoints are affected
kubectl exec -it $(kubectl get pods -l app=api -o jsonpath='{.items[0].metadata.name}') \
  -- curl -s localhost:9090/metrics | grep http_request_duration_seconds

# Check if specific services are affected
for svc in api-gateway auth-service user-service order-service; do
  echo "=== $svc ==="
  kubectl top pods -l app=$svc
done
```

### Step 2: Check Resource Usage

```bash
# Check CPU and memory across pods
kubectl top pods -n production --sort-by=cpu

# Check node resources
kubectl top nodes

# Check for OOMKilled containers
kubectl get events -n production --field-selector reason=OOMKilled
```

### Step 3: Check Database

```bash
# Check database connection pool
kubectl exec -it $(kubectl get pods -l app=api -o jsonpath='{.items[0].metadata.name}') \
  -- curl -s localhost:9090/metrics | grep db_pool

# Check slow queries (requires DB access)
psql -h $DB_HOST -U $DB_USER -d production -c \
  "SELECT query, calls, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

### Step 4: Check External Dependencies

```bash
# Check Redis latency
redis-cli -h $REDIS_HOST --latency

# Check third-party API status
curl -w "@curl-format.txt" -o /dev/null -s https://api.stripe.com/v1/health
```

## Resolution Steps

### Scenario A: High CPU (> 80%)

1. **Scale horizontally**:
   ```bash
   kubectl scale deployment api --replicas=10 -n production
   ```

2. **Verify scaling**:
   ```bash
   kubectl get pods -l app=api -n production -w
   ```

3. **Monitor latency improvement**:
   - Open Grafana dashboard: https://grafana.example.com/d/api-latency
   - Wait for P99 to drop below 500ms

### Scenario B: Database Bottleneck

1. **Kill long-running queries**:
   ```sql
   SELECT pg_terminate_backend(pid)
   FROM pg_stat_activity
   WHERE duration > interval '5 minutes'
     AND state = 'active';
   ```

2. **Add read replicas** (if needed):
   ```bash
   terraform apply -target=module.db_read_replica
   ```

3. **Update connection strings**:
   ```bash
   kubectl set env deployment/api DATABASE_READ_URL=$NEW_REPLICA_URL
   ```

### Scenario C: Memory Pressure

1. **Restart affected pods**:
   ```bash
   kubectl rollout restart deployment/api -n production
   ```

2. **If persistent, increase limits**:
   ```bash
   kubectl patch deployment api -n production \
     -p '{"spec":{"template":{"spec":{"containers":[{"name":"api","resources":{"limits":{"memory":"1Gi"}}}]}}}}'
   ```

### Scenario D: External Dependency Failure

1. **Enable circuit breaker**:
   ```bash
   kubectl set env deployment/api CIRCUIT_BREAKER_ENABLED=true
   ```

2. **Notify affected teams**:
   - Post in #incidents Slack channel
   - Create external incident ticket

## Verification

After applying fixes:

1. **Check latency metrics**:
   ```bash
   # P99 should be < 500ms
   curl -s http://prometheus:9090/api/v1/query \
     --data-urlencode 'query=histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))' \
     | jq '.data.result[0].value[1]'
   ```

2. **Check error rates**:
   ```bash
   # Error rate should be < 1%
   curl -s http://prometheus:9090/api/v1/query \
     --data-urlencode 'query=rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])' \
     | jq '.data.result[0].value[1]'
   ```

3. **Verify health checks**:
   ```bash
   kubectl get pods -l app=api -n production -o jsonpath='{range .items[*]}{.metadata.name}: {.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'
   ```

## Escalation

Escalate if:
- Issue persists after 30 minutes
- Root cause cannot be identified
- Multiple services affected
- Data integrity concerns

**Escalation Path**:
1. Page secondary on-call: `pd trigger --service=platform-eng`
2. Contact Tech Lead: @tech-lead (Slack/Phone)
3. Engage SRE Manager: @sre-manager

## Post-Incident

- [ ] Create incident report ticket
- [ ] Update this runbook if needed
- [ ] Schedule post-mortem within 48 hours
- [ ] Document any temporary fixes for follow-up

## Related Resources

- [API Dashboard](https://grafana.example.com/d/api)
- [Database Dashboard](https://grafana.example.com/d/database)
- [Incident Response Guide](../incident-response.md)
- [Escalation Matrix](../escalation-matrix.md)
```

**Anti-Pattern**: Runbooks without verification steps.

### Pattern 2: Automated Runbook

**When to Use**: Automating common operational tasks

**Example**:
```typescript
// runbook-executor.ts
interface RunbookStep {
  id: string;
  name: string;
  type: 'manual' | 'automated' | 'approval';
  command?: string;
  script?: string;
  timeout?: number;
  retries?: number;
  onFailure?: 'continue' | 'stop' | 'rollback';
  verification?: VerificationStep;
}

interface VerificationStep {
  type: 'metric' | 'command' | 'http';
  condition: string;
  timeout: number;
}

interface RunbookExecution {
  runbookId: string;
  executionId: string;
  status: 'running' | 'completed' | 'failed' | 'pending_approval';
  currentStep: number;
  steps: StepResult[];
  startedAt: Date;
  completedAt?: Date;
  executor: string;
}

interface StepResult {
  stepId: string;
  status: 'pending' | 'running' | 'success' | 'failed' | 'skipped';
  output?: string;
  error?: string;
  duration?: number;
  verificationResult?: boolean;
}

class RunbookExecutor {
  constructor(
    private commandRunner: CommandRunner,
    private metricsService: MetricsService,
    private notificationService: NotificationService,
    private auditLog: AuditLog
  ) {}

  async execute(
    runbook: Runbook,
    context: ExecutionContext
  ): Promise<RunbookExecution> {
    const execution: RunbookExecution = {
      runbookId: runbook.id,
      executionId: this.generateExecutionId(),
      status: 'running',
      currentStep: 0,
      steps: runbook.steps.map(step => ({
        stepId: step.id,
        status: 'pending'
      })),
      startedAt: new Date(),
      executor: context.executor
    };

    await this.auditLog.record({
      event: 'runbook_started',
      runbookId: runbook.id,
      executionId: execution.executionId,
      executor: context.executor
    });

    try {
      for (let i = 0; i < runbook.steps.length; i++) {
        execution.currentStep = i;
        const step = runbook.steps[i];
        const stepResult = execution.steps[i];

        stepResult.status = 'running';

        if (step.type === 'approval') {
          execution.status = 'pending_approval';
          await this.requestApproval(execution, step);
          await this.waitForApproval(execution, step);
          execution.status = 'running';
        }

        const result = await this.executeStep(step, context);

        stepResult.status = result.success ? 'success' : 'failed';
        stepResult.output = result.output;
        stepResult.error = result.error;
        stepResult.duration = result.duration;

        if (step.verification) {
          stepResult.verificationResult = await this.verify(
            step.verification,
            context
          );

          if (!stepResult.verificationResult) {
            stepResult.status = 'failed';
          }
        }

        if (stepResult.status === 'failed') {
          if (step.onFailure === 'stop') {
            throw new Error(`Step ${step.id} failed: ${result.error}`);
          } else if (step.onFailure === 'rollback') {
            await this.rollback(execution, runbook, i);
            throw new Error(`Step ${step.id} failed, rolled back`);
          }
          // 'continue' - proceed to next step
        }
      }

      execution.status = 'completed';
      execution.completedAt = new Date();

    } catch (error) {
      execution.status = 'failed';
      execution.completedAt = new Date();

      await this.notificationService.sendAlert({
        type: 'runbook_failed',
        runbookId: runbook.id,
        executionId: execution.executionId,
        error: error.message
      });
    }

    await this.auditLog.record({
      event: 'runbook_completed',
      runbookId: runbook.id,
      executionId: execution.executionId,
      status: execution.status,
      duration: execution.completedAt!.getTime() - execution.startedAt.getTime()
    });

    return execution;
  }

  private async executeStep(
    step: RunbookStep,
    context: ExecutionContext
  ): Promise<{ success: boolean; output?: string; error?: string; duration: number }> {
    const startTime = Date.now();

    try {
      let output: string;

      if (step.command) {
        output = await this.commandRunner.run(
          this.interpolate(step.command, context),
          { timeout: step.timeout ?? 60000 }
        );
      } else if (step.script) {
        output = await this.commandRunner.runScript(
          this.interpolate(step.script, context),
          { timeout: step.timeout ?? 300000 }
        );
      } else {
        throw new Error(`Step ${step.id} has no command or script`);
      }

      return {
        success: true,
        output,
        duration: Date.now() - startTime
      };

    } catch (error) {
      // Retry logic
      if (step.retries && step.retries > 0) {
        for (let attempt = 1; attempt <= step.retries; attempt++) {
          await this.sleep(Math.pow(2, attempt) * 1000);

          try {
            const output = await this.commandRunner.run(
              this.interpolate(step.command!, context),
              { timeout: step.timeout ?? 60000 }
            );

            return {
              success: true,
              output,
              duration: Date.now() - startTime
            };
          } catch (retryError) {
            if (attempt === step.retries) {
              return {
                success: false,
                error: retryError.message,
                duration: Date.now() - startTime
              };
            }
          }
        }
      }

      return {
        success: false,
        error: error.message,
        duration: Date.now() - startTime
      };
    }
  }

  private async verify(
    verification: VerificationStep,
    context: ExecutionContext
  ): Promise<boolean> {
    const deadline = Date.now() + verification.timeout;

    while (Date.now() < deadline) {
      try {
        let value: any;

        switch (verification.type) {
          case 'metric':
            value = await this.metricsService.query(
              this.interpolate(verification.condition, context)
            );
            break;

          case 'command':
            value = await this.commandRunner.run(
              this.interpolate(verification.condition, context)
            );
            break;

          case 'http':
            const response = await fetch(
              this.interpolate(verification.condition, context)
            );
            value = response.ok;
            break;
        }

        if (this.evaluateCondition(value)) {
          return true;
        }

      } catch (error) {
        // Continue polling
      }

      await this.sleep(5000);
    }

    return false;
  }

  private interpolate(template: string, context: ExecutionContext): string {
    return template.replace(/\{\{(\w+)\}\}/g, (_, key) => {
      return context.variables[key] ?? '';
    });
  }

  private evaluateCondition(value: any): boolean {
    // Simplified - in production use proper expression evaluation
    return Boolean(value);
  }

  private async rollback(
    execution: RunbookExecution,
    runbook: Runbook,
    failedStepIndex: number
  ): Promise<void> {
    // Execute rollback steps in reverse order
    for (let i = failedStepIndex; i >= 0; i--) {
      const step = runbook.steps[i];
      if (step.rollbackCommand) {
        await this.commandRunner.run(step.rollbackCommand);
      }
    }
  }

  private async requestApproval(
    execution: RunbookExecution,
    step: RunbookStep
  ): Promise<void> {
    await this.notificationService.sendApprovalRequest({
      executionId: execution.executionId,
      stepId: step.id,
      stepName: step.name,
      approvers: step.approvers ?? ['on-call']
    });
  }

  private async waitForApproval(
    execution: RunbookExecution,
    step: RunbookStep
  ): Promise<void> {
    // Implementation depends on approval system
  }

  private generateExecutionId(): string {
    return `exec-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Example runbook definition
const databaseFailoverRunbook: Runbook = {
  id: 'database-failover',
  name: 'Database Failover',
  description: 'Failover to standby database',
  steps: [
    {
      id: 'verify-standby',
      name: 'Verify Standby Health',
      type: 'automated',
      command: 'pg_isready -h {{STANDBY_HOST}}',
      onFailure: 'stop'
    },
    {
      id: 'approval',
      name: 'Approve Failover',
      type: 'approval',
      approvers: ['dba-team', 'tech-lead']
    },
    {
      id: 'drain-connections',
      name: 'Drain Primary Connections',
      type: 'automated',
      command: 'psql -h {{PRIMARY_HOST}} -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = \'production\';"',
      timeout: 30000
    },
    {
      id: 'promote-standby',
      name: 'Promote Standby',
      type: 'automated',
      command: 'pg_ctl promote -D /var/lib/postgresql/data',
      verification: {
        type: 'command',
        condition: 'psql -h {{STANDBY_HOST}} -c "SELECT pg_is_in_recovery();" | grep -q "f"',
        timeout: 60000
      },
      onFailure: 'stop'
    },
    {
      id: 'update-dns',
      name: 'Update DNS',
      type: 'automated',
      command: 'aws route53 change-resource-record-sets --hosted-zone-id {{ZONE_ID}} --change-batch file://dns-update.json',
      rollbackCommand: 'aws route53 change-resource-record-sets --hosted-zone-id {{ZONE_ID}} --change-batch file://dns-rollback.json'
    },
    {
      id: 'verify-app',
      name: 'Verify Application',
      type: 'automated',
      command: 'curl -f https://api.example.com/health',
      verification: {
        type: 'http',
        condition: 'https://api.example.com/health',
        timeout: 120000
      }
    }
  ]
};
```

**Anti-Pattern**: Complex automated runbooks without manual override.

### Pattern 3: Service Restart Template

**When to Use**: Standardized service restarts

**Example**:
```markdown
# Runbook: Service Restart - {{SERVICE_NAME}}

## Overview

Standard procedure for restarting {{SERVICE_NAME}} in production.

**Risk Level**: Medium
**Expected Duration**: 5-10 minutes
**Requires Approval**: No (for standard restart)

## Pre-Restart Checklist

- [ ] No active deployments in progress
- [ ] No other incidents affecting related services
- [ ] Traffic is within normal parameters
- [ ] Backup/standby available (if applicable)

## Procedure

### Step 1: Announce Restart

```bash
# Post to Slack
curl -X POST $SLACK_WEBHOOK -H 'Content-Type: application/json' \
  -d '{"text":"[MAINTENANCE] Starting controlled restart of {{SERVICE_NAME}}"}'
```

### Step 2: Check Current State

```bash
# Get current pod status
kubectl get pods -l app={{SERVICE_NAME}} -n production

# Check current metrics
kubectl exec -it $(kubectl get pods -l app={{SERVICE_NAME}} -o jsonpath='{.items[0].metadata.name}') \
  -- curl -s localhost:9090/metrics | grep -E "(requests_total|errors_total)"
```

### Step 3: Perform Rolling Restart

```bash
# Trigger rolling restart
kubectl rollout restart deployment/{{SERVICE_NAME}} -n production

# Watch rollout progress
kubectl rollout status deployment/{{SERVICE_NAME}} -n production --timeout=5m
```

### Step 4: Verify Health

```bash
# Check all pods are ready
kubectl get pods -l app={{SERVICE_NAME}} -n production

# Verify health endpoints
for pod in $(kubectl get pods -l app={{SERVICE_NAME}} -n production -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $pod ==="
  kubectl exec $pod -- curl -s localhost:8080/health
done

# Check error rates
watch -n 5 'kubectl exec -it $(kubectl get pods -l app={{SERVICE_NAME}} -o jsonpath='"'"'{.items[0].metadata.name}'"'"') -- curl -s localhost:9090/metrics | grep http_requests_total'
```

### Step 5: Confirm Completion

```bash
# Post completion
curl -X POST $SLACK_WEBHOOK -H 'Content-Type: application/json' \
  -d '{"text":"[MAINTENANCE] {{SERVICE_NAME}} restart completed successfully"}'
```

## Rollback

If restart causes issues:

```bash
# Rollback to previous revision
kubectl rollout undo deployment/{{SERVICE_NAME}} -n production

# Verify rollback
kubectl rollout status deployment/{{SERVICE_NAME}} -n production
```

## Emergency Contacts

- On-Call: Check PagerDuty
- Service Owner: @{{OWNER}}
- Escalation: @platform-lead
```

**Anti-Pattern**: Restarts without health verification.

### Pattern 4: Capacity Scaling Runbook

**When to Use**: Manual scaling during high load

**Example**:
```yaml
# capacity-scaling-runbook.yaml
apiVersion: runbook/v1
kind: Runbook
metadata:
  name: capacity-scaling
  labels:
    category: operations
    severity: p2
spec:
  description: Scale services during high traffic events
  triggers:
    - type: alert
      name: high_traffic_alert
    - type: scheduled
      cron: "0 8 * * 1-5"  # Business hours scaling

  variables:
    - name: SERVICE
      description: Service to scale
      required: true
    - name: REPLICAS
      description: Target replica count
      required: true
    - name: REASON
      description: Reason for scaling
      required: true

  steps:
    - name: validate-inputs
      type: script
      script: |
        if [ "$REPLICAS" -lt 2 ] || [ "$REPLICAS" -gt 50 ]; then
          echo "Invalid replica count: $REPLICAS (must be 2-50)"
          exit 1
        fi

        kubectl get deployment $SERVICE -n production || {
          echo "Service $SERVICE not found"
          exit 1
        }

    - name: check-current-state
      type: command
      command: |
        echo "Current state:"
        kubectl get deployment $SERVICE -n production
        kubectl top pods -l app=$SERVICE -n production

    - name: check-cluster-capacity
      type: script
      script: |
        # Ensure cluster has capacity
        CURRENT=$(kubectl get deployment $SERVICE -n production -o jsonpath='{.spec.replicas}')
        NEEDED=$((REPLICAS - CURRENT))

        if [ $NEEDED -gt 0 ]; then
          # Check if nodes can accommodate
          kubectl describe nodes | grep -A 5 "Allocated resources"
        fi

    - name: scale-service
      type: command
      command: kubectl scale deployment $SERVICE --replicas=$REPLICAS -n production
      rollback: kubectl scale deployment $SERVICE --replicas=$PREVIOUS_REPLICAS -n production

    - name: wait-for-ready
      type: script
      script: |
        kubectl rollout status deployment/$SERVICE -n production --timeout=10m

    - name: verify-scaling
      type: verification
      checks:
        - type: pods_ready
          selector: app=$SERVICE
          namespace: production
          expected: $REPLICAS
          timeout: 300

        - type: metric
          query: sum(up{app="$SERVICE"}) == $REPLICAS
          timeout: 60

    - name: update-hpa
      type: command
      condition: $UPDATE_HPA == "true"
      command: |
        kubectl patch hpa $SERVICE -n production \
          -p '{"spec":{"minReplicas":'$REPLICAS'}}'

    - name: notify-completion
      type: notification
      channels:
        - slack:#operations
      message: |
        Scaling completed for $SERVICE
        - Previous: $PREVIOUS_REPLICAS replicas
        - Current: $REPLICAS replicas
        - Reason: $REASON
        - Executed by: $EXECUTOR

  cleanup:
    - name: restore-hpa
      type: command
      command: |
        # Restore HPA to default after event
        kubectl patch hpa $SERVICE -n production \
          -p '{"spec":{"minReplicas":3}}'
```

**Anti-Pattern**: Scaling without capacity verification.

### Pattern 5: Certificate Renewal Runbook

**When to Use**: Renewing TLS certificates

**Example**:
```markdown
# Runbook: TLS Certificate Renewal

## Overview

Procedure for renewing TLS certificates before expiration.

**Scheduled**: 30 days before expiration
**Risk Level**: Low (with proper testing)
**Downtime**: None (if using rolling updates)

## Prerequisites

- [ ] Access to certificate management system (cert-manager/Vault/AWS ACM)
- [ ] kubectl access to affected clusters
- [ ] DNS management access (if using DNS validation)

## Check Expiration

```bash
# Check certificate expiration dates
for secret in $(kubectl get secrets -n production -l type=tls -o name); do
  echo "=== $secret ==="
  kubectl get $secret -n production -o jsonpath='{.data.tls\.crt}' | \
    base64 -d | openssl x509 -noout -dates
done

# Or using cert-manager
kubectl get certificates -A -o custom-columns=\
NAME:.metadata.name,\
NAMESPACE:.metadata.namespace,\
READY:.status.conditions[0].status,\
EXPIRY:.status.notAfter
```

## Renewal Procedures

### Option A: Cert-Manager (Automatic)

```bash
# Cert-manager should auto-renew. If not, force renewal:
kubectl delete secret <secret-name> -n production

# Cert-manager will recreate. Verify:
kubectl get certificate <cert-name> -n production -w
```

### Option B: Manual Renewal

#### Step 1: Generate CSR

```bash
# Generate new private key and CSR
openssl req -new -newkey rsa:2048 -nodes \
  -keyout domain.key \
  -out domain.csr \
  -subj "/CN=*.example.com/O=MyCompany"
```

#### Step 2: Submit to CA

```bash
# For Let's Encrypt via certbot
certbot certonly --manual --preferred-challenges dns \
  -d "*.example.com" -d "example.com"

# Or submit CSR to commercial CA
```

#### Step 3: Create/Update Secret

```bash
# Create new secret
kubectl create secret tls example-tls \
  --cert=fullchain.pem \
  --key=privkey.pem \
  -n production \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Step 4: Restart Ingress/Pods

```bash
# Trigger reload of certificates
kubectl rollout restart deployment/ingress-nginx -n ingress-nginx

# Or for application pods
kubectl rollout restart deployment/api -n production
```

## Verification

```bash
# Test new certificate
echo | openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null | \
  openssl x509 -noout -dates -subject

# Verify no certificate errors in logs
kubectl logs -l app=ingress-nginx -n ingress-nginx --since=5m | grep -i "ssl\|cert\|tls"

# Test HTTPS endpoint
curl -vI https://api.example.com 2>&1 | grep -E "(SSL|certificate|expire)"
```

## Monitoring

Set up alerts for upcoming expirations:

```yaml
# Prometheus alert rule
groups:
  - name: certificates
    rules:
      - alert: CertificateExpiringSoon
        expr: |
          (
            probe_ssl_earliest_cert_expiry - time()
          ) / 86400 < 30
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Certificate expiring in {{ $value | humanizeDuration }}"
          description: "Certificate for {{ $labels.instance }} expires soon"

      - alert: CertificateExpiryCritical
        expr: |
          (
            probe_ssl_earliest_cert_expiry - time()
          ) / 86400 < 7
        for: 1h
        labels:
          severity: critical
        annotations:
          summary: "Certificate expires in {{ $value | humanizeDuration }}"
```

## Troubleshooting

### Certificate Not Updating

```bash
# Check cert-manager logs
kubectl logs -l app=cert-manager -n cert-manager --tail=100

# Check certificate status
kubectl describe certificate <name> -n production
```

### DNS Validation Failing

```bash
# Verify DNS record
dig _acme-challenge.example.com TXT

# Check cert-manager DNS solver
kubectl logs -l acme.cert-manager.io/http01-solver=true -n production
```

## Rollback

If new certificate causes issues:

```bash
# Restore previous certificate from backup
kubectl apply -f backup/tls-secret-backup.yaml

# Restart affected services
kubectl rollout restart deployment/ingress-nginx -n ingress-nginx
```

## Documentation

After renewal:
- [ ] Update certificate inventory
- [ ] Record new expiration date
- [ ] Update any pinned certificates in clients
- [ ] Notify dependent teams
```

**Anti-Pattern**: Certificates renewed without testing.

## Checklist

- [ ] Runbooks exist for all critical operations
- [ ] Each runbook has clear prerequisites
- [ ] Steps are actionable and testable
- [ ] Verification steps included
- [ ] Rollback procedures documented
- [ ] Escalation paths defined
- [ ] Runbooks tested periodically
- [ ] Version control for runbooks
- [ ] Automation where appropriate
- [ ] Regular review and updates

## References

- [Google SRE Runbooks](https://sre.google/workbook/on-call/)
- [PagerDuty Runbook Best Practices](https://www.pagerduty.com/resources/learn/runbook-automation/)
- [Rundeck Documentation](https://docs.rundeck.com/)
- [Incident Management](https://response.pagerduty.com/)
