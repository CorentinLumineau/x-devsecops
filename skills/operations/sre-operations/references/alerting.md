---
title: Alerting Reference
category: operations
type: reference
version: "1.0.0"
---

# Alerting

> Part of the operations/monitoring knowledge skill

## Overview

Effective alerting ensures timely response to issues without alert fatigue. This reference covers alert design, routing, and best practices for actionable alerts.

## Quick Reference (80/20)

| Principle | Description |
|-----------|-------------|
| Actionable | Every alert needs a clear response |
| Urgent | Page only for things that need immediate attention |
| Symptomatic | Alert on symptoms, not causes |
| Contextual | Include enough info to start investigation |

## Patterns

### Pattern 1: Alert Rule Design

**When to Use**: Creating effective alert rules

**Example**:
```yaml
# alertmanager-rules.yaml
groups:
  - name: availability
    rules:
      # Service down - Critical
      - alert: ServiceDown
        expr: up{job="api"} == 0
        for: 1m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."
          runbook: "https://wiki.example.com/runbooks/service-down"
          dashboard: "https://grafana.example.com/d/service-health"

      # High Error Rate - Critical
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
            /
            sum(rate(http_requests_total[5m])) by (service)
          ) > 0.05
        for: 5m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }} (threshold: 5%)"
          runbook: "https://wiki.example.com/runbooks/high-error-rate"

      # High Latency - Warning
      - alert: HighLatency
        expr: |
          histogram_quantile(0.99,
            sum by (service, le) (rate(http_request_duration_seconds_bucket[5m]))
          ) > 0.5
        for: 5m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High latency on {{ $labels.service }}"
          description: "P99 latency is {{ $value | humanizeDuration }} (threshold: 500ms)"
          runbook: "https://wiki.example.com/runbooks/high-latency"

  - name: saturation
    rules:
      # High CPU Usage
      - alert: HighCPUUsage
        expr: |
          (
            rate(container_cpu_usage_seconds_total{container!="POD"}[5m])
            /
            container_spec_cpu_quota{container!="POD"}
            * container_spec_cpu_period{container!="POD"}
          ) > 0.8
        for: 10m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High CPU usage on {{ $labels.container }}"
          description: "CPU usage is {{ $value | humanizePercentage }}"

      # High Memory Usage
      - alert: HighMemoryUsage
        expr: |
          (
            container_memory_usage_bytes{container!="POD"}
            /
            container_spec_memory_limit_bytes{container!="POD"}
          ) > 0.85
        for: 10m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "High memory usage on {{ $labels.container }}"
          description: "Memory usage is {{ $value | humanizePercentage }}"

      # Disk Space Running Low
      - alert: DiskSpaceLow
        expr: |
          (
            node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}
            /
            node_filesystem_size_bytes{fstype!~"tmpfs|overlay"}
          ) < 0.1
        for: 10m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Only {{ $value | humanizePercentage }} disk space remaining on {{ $labels.mountpoint }}"

      # Disk Space Critical
      - alert: DiskSpaceCritical
        expr: |
          predict_linear(
            node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"}[6h], 24 * 3600
          ) < 0
        for: 30m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Disk will fill up in 24h on {{ $labels.instance }}"
          description: "At current rate, {{ $labels.mountpoint }} will be full within 24 hours"

  - name: database
    rules:
      # Database Connection Pool Exhaustion
      - alert: DBConnectionPoolExhausted
        expr: |
          (
            myapp_db_pool_connections{state="active"}
            /
            myapp_db_pool_connections_max
          ) > 0.9
        for: 5m
        labels:
          severity: critical
          team: backend
        annotations:
          summary: "Database connection pool nearly exhausted"
          description: "{{ $value | humanizePercentage }} of connections in use"
          runbook: "https://wiki.example.com/runbooks/db-pool-exhausted"

      # Database Replication Lag
      - alert: DBReplicationLag
        expr: mysql_slave_lag_seconds > 30
        for: 5m
        labels:
          severity: warning
          team: dba
        annotations:
          summary: "Database replication lag is high"
          description: "Replication lag is {{ $value | humanizeDuration }}"

  - name: slo
    rules:
      # SLO Error Budget Burn Rate
      - alert: ErrorBudgetBurnRateCritical
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[1h]))
            /
            sum(rate(http_requests_total[1h]))
          ) > (14.4 * 0.001)  # 14.4x burn rate = 2h to exhaust monthly budget
        for: 5m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Error budget burn rate is critical"
          description: "At current rate, error budget will be exhausted in ~2 hours"
          runbook: "https://wiki.example.com/runbooks/error-budget"

      # SLO Error Budget Burn Rate Warning
      - alert: ErrorBudgetBurnRateHigh
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[6h]))
            /
            sum(rate(http_requests_total[6h]))
          ) > (6 * 0.001)  # 6x burn rate = 5 days to exhaust monthly budget
        for: 30m
        labels:
          severity: warning
          team: platform
        annotations:
          summary: "Error budget burn rate is elevated"
          description: "At current rate, error budget will be exhausted in ~5 days"

      # SLO Latency Budget
      - alert: LatencyBudgetBurnRateHigh
        expr: |
          1 - (
            sum(rate(http_request_duration_seconds_bucket{le="0.5"}[1h]))
            /
            sum(rate(http_request_duration_seconds_count[1h]))
          ) > (14.4 * 0.001)
        for: 5m
        labels:
          severity: critical
          team: platform
        annotations:
          summary: "Latency SLO budget burning fast"
          description: "Too many requests exceeding 500ms threshold"
```

**Anti-Pattern**: Alerts without runbooks or context.

### Pattern 2: Alert Routing

**When to Use**: Directing alerts to the right people

**Example**:
```yaml
# alertmanager.yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/xxx/yyy/zzz'
  pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  # Default receiver
  receiver: slack-notifications
  group_by: ['alertname', 'service', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    # Critical alerts -> PagerDuty immediately
    - match:
        severity: critical
      receiver: pagerduty-critical
      group_wait: 10s
      repeat_interval: 1h
      continue: true  # Also send to Slack

    # Critical alerts also to Slack
    - match:
        severity: critical
      receiver: slack-critical

    # Warning alerts -> Slack only
    - match:
        severity: warning
      receiver: slack-warnings
      group_wait: 1m
      repeat_interval: 4h

    # Database alerts -> DBA team
    - match:
        team: dba
      receiver: pagerduty-dba
      routes:
        - match:
            severity: critical
          receiver: pagerduty-dba
        - match:
            severity: warning
          receiver: slack-dba

    # Security alerts -> Security team
    - match_re:
        alertname: ^(Security|Suspicious|Unauthorized).*
      receiver: pagerduty-security
      group_wait: 0s

    # Cost alerts -> Finance + Engineering
    - match:
        category: cost
      receiver: slack-cost-alerts
      repeat_interval: 24h

    # After hours -> Only critical
    - match:
        severity: critical
      receiver: pagerduty-critical
      active_time_intervals:
        - after-hours

    # Business hours -> All severities
    - receiver: slack-notifications
      active_time_intervals:
        - business-hours

time_intervals:
  - name: business-hours
    time_intervals:
      - weekdays: ['monday:friday']
        times:
          - start_time: '09:00'
            end_time: '18:00'

  - name: after-hours
    time_intervals:
      - weekdays: ['saturday', 'sunday']
      - weekdays: ['monday:friday']
        times:
          - start_time: '00:00'
            end_time: '09:00'
          - start_time: '18:00'
            end_time: '24:00'

inhibit_rules:
  # Don't alert on individual instances if service is down
  - source_match:
      alertname: ServiceDown
    target_match_re:
      alertname: (HighLatency|HighErrorRate|HighCPU).*
    equal: ['service']

  # Don't alert on child services if parent is down
  - source_match:
      alertname: ServiceDown
      service: api-gateway
    target_match:
      alertname: ServiceDown
    equal: ['cluster']

  # Warning suppressed if critical is firing
  - source_match:
      severity: critical
    target_match:
      severity: warning
    equal: ['alertname', 'service']

receivers:
  - name: pagerduty-critical
    pagerduty_configs:
      - service_key: '<pagerduty-service-key>'
        severity: critical
        description: '{{ template "pagerduty.description" . }}'
        details:
          firing: '{{ template "pagerduty.firing" . }}'
          runbook: '{{ (index .Alerts 0).Annotations.runbook }}'
          dashboard: '{{ (index .Alerts 0).Annotations.dashboard }}'

  - name: pagerduty-dba
    pagerduty_configs:
      - service_key: '<dba-pagerduty-key>'
        severity: '{{ (index .Alerts 0).Labels.severity }}'

  - name: pagerduty-security
    pagerduty_configs:
      - service_key: '<security-pagerduty-key>'
        severity: critical

  - name: slack-critical
    slack_configs:
      - channel: '#alerts-critical'
        send_resolved: true
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'
        color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
        actions:
          - type: button
            text: 'Runbook'
            url: '{{ (index .Alerts 0).Annotations.runbook }}'
          - type: button
            text: 'Dashboard'
            url: '{{ (index .Alerts 0).Annotations.dashboard }}'
          - type: button
            text: 'Silence'
            url: '{{ template "slack.silence_url" . }}'

  - name: slack-warnings
    slack_configs:
      - channel: '#alerts-warnings'
        send_resolved: true
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'
        color: 'warning'

  - name: slack-notifications
    slack_configs:
      - channel: '#alerts'
        send_resolved: true
        title: '{{ template "slack.title" . }}'
        text: '{{ template "slack.text" . }}'

  - name: slack-dba
    slack_configs:
      - channel: '#dba-alerts'
        send_resolved: true

  - name: slack-cost-alerts
    slack_configs:
      - channel: '#cloud-costs'
        send_resolved: false
```

**Anti-Pattern**: All alerts going to the same channel.

### Pattern 3: Alert Templates

**When to Use**: Consistent alert formatting

**Example**:
```yaml
# alertmanager-templates.tmpl
{{ define "slack.title" }}
[{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .GroupLabels.alertname }}
{{ end }}

{{ define "slack.text" }}
{{ range .Alerts }}
*Alert:* {{ .Labels.alertname }}
*Severity:* {{ .Labels.severity }}
*Service:* {{ .Labels.service }}
*Instance:* {{ .Labels.instance }}

*Summary:* {{ .Annotations.summary }}
*Description:* {{ .Annotations.description }}

{{ if .Annotations.runbook }}:book: <{{ .Annotations.runbook }}|Runbook>{{ end }}
{{ if .Annotations.dashboard }}:chart_with_upwards_trend: <{{ .Annotations.dashboard }}|Dashboard>{{ end }}

*Started:* {{ .StartsAt.Format "2006-01-02 15:04:05 UTC" }}
{{ if .EndsAt }}*Ended:* {{ .EndsAt.Format "2006-01-02 15:04:05 UTC" }}{{ end }}
---
{{ end }}
{{ end }}

{{ define "slack.silence_url" }}
{{ .ExternalURL }}/#/silences/new?filter=%7B
{{- range .CommonLabels.SortedPairs -}}
{{- if ne .Name "alertname" -}}
{{ .Name }}%3D%22{{ .Value }}%22%2C
{{- end -}}
{{- end -}}
alertname%3D%22{{ .CommonLabels.alertname }}%22%7D
{{ end }}

{{ define "pagerduty.description" }}
[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }} - {{ (index .Alerts 0).Annotations.summary }}
{{ end }}

{{ define "pagerduty.firing" }}
{{ range .Alerts.Firing }}
Alert: {{ .Labels.alertname }}
Service: {{ .Labels.service }}
Instance: {{ .Labels.instance }}
Description: {{ .Annotations.description }}
{{ end }}
{{ end }}

{{ define "email.subject" }}
[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}
{{ end }}

{{ define "email.html" }}
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; }
    .alert { padding: 15px; margin: 10px 0; border-radius: 4px; }
    .critical { background-color: #f8d7da; border: 1px solid #f5c6cb; }
    .warning { background-color: #fff3cd; border: 1px solid #ffeeba; }
    .resolved { background-color: #d4edda; border: 1px solid #c3e6cb; }
    .label { font-weight: bold; }
  </style>
</head>
<body>
  <h2>{{ .GroupLabels.alertname }}</h2>
  <p>Status: <strong>{{ .Status | toUpper }}</strong></p>

  {{ range .Alerts }}
  <div class="alert {{ .Labels.severity }}">
    <p><span class="label">Service:</span> {{ .Labels.service }}</p>
    <p><span class="label">Instance:</span> {{ .Labels.instance }}</p>
    <p><span class="label">Summary:</span> {{ .Annotations.summary }}</p>
    <p><span class="label">Description:</span> {{ .Annotations.description }}</p>
    <p><span class="label">Started:</span> {{ .StartsAt.Format "2006-01-02 15:04:05 UTC" }}</p>
    {{ if .Annotations.runbook }}
    <p><a href="{{ .Annotations.runbook }}">View Runbook</a></p>
    {{ end }}
  </div>
  {{ end }}
</body>
</html>
{{ end }}
```

**Anti-Pattern**: Alerts without context or links.

### Pattern 4: SLO-Based Alerting

**When to Use**: Alerting based on error budgets

**Example**:
```yaml
# slo-alerts.yaml
groups:
  - name: slo-alerts
    rules:
      # Multi-window, multi-burn-rate alerting
      # Based on Google SRE workbook recommendations

      # 2% budget consumption in 1 hour = page immediately
      - alert: SLOErrorBudgetBurn_2pct_1h
        expr: |
          (
            # Short window (5m)
            (
              sum(rate(http_requests_total{status=~"5.."}[5m]))
              /
              sum(rate(http_requests_total[5m]))
            ) > (14.4 * 0.001)  # 14.4x burn rate
            and
            # Longer window (1h) for confirmation
            (
              sum(rate(http_requests_total{status=~"5.."}[1h]))
              /
              sum(rate(http_requests_total[1h]))
            ) > (14.4 * 0.001)
          )
        for: 2m
        labels:
          severity: critical
          slo: availability
          window: 1h
          budget_consumption: 2pct
        annotations:
          summary: "Error budget burn rate critical - 2% in 1 hour"
          description: |
            Error rate is burning through error budget at 14.4x the sustainable rate.
            At this rate, the monthly error budget will be exhausted in ~2 hours.
            Current error rate: {{ $value | humanizePercentage }}
          runbook: "https://wiki.example.com/runbooks/slo-error-budget"

      # 5% budget consumption in 6 hours = page
      - alert: SLOErrorBudgetBurn_5pct_6h
        expr: |
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[30m]))
              /
              sum(rate(http_requests_total[30m]))
            ) > (6 * 0.001)  # 6x burn rate
            and
            (
              sum(rate(http_requests_total{status=~"5.."}[6h]))
              /
              sum(rate(http_requests_total[6h]))
            ) > (6 * 0.001)
          )
        for: 15m
        labels:
          severity: critical
          slo: availability
          window: 6h
          budget_consumption: 5pct
        annotations:
          summary: "Error budget burn rate high - 5% in 6 hours"
          description: |
            Error rate is burning through error budget at 6x the sustainable rate.
            At this rate, the monthly error budget will be exhausted in ~5 days.

      # 10% budget consumption in 3 days = ticket
      - alert: SLOErrorBudgetBurn_10pct_3d
        expr: |
          (
            (
              sum(rate(http_requests_total{status=~"5.."}[2h]))
              /
              sum(rate(http_requests_total[2h]))
            ) > (1 * 0.001)  # 1x burn rate (sustainable)
            and
            (
              sum(rate(http_requests_total{status=~"5.."}[3d]))
              /
              sum(rate(http_requests_total[3d]))
            ) > (1 * 0.001)
          )
        for: 1h
        labels:
          severity: warning
          slo: availability
          window: 3d
          budget_consumption: 10pct
        annotations:
          summary: "Error budget burn rate elevated"
          description: |
            Error rate is at the edge of sustainable levels.
            Consider investigating trending issues.

      # Latency SLO alerts
      - alert: SLOLatencyBudgetBurn_2pct_1h
        expr: |
          (
            # Requests exceeding 500ms SLO threshold
            1 - (
              sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
              /
              sum(rate(http_request_duration_seconds_count[5m]))
            ) > (14.4 * 0.001)
            and
            1 - (
              sum(rate(http_request_duration_seconds_bucket{le="0.5"}[1h]))
              /
              sum(rate(http_request_duration_seconds_count[1h]))
            ) > (14.4 * 0.001)
          )
        for: 2m
        labels:
          severity: critical
          slo: latency
          window: 1h
        annotations:
          summary: "Latency SLO budget burning fast"
          description: "Too many requests exceeding 500ms latency threshold"

      # Error budget exhausted
      - alert: SLOErrorBudgetExhausted
        expr: |
          (
            sum(increase(http_requests_total{status=~"5.."}[30d]))
            /
            sum(increase(http_requests_total[30d]))
          ) > 0.001  # 99.9% SLO
        labels:
          severity: critical
          slo: availability
        annotations:
          summary: "Monthly error budget exhausted"
          description: |
            The 30-day error budget has been fully consumed.
            Current 30-day error rate: {{ $value | humanizePercentage }}
            SLO target: 99.9% (0.1% error budget)
```

**Anti-Pattern**: Alerting on every error instead of error budgets.

### Pattern 5: Alert Silencing

**When to Use**: Suppressing known alerts

**Example**:
```yaml
# silence-api.ts
interface Silence {
  id?: string;
  matchers: Matcher[];
  startsAt: string;
  endsAt: string;
  createdBy: string;
  comment: string;
}

interface Matcher {
  name: string;
  value: string;
  isRegex: boolean;
  isEqual: boolean;
}

class AlertManagerClient {
  constructor(private baseUrl: string) {}

  async createSilence(silence: Silence): Promise<string> {
    const response = await fetch(`${this.baseUrl}/api/v2/silences`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(silence)
    });

    const result = await response.json();
    return result.silenceID;
  }

  async deleteSilence(silenceId: string): Promise<void> {
    await fetch(`${this.baseUrl}/api/v2/silence/${silenceId}`, {
      method: 'DELETE'
    });
  }

  async listSilences(): Promise<Silence[]> {
    const response = await fetch(`${this.baseUrl}/api/v2/silences`);
    return response.json();
  }
}

// Common silence patterns
const silencePatterns = {
  // Silence during maintenance window
  maintenance: (service: string, durationMinutes: number, author: string) => ({
    matchers: [
      { name: 'service', value: service, isRegex: false, isEqual: true }
    ],
    startsAt: new Date().toISOString(),
    endsAt: new Date(Date.now() + durationMinutes * 60 * 1000).toISOString(),
    createdBy: author,
    comment: `Maintenance window for ${service}`
  }),

  // Silence known issue
  knownIssue: (alertname: string, instance: string, ticketId: string, author: string) => ({
    matchers: [
      { name: 'alertname', value: alertname, isRegex: false, isEqual: true },
      { name: 'instance', value: instance, isRegex: false, isEqual: true }
    ],
    startsAt: new Date().toISOString(),
    endsAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(), // 7 days
    createdBy: author,
    comment: `Known issue tracked in ${ticketId}`
  }),

  // Silence during deployment
  deployment: (service: string, author: string) => ({
    matchers: [
      { name: 'service', value: service, isRegex: false, isEqual: true },
      { name: 'alertname', value: 'High.*', isRegex: true, isEqual: true }
    ],
    startsAt: new Date().toISOString(),
    endsAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(), // 30 min
    createdBy: author,
    comment: `Deployment silence for ${service}`
  })
};

// Slack command integration
async function handleSlackSilenceCommand(command: SlackCommand) {
  const [action, alertname, duration] = command.text.split(' ');

  if (action === 'create') {
    const silence = {
      matchers: [
        { name: 'alertname', value: alertname, isRegex: false, isEqual: true }
      ],
      startsAt: new Date().toISOString(),
      endsAt: new Date(Date.now() + parseDuration(duration)).toISOString(),
      createdBy: command.user_name,
      comment: `Created via Slack by ${command.user_name}`
    };

    const silenceId = await alertManagerClient.createSilence(silence);

    return {
      response_type: 'in_channel',
      text: `Created silence ${silenceId} for ${alertname} lasting ${duration}`
    };
  }

  if (action === 'list') {
    const silences = await alertManagerClient.listSilences();
    const active = silences.filter(s => new Date(s.endsAt) > new Date());

    return {
      response_type: 'ephemeral',
      text: `Active silences:\n${active.map(s =>
        `- ${s.id}: ${s.matchers.map(m => `${m.name}=${m.value}`).join(', ')} until ${s.endsAt}`
      ).join('\n')}`
    };
  }
}
```

**Anti-Pattern**: Long-running silences without review.

### Pattern 6: Alert Testing

**When to Use**: Validating alert rules

**Example**:
```yaml
# alert-tests.yaml
rule_files:
  - alerts.yaml

evaluation_interval: 1m

tests:
  # Test high error rate alert
  - interval: 1m
    input_series:
      - series: 'http_requests_total{service="api", status="500"}'
        values: '0+10x10'  # 10 requests per minute
      - series: 'http_requests_total{service="api", status="200"}'
        values: '0+90x10'  # 90 requests per minute (10% error rate)

    alert_rule_test:
      - eval_time: 5m
        alertname: HighErrorRate
        exp_alerts:
          - exp_labels:
              severity: critical
              service: api
            exp_annotations:
              summary: "High error rate on api"

  # Test service down alert
  - interval: 1m
    input_series:
      - series: 'up{job="api", instance="api-1"}'
        values: '1 1 1 0 0 0 0 0 0 0'  # Goes down at minute 3

    alert_rule_test:
      - eval_time: 5m
        alertname: ServiceDown
        exp_alerts:
          - exp_labels:
              severity: critical
              job: api
              instance: api-1

  # Test latency alert with histogram
  - interval: 1m
    input_series:
      # Create histogram buckets showing high latency
      - series: 'http_request_duration_seconds_bucket{service="api", le="0.1"}'
        values: '0+100x10'
      - series: 'http_request_duration_seconds_bucket{service="api", le="0.5"}'
        values: '0+150x10'
      - series: 'http_request_duration_seconds_bucket{service="api", le="1"}'
        values: '0+180x10'
      - series: 'http_request_duration_seconds_bucket{service="api", le="+Inf"}'
        values: '0+200x10'
      - series: 'http_request_duration_seconds_count{service="api"}'
        values: '0+200x10'

    alert_rule_test:
      - eval_time: 6m
        alertname: HighLatency
        exp_alerts:
          - exp_labels:
              severity: warning
              service: api

  # Test no alert fires when everything is healthy
  - interval: 1m
    input_series:
      - series: 'http_requests_total{service="api", status="200"}'
        values: '0+100x10'
      - series: 'http_requests_total{service="api", status="500"}'
        values: '0+1x10'  # Only 1% errors

    alert_rule_test:
      - eval_time: 10m
        alertname: HighErrorRate
        exp_alerts: []  # No alerts expected

  # Test error budget alert
  - interval: 1m
    input_series:
      - series: 'http_requests_total{status="500"}'
        values: '0+15x60'  # 15 errors per minute for 1 hour
      - series: 'http_requests_total{status="200"}'
        values: '0+985x60'  # 985 successes per minute (1.5% error rate)

    alert_rule_test:
      - eval_time: 1h
        alertname: SLOErrorBudgetBurn_2pct_1h
        exp_alerts:
          - exp_labels:
              severity: critical
              slo: availability
```

```bash
# Run alert tests
promtool test rules alert-tests.yaml

# Check alert rule syntax
promtool check rules alerts.yaml

# Lint rules
promtool check rules --lint alerts.yaml
```

**Anti-Pattern**: Untested alert rules going to production.

## Checklist

- [ ] Alerts are actionable
- [ ] Runbooks linked to alerts
- [ ] Severity levels defined
- [ ] Routing rules configured
- [ ] Inhibition rules prevent noise
- [ ] Templates provide context
- [ ] SLO-based alerts implemented
- [ ] Alert tests written
- [ ] Silencing process documented
- [ ] Regular alert review scheduled

## References

- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)
- [Google SRE Alerting](https://sre.google/sre-book/alerting-on-slos/)
- [Practical Alerting](https://landing.google.com/sre/workbook/chapters/alerting-on-slos/)
- [Alert Fatigue Prevention](https://www.pagerduty.com/resources/learn/reduce-alert-fatigue/)
