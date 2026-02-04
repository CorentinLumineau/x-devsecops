---
name: load-testing
description: Load, stress, and soak testing patterns with k6, JMeter, and Artillery.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Load Testing

Performance validation through systematic load, stress, and soak testing.

## Quick Reference (80/20)

| Test Type | Purpose | Duration | Load Pattern |
|-----------|---------|----------|-------------|
| Smoke | Verify script works | 1-2 min | Minimal (1-5 VUs) |
| Load | Validate SLOs under normal load | 10-30 min | Expected traffic |
| Stress | Find breaking point | 15-30 min | Ramp beyond capacity |
| Soak | Find memory leaks, degradation | 1-8 hours | Sustained normal load |
| Spike | Test sudden traffic bursts | 10-15 min | Sharp increase/decrease |

## Tool Comparison

| Feature | k6 | JMeter | Artillery |
|---------|-----|--------|-----------|
| Language | JavaScript | GUI/XML | YAML/JS |
| Protocol | HTTP, gRPC, WebSocket | HTTP, JDBC, JMS | HTTP, WebSocket |
| Cloud native | Yes | No (heavy) | Yes |
| CI friendly | Excellent | Fair | Good |
| Scripting | Modern JS/TS | Limited | JS functions |
| Resource usage | Low (Go-based) | High (Java) | Medium (Node) |

## Key Metrics

| Metric | What It Tells You | Alert Threshold |
|--------|-------------------|-----------------|
| Response time (p95) | User experience | > SLO target |
| Throughput (RPS) | Capacity | < expected baseline |
| Error rate | Reliability | > 1% |
| Concurrent users | Scale | Near capacity limit |
| CPU/Memory | Resource saturation | > 80% |

## Performance Budget

```
Response Time Budget (p95):
  DNS lookup:      < 20ms
  TCP connection:  < 50ms
  TLS handshake:   < 50ms
  Server processing: < 200ms
  Content transfer:  < 80ms
  ──────────────────────────
  Total:           < 400ms
```

## CI Integration Strategy

| Stage | Test Type | Gate |
|-------|-----------|------|
| PR | Smoke test | Must pass |
| Merge to main | Load test (short) | p95 < SLO |
| Pre-release | Full load + soak | All metrics pass |
| Post-deploy | Smoke + canary | Error rate < 0.1% |

## Checklist

- [ ] Baselines established for key endpoints
- [ ] SLOs defined with measurable thresholds
- [ ] Test data and environments prepared
- [ ] Load tests in CI pipeline
- [ ] Results tracked over time
- [ ] Alerts for performance regression

## When to Load References

- **For k6 patterns**: See `references/k6-patterns.md`
- **For performance baselines**: See `references/performance-baselines.md`
