---
title: k6 Patterns Reference
category: quality
type: reference
version: "1.0.0"
---

# k6 Patterns

> Part of the quality/load-testing knowledge skill

## Overview

k6 is a modern load testing tool written in Go with a JavaScript scripting API. It excels at CI integration, low resource usage, and developer-friendly scripting.

## Quick Reference (80/20)

| Concept | Purpose |
|---------|---------|
| VUs (Virtual Users) | Simulated concurrent users |
| Scenarios | Named execution configurations |
| Thresholds | Pass/fail criteria |
| Checks | In-script assertions |
| Tags | Custom metric labels |

## Patterns

### Pattern 1: Basic Load Test Structure

**When to Use**: Standard load test for an API

**Example**:
```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const apiDuration = new Trend('api_duration');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up
    { duration: '5m', target: 50 },   // Sustain
    { duration: '2m', target: 100 },  // Peak
    { duration: '5m', target: 100 },  // Sustain peak
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export default function () {
  // GET request
  const listRes = http.get(`${BASE_URL}/api/products`, {
    tags: { name: 'ListProducts' },
  });

  check(listRes, {
    'list status 200': (r) => r.status === 200,
    'list has products': (r) => JSON.parse(r.body).length > 0,
  }) || errorRate.add(1);

  apiDuration.add(listRes.timings.duration);

  sleep(1); // Think time between requests

  // POST request
  const createRes = http.post(
    `${BASE_URL}/api/orders`,
    JSON.stringify({
      product_id: 'prod_001',
      quantity: 1,
    }),
    {
      headers: { 'Content-Type': 'application/json' },
      tags: { name: 'CreateOrder' },
    }
  );

  check(createRes, {
    'create status 201': (r) => r.status === 201,
    'create has id': (r) => JSON.parse(r.body).id !== undefined,
  }) || errorRate.add(1);

  sleep(Math.random() * 3 + 1); // Random think time 1-4s
}
```

**Anti-Pattern**: No think time between requests (unrealistic traffic pattern).

### Pattern 2: Scenario-Based Testing

**When to Use**: Testing multiple user flows with different load profiles

**Example**:
```javascript
// scenarios.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    // Browsing users - high volume, read-only
    browsers: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '2m', target: 200 },
        { duration: '10m', target: 200 },
        { duration: '2m', target: 0 },
      ],
      exec: 'browseProducts',
    },
    // Buyers - lower volume, read-write
    buyers: {
      executor: 'constant-arrival-rate',
      rate: 50,           // 50 iterations per timeUnit
      timeUnit: '1m',     // per minute
      duration: '14m',
      preAllocatedVUs: 20,
      maxVUs: 50,
      exec: 'purchaseFlow',
    },
    // API integrations - steady rate
    api_clients: {
      executor: 'constant-vus',
      vus: 10,
      duration: '14m',
      exec: 'apiIntegration',
    },
  },
  thresholds: {
    'http_req_duration{scenario:browsers}': ['p(95)<300'],
    'http_req_duration{scenario:buyers}': ['p(95)<1000'],
    'http_req_duration{scenario:api_clients}': ['p(95)<200'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE = __ENV.BASE_URL || 'http://localhost:3000';

export function browseProducts() {
  http.get(`${BASE}/api/products`);
  sleep(2);
  http.get(`${BASE}/api/products/${Math.floor(Math.random() * 100) + 1}`);
  sleep(3);
}

export function purchaseFlow() {
  // Browse
  const products = http.get(`${BASE}/api/products`);
  sleep(1);

  // Add to cart
  http.post(`${BASE}/api/cart`, JSON.stringify({
    product_id: `prod_${Math.floor(Math.random() * 100) + 1}`,
    quantity: 1,
  }), { headers: { 'Content-Type': 'application/json' } });
  sleep(2);

  // Checkout
  const checkout = http.post(`${BASE}/api/checkout`, JSON.stringify({
    payment_method: 'test_card',
  }), { headers: { 'Content-Type': 'application/json' } });

  check(checkout, { 'checkout success': (r) => r.status === 200 });
  sleep(1);
}

export function apiIntegration() {
  const res = http.get(`${BASE}/api/inventory/sync`, {
    headers: { 'Authorization': `Bearer ${__ENV.API_TOKEN}` },
  });
  check(res, { 'sync success': (r) => r.status === 200 });
  sleep(5);
}
```

**Anti-Pattern**: Testing only a single endpoint instead of realistic user flows.

### Pattern 3: Stress Test with Breakpoint

**When to Use**: Finding the system's maximum capacity

**Example**:
```javascript
// stress-test.js
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    breakpoint: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 500,
      maxVUs: 2000,
      stages: [
        { duration: '2m', target: 10 },    // Warm up
        { duration: '5m', target: 50 },    // Normal
        { duration: '5m', target: 100 },   // High
        { duration: '5m', target: 200 },   // Very high
        { duration: '5m', target: 500 },   // Extreme
        { duration: '5m', target: 1000 },  // Breaking point?
        { duration: '3m', target: 0 },     // Recovery
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<2000'],  // Lenient for stress
    http_req_failed: ['rate<0.10'],     // 10% error acceptable in stress
  },
};

export default function () {
  const res = http.get(`${__ENV.BASE_URL}/api/health`);
  check(res, {
    'status 200': (r) => r.status === 200,
    'duration < 2s': (r) => r.timings.duration < 2000,
  });
}
```

**Anti-Pattern**: Running stress tests against shared or production environments.

### Pattern 4: CI Integration

**When to Use**: Automated performance regression detection

**Example**:
```yaml
# .github/workflows/load-test.yml
name: Load Test
on:
  push:
    branches: [main]
  pull_request:

jobs:
  smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Start application
        run: docker compose up -d
        working-directory: ./deploy

      - name: Wait for app
        run: |
          for i in $(seq 1 30); do
            curl -sf http://localhost:3000/health && break
            sleep 2
          done

      - name: Run k6 smoke test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: tests/load/smoke.js
        env:
          BASE_URL: http://localhost:3000

  load-test:
    if: github.ref == 'refs/heads/main'
    needs: smoke-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to staging
        run: ./deploy.sh staging

      - name: Run k6 load test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: tests/load/load-test.js
          flags: --out json=results.json
        env:
          BASE_URL: ${{ secrets.STAGING_URL }}

      - name: Upload results
        uses: actions/upload-artifact@v4
        with:
          name: k6-results
          path: results.json
```

**Anti-Pattern**: Running load tests without threshold gates that can fail the pipeline.

### Pattern 5: Authentication and Session Handling

**When to Use**: Testing authenticated endpoints

**Example**:
```javascript
// authenticated-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { SharedArray } from 'k6/data';

// Load test users from file (shared across VUs)
const users = new SharedArray('users', function () {
  return JSON.parse(open('./test-users.json'));
});

export const options = {
  stages: [
    { duration: '1m', target: 20 },
    { duration: '5m', target: 20 },
    { duration: '1m', target: 0 },
  ],
};

const BASE = __ENV.BASE_URL || 'http://localhost:3000';

// Setup: runs once per VU
export function setup() {
  // Warm up the system
  http.get(`${BASE}/health`);
}

export default function () {
  // Each VU gets a unique user
  const user = users[__VU % users.length];

  // Login
  const loginRes = http.post(`${BASE}/api/auth/login`, JSON.stringify({
    email: user.email,
    password: user.password,
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  const success = check(loginRes, {
    'login ok': (r) => r.status === 200,
  });

  if (!success) return;

  const token = JSON.parse(loginRes.body).token;
  const authHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`,
  };

  // Authenticated requests
  const profileRes = http.get(`${BASE}/api/me`, { headers: authHeaders });
  check(profileRes, { 'profile ok': (r) => r.status === 200 });
  sleep(1);

  const ordersRes = http.get(`${BASE}/api/me/orders`, { headers: authHeaders });
  check(ordersRes, { 'orders ok': (r) => r.status === 200 });
  sleep(2);
}
```

**Anti-Pattern**: All VUs sharing a single auth token (not realistic, may hit rate limits).

## Checklist

- [ ] Smoke test passes before load test
- [ ] Realistic think times between requests
- [ ] Multiple user scenarios defined
- [ ] Thresholds set for p95, error rate
- [ ] Test data prepared (no shared state conflicts)
- [ ] CI integration with pass/fail gates
- [ ] Results stored for trend analysis
- [ ] Environment isolated from production

## References

- [k6 Documentation](https://grafana.com/docs/k6/latest/)
- [k6 Examples](https://github.com/grafana/k6/tree/master/examples)
- [k6 Thresholds](https://grafana.com/docs/k6/latest/using-k6/thresholds/)
