---
title: Dashboards Reference
category: operations
type: reference
version: "1.0.0"
---

# Dashboards

> Part of the operations/monitoring knowledge skill

## Overview

Dashboards provide visual insights into system health and performance. This reference covers dashboard design, layout patterns, and best practices for Grafana and similar tools.

## Quick Reference (80/20)

| Dashboard Type | Purpose |
|----------------|---------|
| Service | Individual service health |
| USE | Utilization, Saturation, Errors |
| RED | Rate, Errors, Duration |
| Business | KPIs and business metrics |
| SLO | Service level tracking |

## Patterns

### Pattern 1: RED Method Dashboard

**When to Use**: Service-oriented dashboards

**Example**:
```json
{
  "title": "API Service - RED Metrics",
  "uid": "api-red-metrics",
  "tags": ["api", "red", "service"],
  "timezone": "browser",
  "refresh": "30s",
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "templating": {
    "list": [
      {
        "name": "service",
        "type": "query",
        "query": "label_values(http_requests_total, service)",
        "current": { "text": "api", "value": "api" },
        "refresh": 2
      },
      {
        "name": "instance",
        "type": "query",
        "query": "label_values(http_requests_total{service=\"$service\"}, instance)",
        "includeAll": true,
        "multi": true,
        "refresh": 2
      }
    ]
  },
  "panels": [
    {
      "title": "Request Rate",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 0, "w": 8, "h": 8 },
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{service=\"$service\", instance=~\"$instance\"}[5m]))",
          "legendFormat": "Total"
        },
        {
          "expr": "sum by (status) (rate(http_requests_total{service=\"$service\", instance=~\"$instance\"}[5m]))",
          "legendFormat": "{{status}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "reqps",
          "custom": {
            "lineWidth": 2,
            "fillOpacity": 10
          }
        }
      }
    },
    {
      "title": "Error Rate",
      "type": "timeseries",
      "gridPos": { "x": 8, "y": 0, "w": 8, "h": 8 },
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{service=\"$service\", status=~\"5..\"}[5m])) / sum(rate(http_requests_total{service=\"$service\"}[5m])) * 100",
          "legendFormat": "Error Rate %"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "value": null, "color": "green" },
              { "value": 1, "color": "yellow" },
              { "value": 5, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "Latency Distribution",
      "type": "timeseries",
      "gridPos": { "x": 16, "y": 0, "w": 8, "h": 8 },
      "targets": [
        {
          "expr": "histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
          "legendFormat": "P50"
        },
        {
          "expr": "histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
          "legendFormat": "P95"
        },
        {
          "expr": "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
          "legendFormat": "P99"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "s",
          "custom": {
            "lineWidth": 2
          }
        }
      }
    },
    {
      "title": "Request Rate by Endpoint",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 8, "w": 12, "h": 8 },
      "targets": [
        {
          "expr": "sum by (endpoint) (rate(http_requests_total{service=\"$service\"}[5m]))",
          "legendFormat": "{{endpoint}}"
        }
      ]
    },
    {
      "title": "P99 Latency by Endpoint",
      "type": "timeseries",
      "gridPos": { "x": 12, "y": 8, "w": 12, "h": 8 },
      "targets": [
        {
          "expr": "histogram_quantile(0.99, sum by (endpoint, le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])))",
          "legendFormat": "{{endpoint}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "s"
        }
      }
    },
    {
      "title": "Status Code Distribution",
      "type": "piechart",
      "gridPos": { "x": 0, "y": 16, "w": 6, "h": 8 },
      "targets": [
        {
          "expr": "sum by (status) (increase(http_requests_total{service=\"$service\"}[1h]))",
          "legendFormat": "{{status}}"
        }
      ]
    },
    {
      "title": "Top 5 Slowest Endpoints",
      "type": "table",
      "gridPos": { "x": 6, "y": 16, "w": 9, "h": 8 },
      "targets": [
        {
          "expr": "topk(5, histogram_quantile(0.99, sum by (endpoint, le) (rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m]))))",
          "format": "table",
          "instant": true
        }
      ],
      "transformations": [
        {
          "id": "organize",
          "options": {
            "excludeByName": { "Time": true },
            "renameByName": { "endpoint": "Endpoint", "Value": "P99 Latency (s)" }
          }
        }
      ]
    },
    {
      "title": "Active Connections",
      "type": "stat",
      "gridPos": { "x": 15, "y": 16, "w": 3, "h": 4 },
      "targets": [
        {
          "expr": "sum(http_active_connections{service=\"$service\"})",
          "legendFormat": "Connections"
        }
      ]
    },
    {
      "title": "Requests/sec",
      "type": "stat",
      "gridPos": { "x": 18, "y": 16, "w": 3, "h": 4 },
      "targets": [
        {
          "expr": "sum(rate(http_requests_total{service=\"$service\"}[5m]))",
          "legendFormat": "RPS"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "reqps"
        }
      }
    },
    {
      "title": "Error Count (1h)",
      "type": "stat",
      "gridPos": { "x": 21, "y": 16, "w": 3, "h": 4 },
      "targets": [
        {
          "expr": "sum(increase(http_requests_total{service=\"$service\", status=~\"5..\"}[1h]))",
          "legendFormat": "Errors"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              { "value": null, "color": "green" },
              { "value": 10, "color": "yellow" },
              { "value": 100, "color": "red" }
            ]
          }
        }
      }
    }
  ]
}
```

**Anti-Pattern**: Dashboards without variable templates.

### Pattern 2: USE Method Dashboard

**When to Use**: Resource-focused dashboards

**Example**:
```json
{
  "title": "Infrastructure - USE Metrics",
  "uid": "infra-use-metrics",
  "panels": [
    {
      "title": "CPU Utilization",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 0, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "legendFormat": "{{instance}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "max": 100,
          "thresholds": {
            "steps": [
              { "value": null, "color": "green" },
              { "value": 70, "color": "yellow" },
              { "value": 90, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "CPU Saturation (Load Average)",
      "type": "timeseries",
      "gridPos": { "x": 8, "y": 0, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "node_load1 / count without (cpu, mode) (node_cpu_seconds_total{mode=\"idle\"})",
          "legendFormat": "{{instance}} - 1m"
        },
        {
          "expr": "node_load5 / count without (cpu, mode) (node_cpu_seconds_total{mode=\"idle\"})",
          "legendFormat": "{{instance}} - 5m"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              { "value": null, "color": "green" },
              { "value": 1, "color": "yellow" },
              { "value": 2, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "CPU Errors",
      "type": "stat",
      "gridPos": { "x": 16, "y": 0, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "sum(increase(node_cpu_core_throttles_total[1h]))",
          "legendFormat": "Throttles"
        }
      ]
    },
    {
      "title": "Memory Utilization",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 6, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100",
          "legendFormat": "{{instance}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "max": 100
        }
      }
    },
    {
      "title": "Memory Saturation (Swap)",
      "type": "timeseries",
      "gridPos": { "x": 8, "y": 6, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "rate(node_vmstat_pswpin[5m]) + rate(node_vmstat_pswpout[5m])",
          "legendFormat": "{{instance}} - Swap I/O"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "ops"
        }
      }
    },
    {
      "title": "Memory Errors (OOM Kills)",
      "type": "stat",
      "gridPos": { "x": 16, "y": 6, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "sum(increase(node_vmstat_oom_kill[1h]))",
          "legendFormat": "OOM Kills"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "thresholds": {
            "steps": [
              { "value": null, "color": "green" },
              { "value": 1, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "Disk Utilization",
      "type": "gauge",
      "gridPos": { "x": 0, "y": 12, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "100 - (node_filesystem_avail_bytes{fstype!~\"tmpfs|overlay\"} / node_filesystem_size_bytes{fstype!~\"tmpfs|overlay\"}) * 100",
          "legendFormat": "{{instance}} - {{mountpoint}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "max": 100,
          "thresholds": {
            "steps": [
              { "value": null, "color": "green" },
              { "value": 70, "color": "yellow" },
              { "value": 90, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "Disk I/O Saturation",
      "type": "timeseries",
      "gridPos": { "x": 8, "y": 12, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "rate(node_disk_io_time_weighted_seconds_total[5m])",
          "legendFormat": "{{instance}} - {{device}}"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percentunit"
        }
      }
    },
    {
      "title": "Disk Errors",
      "type": "stat",
      "gridPos": { "x": 16, "y": 12, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "sum(increase(node_disk_io_time_seconds_total{result=\"error\"}[1h]))",
          "legendFormat": "I/O Errors"
        }
      ]
    },
    {
      "title": "Network Utilization",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 18, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "rate(node_network_receive_bytes_total{device!~\"lo|veth.*\"}[5m]) * 8",
          "legendFormat": "{{instance}} - {{device}} RX"
        },
        {
          "expr": "rate(node_network_transmit_bytes_total{device!~\"lo|veth.*\"}[5m]) * 8",
          "legendFormat": "{{instance}} - {{device}} TX"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "bps"
        }
      }
    },
    {
      "title": "Network Saturation (Drops)",
      "type": "timeseries",
      "gridPos": { "x": 8, "y": 18, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "rate(node_network_receive_drop_total[5m])",
          "legendFormat": "{{instance}} - {{device}} RX drops"
        },
        {
          "expr": "rate(node_network_transmit_drop_total[5m])",
          "legendFormat": "{{instance}} - {{device}} TX drops"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "pps"
        }
      }
    },
    {
      "title": "Network Errors",
      "type": "stat",
      "gridPos": { "x": 16, "y": 18, "w": 8, "h": 6 },
      "targets": [
        {
          "expr": "sum(increase(node_network_receive_errs_total[1h]) + increase(node_network_transmit_errs_total[1h]))",
          "legendFormat": "Network Errors"
        }
      ]
    }
  ]
}
```

**Anti-Pattern**: Metrics without thresholds or context.

### Pattern 3: SLO Dashboard

**When to Use**: Tracking service level objectives

**Example**:
```json
{
  "title": "SLO Dashboard",
  "uid": "slo-dashboard",
  "panels": [
    {
      "title": "Availability SLO (99.9%)",
      "type": "gauge",
      "gridPos": { "x": 0, "y": 0, "w": 6, "h": 6 },
      "targets": [
        {
          "expr": "(1 - sum(increase(http_requests_total{status=~\"5..\"}[30d])) / sum(increase(http_requests_total[30d]))) * 100",
          "legendFormat": "Availability"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "min": 99,
          "max": 100,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "value": null, "color": "red" },
              { "value": 99.9, "color": "yellow" },
              { "value": 99.95, "color": "green" }
            ]
          }
        }
      },
      "options": {
        "showThresholdLabels": true,
        "showThresholdMarkers": true
      }
    },
    {
      "title": "Error Budget Remaining",
      "type": "gauge",
      "gridPos": { "x": 6, "y": 0, "w": 6, "h": 6 },
      "targets": [
        {
          "expr": "((1 - sum(increase(http_requests_total{status=~\"5..\"}[30d])) / sum(increase(http_requests_total[30d]))) - 0.999) / 0.001 * 100",
          "legendFormat": "Budget"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "min": 0,
          "max": 100,
          "thresholds": {
            "steps": [
              { "value": null, "color": "red" },
              { "value": 25, "color": "yellow" },
              { "value": 50, "color": "green" }
            ]
          }
        }
      }
    },
    {
      "title": "Error Budget Burn Rate",
      "type": "timeseries",
      "gridPos": { "x": 12, "y": 0, "w": 12, "h": 6 },
      "targets": [
        {
          "expr": "(sum(rate(http_requests_total{status=~\"5..\"}[1h])) / sum(rate(http_requests_total[1h]))) / 0.001",
          "legendFormat": "Burn Rate (1h)"
        },
        {
          "expr": "(sum(rate(http_requests_total{status=~\"5..\"}[6h])) / sum(rate(http_requests_total[6h]))) / 0.001",
          "legendFormat": "Burn Rate (6h)"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "custom": {
            "thresholdsStyle": {
              "mode": "line"
            }
          },
          "thresholds": {
            "steps": [
              { "value": 1, "color": "green" },
              { "value": 6, "color": "yellow" },
              { "value": 14.4, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "Latency SLO (P99 < 500ms)",
      "type": "gauge",
      "gridPos": { "x": 0, "y": 6, "w": 6, "h": 6 },
      "targets": [
        {
          "expr": "sum(rate(http_request_duration_seconds_bucket{le=\"0.5\"}[30d])) / sum(rate(http_request_duration_seconds_count[30d])) * 100",
          "legendFormat": "Within SLO"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "min": 99,
          "max": 100,
          "thresholds": {
            "steps": [
              { "value": null, "color": "red" },
              { "value": 99.9, "color": "yellow" },
              { "value": 99.95, "color": "green" }
            ]
          }
        }
      }
    },
    {
      "title": "P99 Latency Over Time",
      "type": "timeseries",
      "gridPos": { "x": 6, "y": 6, "w": 18, "h": 6 },
      "targets": [
        {
          "expr": "histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))",
          "legendFormat": "P99 Latency"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "s",
          "custom": {
            "thresholdsStyle": {
              "mode": "line"
            }
          },
          "thresholds": {
            "steps": [
              { "value": null, "color": "green" },
              { "value": 0.5, "color": "red" }
            ]
          }
        }
      }
    },
    {
      "title": "Error Budget Consumption (30 days)",
      "type": "timeseries",
      "gridPos": { "x": 0, "y": 12, "w": 24, "h": 8 },
      "targets": [
        {
          "expr": "(1 - (sum(increase(http_requests_total{status=~\"5..\"}[$__range])) / sum(increase(http_requests_total[$__range])) - 0.999) / 0.001) * 100",
          "legendFormat": "Budget Consumed %"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "percent",
          "custom": {
            "fillOpacity": 20
          }
        }
      }
    },
    {
      "title": "SLO Status",
      "type": "stat",
      "gridPos": { "x": 0, "y": 20, "w": 8, "h": 4 },
      "targets": [
        {
          "expr": "(1 - sum(increase(http_requests_total{status=~\"5..\"}[30d])) / sum(increase(http_requests_total[30d]))) >= 0.999",
          "legendFormat": "Availability"
        }
      ],
      "options": {
        "textMode": "value_and_name",
        "colorMode": "background"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [
            { "type": "value", "options": { "0": { "text": "NOT MET", "color": "red" } } },
            { "type": "value", "options": { "1": { "text": "MET", "color": "green" } } }
          ]
        }
      }
    },
    {
      "title": "Days Until Budget Exhausted",
      "type": "stat",
      "gridPos": { "x": 8, "y": 20, "w": 8, "h": 4 },
      "targets": [
        {
          "expr": "((0.999 - (1 - sum(increase(http_requests_total{status=~\"5..\"}[30d])) / sum(increase(http_requests_total[30d])))) / 0.001) * 30 / ((sum(rate(http_requests_total{status=~\"5..\"}[1h])) / sum(rate(http_requests_total[1h]))) / 0.001)",
          "legendFormat": "Days"
        }
      ],
      "fieldConfig": {
        "defaults": {
          "unit": "d",
          "thresholds": {
            "steps": [
              { "value": null, "color": "red" },
              { "value": 7, "color": "yellow" },
              { "value": 14, "color": "green" }
            ]
          }
        }
      }
    }
  ]
}
```

**Anti-Pattern**: SLO dashboards without budget visualization.

### Pattern 4: Incident Dashboard

**When to Use**: During active incidents

**Example**:
```typescript
// incident-dashboard-generator.ts
interface IncidentDashboardConfig {
  incidentId: string;
  affectedServices: string[];
  startTime: Date;
  alertName?: string;
}

class IncidentDashboardGenerator {
  generateDashboard(config: IncidentDashboardConfig): GrafanaDashboard {
    const timeRange = {
      from: new Date(config.startTime.getTime() - 15 * 60 * 1000).toISOString(),
      to: 'now'
    };

    return {
      title: `Incident ${config.incidentId} Dashboard`,
      uid: `incident-${config.incidentId}`,
      tags: ['incident', config.incidentId],
      time: { from: timeRange.from, to: timeRange.to },
      refresh: '10s',
      annotations: {
        list: [
          {
            name: 'Deployments',
            datasource: 'Prometheus',
            expr: 'changes(deployment_timestamp{service=~"' + config.affectedServices.join('|') + '"}[5m]) > 0',
            tagKeys: 'service,version',
            titleFormat: 'Deployment: {{service}}'
          },
          {
            name: 'Incident Start',
            datasource: '-- Grafana --',
            type: 'dashboard',
            time: config.startTime.toISOString()
          }
        ]
      },
      panels: [
        // Row 1: Key Metrics
        {
          title: 'Error Rate',
          type: 'timeseries',
          gridPos: { x: 0, y: 0, w: 8, h: 8 },
          targets: config.affectedServices.map(svc => ({
            expr: `sum(rate(http_requests_total{service="${svc}", status=~"5.."}[1m])) / sum(rate(http_requests_total{service="${svc}"}[1m])) * 100`,
            legendFormat: `${svc} Error %`
          })),
          alert: {
            name: 'Error Rate Spike',
            conditions: [
              { type: 'query', evaluator: { type: 'gt', params: [5] } }
            ]
          }
        },
        {
          title: 'Request Latency (P99)',
          type: 'timeseries',
          gridPos: { x: 8, y: 0, w: 8, h: 8 },
          targets: config.affectedServices.map(svc => ({
            expr: `histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service="${svc}"}[1m])))`,
            legendFormat: `${svc} P99`
          }))
        },
        {
          title: 'Request Rate',
          type: 'timeseries',
          gridPos: { x: 16, y: 0, w: 8, h: 8 },
          targets: config.affectedServices.map(svc => ({
            expr: `sum(rate(http_requests_total{service="${svc}"}[1m]))`,
            legendFormat: `${svc} RPS`
          }))
        },

        // Row 2: Resource Utilization
        {
          title: 'CPU Usage',
          type: 'timeseries',
          gridPos: { x: 0, y: 8, w: 8, h: 6 },
          targets: config.affectedServices.map(svc => ({
            expr: `avg(rate(container_cpu_usage_seconds_total{container="${svc}"}[1m])) * 100`,
            legendFormat: `${svc}`
          }))
        },
        {
          title: 'Memory Usage',
          type: 'timeseries',
          gridPos: { x: 8, y: 8, w: 8, h: 6 },
          targets: config.affectedServices.map(svc => ({
            expr: `avg(container_memory_usage_bytes{container="${svc}"}) / avg(container_spec_memory_limit_bytes{container="${svc}"}) * 100`,
            legendFormat: `${svc}`
          }))
        },
        {
          title: 'Pod Status',
          type: 'table',
          gridPos: { x: 16, y: 8, w: 8, h: 6 },
          targets: [{
            expr: `kube_pod_status_phase{namespace="production", pod=~"(${config.affectedServices.join('|')}).*"}`,
            format: 'table',
            instant: true
          }]
        },

        // Row 3: Dependencies
        {
          title: 'Database Latency',
          type: 'timeseries',
          gridPos: { x: 0, y: 14, w: 12, h: 6 },
          targets: [{
            expr: `histogram_quantile(0.99, sum by (le) (rate(db_query_duration_seconds_bucket[1m])))`,
            legendFormat: 'P99'
          }]
        },
        {
          title: 'Cache Hit Rate',
          type: 'timeseries',
          gridPos: { x: 12, y: 14, w: 12, h: 6 },
          targets: [{
            expr: 'sum(rate(cache_hits_total[1m])) / sum(rate(cache_requests_total[1m])) * 100',
            legendFormat: 'Hit Rate %'
          }]
        },

        // Row 4: Logs
        {
          title: 'Error Logs',
          type: 'logs',
          gridPos: { x: 0, y: 20, w: 24, h: 8 },
          targets: [{
            datasource: 'Loki',
            expr: `{service=~"${config.affectedServices.join('|')}"} |= "error" or |= "Error" or |= "ERROR"`,
            refId: 'A'
          }],
          options: {
            showTime: true,
            showLabels: true,
            wrapLogMessage: true
          }
        }
      ]
    };
  }

  async createAndOpen(config: IncidentDashboardConfig): Promise<string> {
    const dashboard = this.generateDashboard(config);

    // Create dashboard via Grafana API
    const response = await fetch(`${GRAFANA_URL}/api/dashboards/db`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${GRAFANA_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        dashboard,
        overwrite: true,
        folderId: INCIDENT_FOLDER_ID
      })
    });

    const result = await response.json();
    return `${GRAFANA_URL}${result.url}?from=${dashboard.time.from}&to=${dashboard.time.to}`;
  }
}

// Usage during incident
const generator = new IncidentDashboardGenerator();
const dashboardUrl = await generator.createAndOpen({
  incidentId: 'INC-2024-001',
  affectedServices: ['api-gateway', 'user-service', 'order-service'],
  startTime: new Date('2024-01-15T14:00:00Z'),
  alertName: 'HighErrorRate'
});

console.log(`Incident dashboard: ${dashboardUrl}`);
```

**Anti-Pattern**: Using generic dashboards during incidents.

### Pattern 5: Dashboard as Code

**When to Use**: Version-controlled dashboards

**Example**:
```typescript
// dashboard-builder.ts
import { Dashboard, Panel, Target } from 'grafana-dash-gen';

class DashboardBuilder {
  private panels: Panel[] = [];
  private row = 0;

  addRow(title: string): this {
    this.panels.push({
      type: 'row',
      title,
      gridPos: { x: 0, y: this.row, w: 24, h: 1 }
    });
    this.row += 1;
    return this;
  }

  addTimeseries(config: {
    title: string;
    query: string | string[];
    width?: number;
    unit?: string;
    thresholds?: { value: number; color: string }[];
  }): this {
    const queries = Array.isArray(config.query) ? config.query : [config.query];
    const width = config.width ?? 12;

    this.panels.push({
      type: 'timeseries',
      title: config.title,
      gridPos: { x: this.getNextX(width), y: this.row, w: width, h: 8 },
      targets: queries.map((q, i) => ({
        expr: q,
        legendFormat: `{{${this.extractLabels(q)[0] ?? 'instance'}}}`
      })),
      fieldConfig: {
        defaults: {
          unit: config.unit,
          thresholds: config.thresholds ? {
            mode: 'absolute',
            steps: config.thresholds.map(t => ({ value: t.value, color: t.color }))
          } : undefined
        }
      }
    });

    return this;
  }

  addGauge(config: {
    title: string;
    query: string;
    width?: number;
    min?: number;
    max?: number;
    unit?: string;
    thresholds: { value: number; color: string }[];
  }): this {
    const width = config.width ?? 6;

    this.panels.push({
      type: 'gauge',
      title: config.title,
      gridPos: { x: this.getNextX(width), y: this.row, w: width, h: 6 },
      targets: [{ expr: config.query }],
      fieldConfig: {
        defaults: {
          min: config.min ?? 0,
          max: config.max ?? 100,
          unit: config.unit ?? 'percent',
          thresholds: {
            mode: 'absolute',
            steps: config.thresholds.map(t => ({ value: t.value, color: t.color }))
          }
        }
      }
    });

    return this;
  }

  addStat(config: {
    title: string;
    query: string;
    width?: number;
    unit?: string;
    colorMode?: 'background' | 'value';
  }): this {
    const width = config.width ?? 4;

    this.panels.push({
      type: 'stat',
      title: config.title,
      gridPos: { x: this.getNextX(width), y: this.row, w: width, h: 4 },
      targets: [{ expr: config.query }],
      fieldConfig: {
        defaults: { unit: config.unit }
      },
      options: {
        colorMode: config.colorMode ?? 'value'
      }
    });

    return this;
  }

  addTable(config: {
    title: string;
    query: string;
    width?: number;
    columns?: { name: string; displayName: string }[];
  }): this {
    const width = config.width ?? 12;

    this.panels.push({
      type: 'table',
      title: config.title,
      gridPos: { x: this.getNextX(width), y: this.row, w: width, h: 8 },
      targets: [{ expr: config.query, format: 'table', instant: true }],
      transformations: config.columns ? [{
        id: 'organize',
        options: {
          renameByName: Object.fromEntries(
            config.columns.map(c => [c.name, c.displayName])
          )
        }
      }] : []
    });

    return this;
  }

  nextRow(): this {
    this.row += 8;
    return this;
  }

  build(config: {
    title: string;
    uid: string;
    tags?: string[];
    variables?: Variable[];
  }): Dashboard {
    return {
      title: config.title,
      uid: config.uid,
      tags: config.tags ?? [],
      timezone: 'browser',
      refresh: '30s',
      time: { from: 'now-1h', to: 'now' },
      templating: {
        list: config.variables ?? []
      },
      panels: this.panels
    };
  }

  private currentX = 0;

  private getNextX(width: number): number {
    if (this.currentX + width > 24) {
      this.row += 8;
      this.currentX = 0;
    }
    const x = this.currentX;
    this.currentX += width;
    return x;
  }

  private extractLabels(query: string): string[] {
    const matches = query.match(/\{([^}]+)\}/);
    if (!matches) return [];
    return matches[1].split(',').map(l => l.split('=')[0].trim());
  }
}

// Example usage
const dashboard = new DashboardBuilder()
  .addRow('Overview')
  .addStat({ title: 'RPS', query: 'sum(rate(http_requests_total[5m]))', unit: 'reqps' })
  .addStat({ title: 'Error Rate', query: 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100', unit: 'percent' })
  .addStat({ title: 'P99 Latency', query: 'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))', unit: 's' })
  .addStat({ title: 'Active', query: 'sum(up{job="api"})', colorMode: 'background' })

  .addRow('Traffic')
  .addTimeseries({ title: 'Request Rate', query: 'sum by (endpoint) (rate(http_requests_total[5m]))', width: 12 })
  .addTimeseries({ title: 'Error Rate', query: 'sum by (endpoint) (rate(http_requests_total{status=~"5.."}[5m]))', width: 12 })

  .nextRow()
  .addRow('Latency')
  .addTimeseries({
    title: 'Latency Percentiles',
    query: [
      'histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))',
      'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))',
      'histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))'
    ],
    unit: 's',
    width: 24
  })

  .build({
    title: 'API Service Dashboard',
    uid: 'api-service',
    tags: ['api', 'service'],
    variables: [
      { name: 'instance', type: 'query', query: 'label_values(http_requests_total, instance)', multi: true }
    ]
  });

// Export to JSON for Grafana provisioning
fs.writeFileSync('dashboards/api-service.json', JSON.stringify(dashboard, null, 2));
```

**Anti-Pattern**: Manual dashboard creation without version control.

## Checklist

- [ ] Dashboards have clear purpose
- [ ] Variables enable filtering
- [ ] Appropriate visualizations used
- [ ] Thresholds configured
- [ ] Links to related dashboards
- [ ] Annotations for deployments
- [ ] Reasonable refresh rates
- [ ] Dashboard as code versioned
- [ ] Mobile-friendly layout
- [ ] Documentation in dashboard

## References

- [Grafana Documentation](https://grafana.com/docs/)
- [RED Method](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/)
- [USE Method](https://www.brendangregg.com/usemethod.html)
- [Dashboard Best Practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
