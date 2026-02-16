---
title: Performance Baselines Reference
category: quality
type: reference
version: "1.0.0"
---

# Performance Baselines

> Part of the quality/load-testing knowledge skill

## Overview

Performance baselines establish expected behavior under known conditions. They enable regression detection, capacity planning, and SLO definition. Without baselines, performance testing produces data but no actionable insights.

## Quick Reference (80/20)

| Baseline Type | What It Measures | Update Frequency |
|---------------|-----------------|------------------|
| Response time | p50, p95, p99 per endpoint | Per release |
| Throughput | Max RPS at acceptable latency | Monthly |
| Resource utilization | CPU, memory, disk at load | Per infra change |
| Error rate | Failures under normal load | Per release |
| Saturation point | Load level where SLOs break | Quarterly |

## Patterns

### Pattern 1: Establishing Response Time Baselines

**When to Use**: First-time baseline creation or after major changes

**Example**:
```javascript
// baseline-capture.js - k6 script to capture baselines
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

// Per-endpoint metrics
const endpoints = {
  listProducts: new Trend('baseline_list_products_duration'),
  getProduct: new Trend('baseline_get_product_duration'),
  createOrder: new Trend('baseline_create_order_duration'),
  search: new Trend('baseline_search_duration'),
};

export const options = {
  scenarios: {
    baseline: {
      executor: 'constant-vus',
      vus: 20,             // Known steady-state load
      duration: '10m',     // Long enough for stable measurements
    },
  },
  // No thresholds during baseline capture - we are measuring, not asserting
};

const BASE = __ENV.BASE_URL;

export default function () {
  // List products
  const list = http.get(`${BASE}/api/products`);
  endpoints.listProducts.add(list.timings.duration);
  check(list, { 'list 200': (r) => r.status === 200 });
  sleep(1);

  // Get single product
  const get = http.get(`${BASE}/api/products/1`);
  endpoints.getProduct.add(get.timings.duration);
  check(get, { 'get 200': (r) => r.status === 200 });
  sleep(1);

  // Create order
  const create = http.post(`${BASE}/api/orders`, JSON.stringify({
    product_id: 'prod_001',
    quantity: 1,
  }), { headers: { 'Content-Type': 'application/json' } });
  endpoints.createOrder.add(create.timings.duration);
  sleep(1);

  // Search
  const search = http.get(`${BASE}/api/search?q=widget`);
  endpoints.search.add(search.timings.duration);
  sleep(2);
}

export function handleSummary(data) {
  // Export baselines as JSON for future comparisons
  const baselines = {};
  for (const [name, metric] of Object.entries(data.metrics)) {
    if (name.startsWith('baseline_')) {
      baselines[name] = {
        p50: metric.values['p(50)'],
        p95: metric.values['p(95)'],
        p99: metric.values['p(99)'],
        avg: metric.values.avg,
        min: metric.values.min,
        max: metric.values.max,
      };
    }
  }

  return {
    'baselines.json': JSON.stringify(baselines, null, 2),
    stdout: textSummary(data),
  };
}
```

```json
// baselines.json - example output
{
  "baseline_list_products_duration": {
    "p50": 45.2,
    "p95": 120.5,
    "p99": 250.3,
    "avg": 62.1,
    "min": 12.0,
    "max": 890.0
  },
  "baseline_get_product_duration": {
    "p50": 22.1,
    "p95": 65.3,
    "p99": 130.8,
    "avg": 30.5,
    "min": 8.0,
    "max": 450.0
  },
  "baseline_create_order_duration": {
    "p50": 85.4,
    "p95": 210.7,
    "p99": 450.2,
    "avg": 105.3,
    "min": 35.0,
    "max": 1200.0
  },
  "baseline_search_duration": {
    "p50": 120.3,
    "p95": 350.8,
    "p99": 680.5,
    "avg": 155.2,
    "min": 45.0,
    "max": 2100.0
  }
}
```

**Anti-Pattern**: Capturing baselines during unusual conditions (deployments, maintenance windows, traffic spikes).

### Pattern 2: Regression Detection with Baselines

**When to Use**: Comparing current performance against established baselines

**Example**:
```javascript
// regression-test.js - Uses baselines for thresholds
import http from 'k6/http';
import { check, sleep } from 'k6';

// Load baselines from previous capture
const baselines = JSON.parse(open('./baselines.json'));

// Allow 20% degradation before failing
const TOLERANCE = 1.2;

export const options = {
  scenarios: {
    regression: {
      executor: 'constant-vus',
      vus: 20,          // Same as baseline capture
      duration: '5m',
    },
  },
  thresholds: {
    'http_req_duration{name:ListProducts}': [
      `p(95)<${baselines.baseline_list_products_duration.p95 * TOLERANCE}`,
    ],
    'http_req_duration{name:GetProduct}': [
      `p(95)<${baselines.baseline_get_product_duration.p95 * TOLERANCE}`,
    ],
    'http_req_duration{name:CreateOrder}': [
      `p(95)<${baselines.baseline_create_order_duration.p95 * TOLERANCE}`,
    ],
    'http_req_duration{name:Search}': [
      `p(95)<${baselines.baseline_search_duration.p95 * TOLERANCE}`,
    ],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE = __ENV.BASE_URL;

export default function () {
  http.get(`${BASE}/api/products`, { tags: { name: 'ListProducts' } });
  sleep(1);

  http.get(`${BASE}/api/products/1`, { tags: { name: 'GetProduct' } });
  sleep(1);

  http.post(`${BASE}/api/orders`, JSON.stringify({
    product_id: 'prod_001', quantity: 1,
  }), {
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'CreateOrder' },
  });
  sleep(1);

  http.get(`${BASE}/api/search?q=widget`, { tags: { name: 'Search' } });
  sleep(2);
}
```

**Anti-Pattern**: Using absolute thresholds that do not adapt as the system evolves.

### Pattern 3: Capacity Planning Baselines

**When to Use**: Determining infrastructure scaling needs

**Example**:
```markdown
## Capacity Planning Template

### Current Baseline (captured: 2026-01-28)

| Metric | Value | Condition |
|--------|-------|-----------|
| Max sustainable RPS | 850 | p95 < 500ms |
| Breaking point RPS | 1,200 | Error rate > 1% |
| CPU at max RPS | 72% | 4 vCPU instances |
| Memory at max RPS | 3.2 GB | 4 GB allocated |
| DB connections at max | 45 | Pool size: 50 |

### Growth Projections

| Timeline | Expected RPS | Infrastructure Needed |
|----------|--------------|-----------------------|
| Current | 400 | 2x instances |
| +3 months | 600 | 3x instances |
| +6 months | 900 | 4x instances + DB upgrade |
| +12 months | 1,500 | Horizontal scaling redesign |

### Scaling Decision Points

| Trigger | Action |
|---------|--------|
| CPU > 70% sustained | Add instance |
| p95 > 400ms | Investigate bottleneck |
| DB connections > 80% pool | Increase pool or add read replica |
| Error rate > 0.5% | Immediate investigation |
```

```python
# capacity_report.py - Generate capacity report from k6 results
import json
from datetime import datetime

def generate_capacity_report(
    results_file: str,
    instance_count: int,
    instance_type: str,
) -> dict:
    with open(results_file) as f:
        results = json.load(f)

    metrics = results.get("metrics", {})
    http_reqs = metrics.get("http_reqs", {})
    http_duration = metrics.get("http_req_duration", {})
    http_failed = metrics.get("http_req_failed", {})

    report = {
        "timestamp": datetime.now().isoformat(),
        "infrastructure": {
            "instance_count": instance_count,
            "instance_type": instance_type,
        },
        "performance": {
            "total_requests": http_reqs.get("values", {}).get("count", 0),
            "rps": http_reqs.get("values", {}).get("rate", 0),
            "p50_ms": http_duration.get("values", {}).get("p(50)", 0),
            "p95_ms": http_duration.get("values", {}).get("p(95)", 0),
            "p99_ms": http_duration.get("values", {}).get("p(99)", 0),
            "error_rate": http_failed.get("values", {}).get("rate", 0),
        },
        "headroom": {
            "rps_to_p95_slo": "calculate based on stress test",
            "estimated_max_rps": "from breakpoint test",
        },
    }

    return report
```

**Anti-Pattern**: Planning capacity based on average metrics instead of percentiles.

### Pattern 4: SLO-Driven Baselines

**When to Use**: Defining performance budgets aligned with business objectives

**Example**:
```yaml
# slo-baselines.yaml
service: order-api
version: "2.1.0"
captured: "2026-01-28"

slos:
  availability:
    target: 99.9%
    window: 30d
    current: 99.95%
    error_budget_remaining: 50%

  latency:
    - name: fast-endpoints
      endpoints: ["/health", "/api/products", "/api/products/:id"]
      p95_target: 200ms
      p99_target: 500ms
      current_p95: 85ms
      current_p99: 210ms
      headroom: 57%  # (200 - 85) / 200

    - name: write-endpoints
      endpoints: ["/api/orders", "/api/cart"]
      p95_target: 500ms
      p99_target: 1000ms
      current_p95: 210ms
      current_p99: 450ms
      headroom: 58%

  throughput:
    target_rps: 500
    current_max: 850
    headroom: 41%

baselines:
  infrastructure:
    instances: 3
    instance_type: "c5.xlarge"
    database: "db.r5.large"
    cache: "cache.m5.large"

  load_profile:
    peak_rps: 400
    avg_rps: 150
    peak_concurrent_users: 2000
    avg_concurrent_users: 500
```

**Anti-Pattern**: Setting SLOs without measuring current baselines first.

### Pattern 5: Trend Tracking

**When to Use**: Monitoring performance over time across releases

**Example**:
```python
# track_trends.py - Store and compare baselines over time
import json
import sqlite3
from datetime import datetime

class BaselineTracker:
    def __init__(self, db_path: str = "baselines.db"):
        self.conn = sqlite3.connect(db_path)
        self._init_db()

    def _init_db(self):
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS baselines (
                id INTEGER PRIMARY KEY,
                endpoint TEXT NOT NULL,
                version TEXT NOT NULL,
                captured_at TIMESTAMP NOT NULL,
                p50 REAL,
                p95 REAL,
                p99 REAL,
                avg REAL,
                error_rate REAL,
                rps REAL
            )
        """)

    def record(self, endpoint: str, version: str, metrics: dict):
        self.conn.execute(
            """INSERT INTO baselines
            (endpoint, version, captured_at, p50, p95, p99, avg, error_rate, rps)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (endpoint, version, datetime.now(),
             metrics["p50"], metrics["p95"], metrics["p99"],
             metrics["avg"], metrics.get("error_rate", 0),
             metrics.get("rps", 0)),
        )
        self.conn.commit()

    def get_trend(self, endpoint: str, limit: int = 10) -> list[dict]:
        cursor = self.conn.execute(
            """SELECT version, captured_at, p50, p95, p99, error_rate
            FROM baselines WHERE endpoint = ?
            ORDER BY captured_at DESC LIMIT ?""",
            (endpoint, limit),
        )
        return [
            {"version": r[0], "date": r[1], "p50": r[2],
             "p95": r[3], "p99": r[4], "error_rate": r[5]}
            for r in cursor
        ]

    def detect_regression(
        self, endpoint: str, current: dict, tolerance: float = 0.2
    ) -> dict:
        previous = self.get_trend(endpoint, limit=1)
        if not previous:
            return {"regression": False, "message": "No previous baseline"}

        prev = previous[0]
        degradation = (current["p95"] - prev["p95"]) / prev["p95"]

        return {
            "regression": degradation > tolerance,
            "degradation_pct": round(degradation * 100, 1),
            "previous_p95": prev["p95"],
            "current_p95": current["p95"],
            "version_compared": prev["version"],
        }
```

**Anti-Pattern**: Tracking only averages, which hide latency spikes and tail behavior.

## Checklist

- [ ] Baselines captured under controlled conditions
- [ ] Same load profile used for comparison
- [ ] Percentiles tracked (p50, p95, p99), not just averages
- [ ] Baselines stored in version control or database
- [ ] Regression tolerance defined (e.g., 20%)
- [ ] Baselines updated after intentional changes
- [ ] Capacity projections reviewed quarterly
- [ ] SLOs informed by baseline data
- [ ] Trend dashboard accessible to team
- [ ] Alerting on baseline regression

## References

- [k6 Thresholds Documentation](https://grafana.com/docs/k6/latest/using-k6/thresholds/)
- [Google SRE - Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Performance Testing Guidance](https://learn.microsoft.com/en-us/azure/architecture/framework/scalability/performance-test)
