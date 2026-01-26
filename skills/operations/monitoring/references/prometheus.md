---
title: Prometheus Reference
category: operations
type: reference
version: "1.0.0"
---

# Prometheus

> Part of the operations/monitoring knowledge skill

## Overview

Prometheus is the standard for metrics collection and alerting in cloud-native environments. This reference covers metric types, PromQL queries, and best practices.

## Quick Reference (80/20)

| Metric Type | Use Case |
|-------------|----------|
| Counter | Total events (requests, errors) |
| Gauge | Current values (memory, connections) |
| Histogram | Distributions (latency, size) |
| Summary | Pre-calculated percentiles |

## Patterns

### Pattern 1: Application Instrumentation

**When to Use**: Adding metrics to applications

**Example**:
```go
// metrics.go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    // Counter - total requests
    RequestsTotal = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Namespace: "myapp",
            Subsystem: "http",
            Name:      "requests_total",
            Help:      "Total number of HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )

    // Histogram - request duration
    RequestDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Namespace: "myapp",
            Subsystem: "http",
            Name:      "request_duration_seconds",
            Help:      "HTTP request duration in seconds",
            Buckets:   []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10},
        },
        []string{"method", "endpoint"},
    )

    // Gauge - active connections
    ActiveConnections = promauto.NewGauge(
        prometheus.GaugeOpts{
            Namespace: "myapp",
            Subsystem: "http",
            Name:      "active_connections",
            Help:      "Number of active HTTP connections",
        },
    )

    // Histogram - request size
    RequestSize = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Namespace: "myapp",
            Subsystem: "http",
            Name:      "request_size_bytes",
            Help:      "HTTP request size in bytes",
            Buckets:   prometheus.ExponentialBuckets(100, 10, 8), // 100B to 1GB
        },
        []string{"method", "endpoint"},
    )

    // Counter - database operations
    DBOperations = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Namespace: "myapp",
            Subsystem: "db",
            Name:      "operations_total",
            Help:      "Total database operations",
        },
        []string{"operation", "table", "status"},
    )

    // Histogram - database query duration
    DBQueryDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Namespace: "myapp",
            Subsystem: "db",
            Name:      "query_duration_seconds",
            Help:      "Database query duration in seconds",
            Buckets:   []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5},
        },
        []string{"operation", "table"},
    )

    // Gauge - connection pool
    DBPoolConnections = promauto.NewGaugeVec(
        prometheus.GaugeOpts{
            Namespace: "myapp",
            Subsystem: "db",
            Name:      "pool_connections",
            Help:      "Database connection pool status",
        },
        []string{"state"}, // active, idle, waiting
    )

    // Counter - cache operations
    CacheOperations = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Namespace: "myapp",
            Subsystem: "cache",
            Name:      "operations_total",
            Help:      "Total cache operations",
        },
        []string{"operation", "result"}, // get/set, hit/miss
    )

    // Summary - external API latency
    ExternalAPILatency = promauto.NewSummaryVec(
        prometheus.SummaryOpts{
            Namespace:  "myapp",
            Subsystem:  "external",
            Name:       "api_latency_seconds",
            Help:       "External API call latency",
            Objectives: map[float64]float64{0.5: 0.05, 0.9: 0.01, 0.99: 0.001},
        },
        []string{"service", "endpoint"},
    )
)

// Middleware for HTTP metrics
func MetricsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        ActiveConnections.Inc()
        defer ActiveConnections.Dec()

        start := time.Now()
        wrapped := &responseWriter{ResponseWriter: w, statusCode: 200}

        next.ServeHTTP(wrapped, r)

        duration := time.Since(start).Seconds()
        endpoint := normalizeEndpoint(r.URL.Path)

        RequestsTotal.WithLabelValues(
            r.Method,
            endpoint,
            strconv.Itoa(wrapped.statusCode),
        ).Inc()

        RequestDuration.WithLabelValues(
            r.Method,
            endpoint,
        ).Observe(duration)

        if r.ContentLength > 0 {
            RequestSize.WithLabelValues(
                r.Method,
                endpoint,
            ).Observe(float64(r.ContentLength))
        }
    })
}

type responseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
    rw.statusCode = code
    rw.ResponseWriter.WriteHeader(code)
}

func normalizeEndpoint(path string) string {
    // Replace IDs with placeholders for consistent cardinality
    // /users/123 -> /users/:id
    // /orders/abc-def -> /orders/:id
    patterns := []struct {
        regex       *regexp.Regexp
        replacement string
    }{
        {regexp.MustCompile(`/users/[^/]+`), "/users/:id"},
        {regexp.MustCompile(`/orders/[^/]+`), "/orders/:id"},
        {regexp.MustCompile(`/products/[^/]+`), "/products/:id"},
    }

    result := path
    for _, p := range patterns {
        result = p.regex.ReplaceAllString(result, p.replacement)
    }
    return result
}

// Database instrumentation wrapper
type InstrumentedDB struct {
    db *sql.DB
}

func (i *InstrumentedDB) Query(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
    start := time.Now()
    table := extractTable(query)
    operation := extractOperation(query)

    rows, err := i.db.QueryContext(ctx, query, args...)

    duration := time.Since(start).Seconds()
    status := "success"
    if err != nil {
        status = "error"
    }

    DBOperations.WithLabelValues(operation, table, status).Inc()
    DBQueryDuration.WithLabelValues(operation, table).Observe(duration)

    return rows, err
}

// Expose metrics endpoint
func SetupMetricsServer() {
    http.Handle("/metrics", promhttp.Handler())
    go http.ListenAndServe(":9090", nil)
}
```

**Anti-Pattern**: High-cardinality labels (user IDs, request IDs).

### Pattern 2: PromQL Queries

**When to Use**: Querying metrics

**Example**:
```promql
# Request Rate (requests per second)
rate(myapp_http_requests_total[5m])

# Request rate by endpoint
sum by (endpoint) (rate(myapp_http_requests_total[5m]))

# Error Rate (percentage)
sum(rate(myapp_http_requests_total{status=~"5.."}[5m]))
/
sum(rate(myapp_http_requests_total[5m]))
* 100

# Latency Percentiles (from histogram)
# P50
histogram_quantile(0.50, sum by (le) (rate(myapp_http_request_duration_seconds_bucket[5m])))

# P95
histogram_quantile(0.95, sum by (le) (rate(myapp_http_request_duration_seconds_bucket[5m])))

# P99
histogram_quantile(0.99, sum by (le) (rate(myapp_http_request_duration_seconds_bucket[5m])))

# P99 by endpoint
histogram_quantile(0.99,
  sum by (le, endpoint) (rate(myapp_http_request_duration_seconds_bucket[5m]))
)

# Apdex Score (satisfied < 100ms, tolerating < 500ms)
(
  sum(rate(myapp_http_request_duration_seconds_bucket{le="0.1"}[5m]))
  +
  sum(rate(myapp_http_request_duration_seconds_bucket{le="0.5"}[5m]))
) / 2
/
sum(rate(myapp_http_request_duration_seconds_count[5m]))

# Cache Hit Rate
sum(rate(myapp_cache_operations_total{result="hit"}[5m]))
/
sum(rate(myapp_cache_operations_total{operation="get"}[5m]))
* 100

# Database Connection Pool Utilization
myapp_db_pool_connections{state="active"}
/
(myapp_db_pool_connections{state="active"} + myapp_db_pool_connections{state="idle"})
* 100

# Memory Usage (container)
container_memory_usage_bytes{container="api"}
/
container_spec_memory_limit_bytes{container="api"}
* 100

# CPU Usage (container)
rate(container_cpu_usage_seconds_total{container="api"}[5m])
/
container_spec_cpu_quota{container="api"}
* container_spec_cpu_period{container="api"}
* 100

# Requests in flight
sum(myapp_http_active_connections)

# Top 5 slowest endpoints
topk(5,
  histogram_quantile(0.99,
    sum by (endpoint, le) (rate(myapp_http_request_duration_seconds_bucket[5m]))
  )
)

# Saturation - queue depth over time
avg_over_time(myapp_queue_depth[1h])

# Error budget remaining (99.9% SLO)
1 - (
  sum(increase(myapp_http_requests_total{status=~"5.."}[30d]))
  /
  sum(increase(myapp_http_requests_total[30d]))
) / 0.001

# Rate of change (derivative)
deriv(myapp_http_requests_total[5m])

# Predict value in 1 hour
predict_linear(myapp_db_disk_usage_bytes[1h], 3600)

# Absent metric (for alerting on missing data)
absent(up{job="api"})

# Changes in last hour
changes(myapp_config_version[1h])
```

**Anti-Pattern**: Complex queries without rate() for counters.

### Pattern 3: Recording Rules

**When to Use**: Pre-computing expensive queries

**Example**:
```yaml
# prometheus-rules.yaml
groups:
  - name: myapp.rules
    interval: 30s
    rules:
      # Request rate
      - record: myapp:http_requests:rate5m
        expr: sum by (endpoint, method) (rate(myapp_http_requests_total[5m]))

      # Error rate
      - record: myapp:http_errors:rate5m
        expr: |
          sum by (endpoint) (rate(myapp_http_requests_total{status=~"5.."}[5m]))
          /
          sum by (endpoint) (rate(myapp_http_requests_total[5m]))

      # Latency percentiles
      - record: myapp:http_latency:p50
        expr: |
          histogram_quantile(0.50,
            sum by (endpoint, le) (rate(myapp_http_request_duration_seconds_bucket[5m]))
          )

      - record: myapp:http_latency:p95
        expr: |
          histogram_quantile(0.95,
            sum by (endpoint, le) (rate(myapp_http_request_duration_seconds_bucket[5m]))
          )

      - record: myapp:http_latency:p99
        expr: |
          histogram_quantile(0.99,
            sum by (endpoint, le) (rate(myapp_http_request_duration_seconds_bucket[5m]))
          )

      # Availability (1 - error rate)
      - record: myapp:availability:rate5m
        expr: 1 - myapp:http_errors:rate5m

      # Cache hit rate
      - record: myapp:cache:hit_rate
        expr: |
          sum(rate(myapp_cache_operations_total{result="hit"}[5m]))
          /
          sum(rate(myapp_cache_operations_total{operation="get"}[5m]))

      # Database query rate
      - record: myapp:db:queries:rate5m
        expr: sum by (operation, table) (rate(myapp_db_operations_total[5m]))

      # Database error rate
      - record: myapp:db:errors:rate5m
        expr: |
          sum(rate(myapp_db_operations_total{status="error"}[5m]))
          /
          sum(rate(myapp_db_operations_total[5m]))

  - name: slo.rules
    interval: 1m
    rules:
      # SLO: 99.9% availability over 30 days
      - record: myapp:slo:availability:30d
        expr: |
          1 - (
            sum(increase(myapp_http_requests_total{status=~"5.."}[30d]))
            /
            sum(increase(myapp_http_requests_total[30d]))
          )

      # Error budget remaining
      - record: myapp:slo:error_budget_remaining
        expr: |
          (myapp:slo:availability:30d - 0.999) / 0.001

      # Error budget burn rate (last hour vs 30 day budget)
      - record: myapp:slo:error_budget_burn_rate:1h
        expr: |
          (
            sum(increase(myapp_http_requests_total{status=~"5.."}[1h]))
            /
            sum(increase(myapp_http_requests_total[1h]))
          )
          /
          0.001

      # SLO: P99 latency < 500ms
      - record: myapp:slo:latency_compliance:5m
        expr: |
          histogram_quantile(0.99,
            sum by (le) (rate(myapp_http_request_duration_seconds_bucket[5m]))
          ) < 0.5
```

**Anti-Pattern**: Running expensive queries in dashboards.

### Pattern 4: Service Discovery

**When to Use**: Auto-discovering scrape targets

**Example**:
```yaml
# prometheus.yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

  external_labels:
    cluster: production
    region: us-east-1

rule_files:
  - /etc/prometheus/rules/*.yaml

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

scrape_configs:
  # Kubernetes pods with prometheus.io annotations
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Only scrape pods with prometheus.io/scrape: "true"
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true

      # Use custom port if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)
        replacement: ${1}

      # Use custom path if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

      # Add pod labels
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)

      # Add namespace label
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: namespace

      # Add pod name label
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: pod

  # Kubernetes services
  - job_name: kubernetes-services
    kubernetes_sd_configs:
      - role: service
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: (.+)

  # Node exporter
  - job_name: node-exporter
    kubernetes_sd_configs:
      - role: node
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - source_labels: [__address__]
        regex: (.+):(.+)
        target_label: __address__
        replacement: ${1}:9100

  # Kubernetes API server
  - job_name: kubernetes-apiservers
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels:
          - __meta_kubernetes_namespace
          - __meta_kubernetes_service_name
          - __meta_kubernetes_endpoint_port_name
        action: keep
        regex: default;kubernetes;https

  # Static targets (external services)
  - job_name: external-databases
    static_configs:
      - targets:
          - db-primary.example.com:9187
          - db-replica.example.com:9187
    relabel_configs:
      - source_labels: [__address__]
        regex: (.+):.+
        target_label: instance

  # Blackbox exporter for endpoint probing
  - job_name: blackbox-http
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
          - https://api.example.com/health
          - https://www.example.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

**Anti-Pattern**: Hardcoded targets for dynamic infrastructure.

### Pattern 5: Histogram Design

**When to Use**: Measuring distributions

**Example**:
```go
// histogram-design.go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
)

// HTTP latency buckets optimized for web services
// Most requests < 100ms, alert on > 500ms
var HTTPLatencyBuckets = []float64{
    0.001,  // 1ms
    0.005,  // 5ms
    0.01,   // 10ms
    0.025,  // 25ms
    0.05,   // 50ms
    0.1,    // 100ms - target p50
    0.25,   // 250ms
    0.5,    // 500ms - SLO threshold
    1,      // 1s
    2.5,    // 2.5s
    5,      // 5s
    10,     // 10s - timeout
}

// Database query buckets - generally faster
var DBQueryBuckets = []float64{
    0.0001, // 0.1ms
    0.0005, // 0.5ms
    0.001,  // 1ms
    0.005,  // 5ms
    0.01,   // 10ms
    0.025,  // 25ms
    0.05,   // 50ms
    0.1,    // 100ms
    0.25,   // 250ms
    0.5,    // 500ms
    1,      // 1s
}

// File size buckets using exponential growth
var FileSizeBuckets = prometheus.ExponentialBuckets(
    1024,    // Start: 1KB
    4,       // Factor: 4x
    10,      // Count: 10 buckets
)
// Results in: 1KB, 4KB, 16KB, 64KB, 256KB, 1MB, 4MB, 16MB, 64MB, 256MB

// Queue wait time buckets
var QueueWaitBuckets = []float64{
    0.01,  // 10ms
    0.1,   // 100ms
    0.5,   // 500ms
    1,     // 1s
    5,     // 5s
    10,    // 10s
    30,    // 30s
    60,    // 1m
    300,   // 5m
    600,   // 10m
}

// Native histograms (Prometheus 2.40+)
var NativeHistogram = prometheus.NewHistogram(
    prometheus.HistogramOpts{
        Namespace:                       "myapp",
        Name:                            "request_duration_seconds",
        Help:                            "Request duration with native histograms",
        NativeHistogramBucketFactor:     1.1,
        NativeHistogramMaxBucketNumber:  100,
        NativeHistogramMinResetDuration: time.Hour,
    },
)

// Choosing bucket boundaries
//
// Guidelines:
// 1. Include your SLO threshold as a bucket boundary
// 2. Have buckets around expected p50, p95, p99
// 3. Include values where you would alert
// 4. Use 10-20 buckets (more = higher cardinality)
// 5. Consider using native histograms for automatic boundaries

// Example: Designing buckets for API with 200ms SLO
func designAPIBuckets() []float64 {
    return []float64{
        0.01,  // 10ms - very fast
        0.025, // 25ms
        0.05,  // 50ms - expected p50
        0.1,   // 100ms - expected p90
        0.15,  // 150ms
        0.2,   // 200ms - SLO threshold (p99)
        0.25,  // 250ms
        0.5,   // 500ms - concerning
        1,     // 1s - problematic
        2,     // 2s - near timeout
        5,     // 5s - timeout
    }
}

// Calculating percentiles from histograms
//
// histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
//
// Note: histogram_quantile provides approximations, not exact percentiles
// Accuracy depends on bucket boundaries
```

```promql
# Histogram queries

# Calculate P99 latency
histogram_quantile(0.99, sum by (le) (rate(myapp_request_duration_seconds_bucket[5m])))

# Calculate median (P50)
histogram_quantile(0.50, sum by (le) (rate(myapp_request_duration_seconds_bucket[5m])))

# Requests above SLO threshold (500ms)
sum(rate(myapp_request_duration_seconds_bucket{le="0.5"}[5m]))
/
sum(rate(myapp_request_duration_seconds_count[5m]))

# Average duration (from histogram)
sum(rate(myapp_request_duration_seconds_sum[5m]))
/
sum(rate(myapp_request_duration_seconds_count[5m]))

# Heatmap data for Grafana
sum by (le) (rate(myapp_request_duration_seconds_bucket[5m]))
```

**Anti-Pattern**: Too many or poorly placed bucket boundaries.

### Pattern 6: Federation and Remote Write

**When to Use**: Multi-cluster or long-term storage

**Example**:
```yaml
# Global Prometheus (federation)
# prometheus-global.yaml
global:
  scrape_interval: 1m
  evaluation_interval: 1m
  external_labels:
    env: global

scrape_configs:
  # Federate from regional Prometheus instances
  - job_name: federate-us-east
    honor_labels: true
    metrics_path: /federate
    params:
      match[]:
        - '{job=~".+"}'  # All jobs
        - 'myapp:.*'     # Recording rules
    static_configs:
      - targets:
          - prometheus-us-east.example.com:9090
    relabel_configs:
      - source_labels: [__address__]
        target_label: prometheus_cluster
        replacement: us-east

  - job_name: federate-eu-west
    honor_labels: true
    metrics_path: /federate
    params:
      match[]:
        - '{job=~".+"}'
        - 'myapp:.*'
    static_configs:
      - targets:
          - prometheus-eu-west.example.com:9090
    relabel_configs:
      - source_labels: [__address__]
        target_label: prometheus_cluster
        replacement: eu-west

# Remote write to long-term storage
# prometheus.yaml
remote_write:
  - url: https://cortex.example.com/api/v1/push
    remote_timeout: 30s
    queue_config:
      capacity: 100000
      max_shards: 50
      min_shards: 1
      max_samples_per_send: 5000
      batch_send_deadline: 5s
    write_relabel_configs:
      # Drop high-cardinality metrics
      - source_labels: [__name__]
        regex: 'go_.*'
        action: drop
      # Keep only important metrics for long-term
      - source_labels: [__name__]
        regex: '(myapp_.*|up|container_.*)'
        action: keep
    metadata_config:
      send: true
      send_interval: 1m

  # Backup to Thanos
  - url: http://thanos-receive:19291/api/v1/receive
    remote_timeout: 30s

# Remote read for querying historical data
remote_read:
  - url: https://cortex.example.com/api/v1/read
    read_recent: false
```

```yaml
# Thanos sidecar for object storage
# thanos-sidecar.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  template:
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:v2.45.0
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.path=/prometheus
            - --storage.tsdb.retention.time=2h
            - --storage.tsdb.min-block-duration=2h
            - --storage.tsdb.max-block-duration=2h
            - --web.enable-lifecycle

        - name: thanos-sidecar
          image: quay.io/thanos/thanos:v0.32.0
          args:
            - sidecar
            - --prometheus.url=http://localhost:9090
            - --tsdb.path=/prometheus
            - --objstore.config-file=/etc/thanos/bucket.yaml
            - --shipper.upload-compacted
          volumeMounts:
            - name: prometheus-data
              mountPath: /prometheus
            - name: thanos-config
              mountPath: /etc/thanos
```

**Anti-Pattern**: Single Prometheus for all environments.

## Checklist

- [ ] Appropriate metric types used
- [ ] Labels follow naming conventions
- [ ] Cardinality kept under control
- [ ] Recording rules for expensive queries
- [ ] Histogram buckets match SLOs
- [ ] Service discovery configured
- [ ] Retention configured appropriately
- [ ] High availability setup
- [ ] Federation for global view
- [ ] Long-term storage for compliance

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [PromQL Guide](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)
- [Thanos Documentation](https://thanos.io/tip/thanos/getting-started.md/)
