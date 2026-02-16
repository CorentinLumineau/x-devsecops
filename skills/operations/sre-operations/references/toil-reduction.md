---
name: Toil Reduction
description: Identifying, measuring, and eliminating operational toil
category: operations/sre-practices
type: reference
license: Apache-2.0
---

# Toil Reduction

## Defining Toil

Toil is work that is:

| Property | Description | Example |
|----------|-------------|---------|
| Manual | Human performs it | SSH to restart a service |
| Repetitive | Done repeatedly | Weekly cert rotation |
| Automatable | Script could do it | Copy logs to archive |
| Reactive | Triggered by events | Responding to disk-full alerts |
| No lasting value | Doesn't improve system | Clearing a stuck queue |
| Scales with load | Grows with service size | Adding shards manually |

**Not toil**: project work, design, code review, on-call improvements, documentation.

## Measuring Toil

### Time Tracking

```yaml
toil_tracking:
  team: platform-sre
  quarter: Q1-2024
  members: 5

  categories:
    - name: "Manual deployments"
      hours_per_week: 8
      frequency: daily
      automatable: true
      priority: high

    - name: "Certificate renewal"
      hours_per_week: 2
      frequency: weekly
      automatable: true
      priority: medium

    - name: "Capacity requests"
      hours_per_week: 4
      frequency: as-needed
      automatable: partially
      priority: medium

  summary:
    total_hours_per_week: 14
    total_available_hours: 200  # 5 engineers * 40h
    toil_percentage: 7%
    target: "<50%"
```

### The 50% Rule

SRE teams should spend no more than 50% of time on toil. The other 50% goes to engineering work that reduces future toil.

## Prioritization Framework

Use effort-vs-impact to prioritize toil elimination:

```
High Impact  |  Quick Wins    |  Major Projects
             |  (Do First)    |  (Plan Next)
             |                |
Low Impact   |  Fill-ins      |  Don't Bother
             |  (Maybe)       |  (Skip)
             |________________|________________
               Low Effort       High Effort
```

### Scoring

```python
def toil_priority_score(frequency_per_week, time_per_occurrence_min,
                         automation_effort_hours):
    """Higher score = automate first."""
    annual_time_saved = frequency_per_week * time_per_occurrence_min * 52 / 60
    roi = annual_time_saved / automation_effort_hours
    return roi

# Example: Daily 15-min task, 8 hours to automate
# Annual savings = 5 * 15 * 52 / 60 = 65 hours
# ROI = 65 / 8 = 8.1x (excellent)
```

## Elimination Strategies

### 1. Self-Healing Systems

```yaml
# Kubernetes auto-restart on failure
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: app
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

### 2. Automated Scaling

```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### 3. Runbook Automation

Progress from manual to fully automated:

```
Level 0: No documentation
  → Write a runbook

Level 1: Documented steps
  → Script individual steps

Level 2: Scripted steps
  → Chain scripts into a single command

Level 3: Single command
  → Trigger automatically on alert

Level 4: Fully automated
  → Self-healing, no human needed
```

### 4. Deployment Automation

| Manual Step | Automated Replacement |
|------------|----------------------|
| SSH and pull code | CI/CD pipeline |
| Run database migrations | Migration in deploy pipeline |
| Update config files | Config management (Vault, ConfigMap) |
| Restart services | Rolling restart via orchestrator |
| Verify health | Automated smoke tests |
| Rollback if failed | Automated rollback on health check failure |

## Tracking Progress

```yaml
toil_reduction_dashboard:
  metrics:
    - name: toil_percentage
      current: 35%
      target: 25%
      trend: decreasing

    - name: tickets_automated
      current: 12
      target: 20
      trend: increasing

    - name: mean_time_to_resolve
      current: "15 min"
      previous: "45 min"
      improvement: "67%"

    - name: manual_interventions_per_week
      current: 8
      previous: 23
      improvement: "65%"
```

## Common Toil Sources and Solutions

| Toil Source | Solution | Effort |
|-------------|----------|--------|
| Manual deploys | CI/CD pipeline | Medium |
| Disk cleanup | Auto-rotation, retention policies | Low |
| Certificate renewal | cert-manager, ACME | Low |
| Capacity planning | Auto-scaling policies | Medium |
| Config changes | GitOps, self-service portal | High |
| Incident triage | Automated runbooks | High |
| Access provisioning | Self-service IAM with approval | Medium |
