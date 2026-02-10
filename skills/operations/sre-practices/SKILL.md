---
name: sre-practices
description: Site Reliability Engineering practices for production systems.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: operations
---

# SRE Practices

Core Site Reliability Engineering disciplines for building and operating reliable systems.

## Quick Reference (80/20)

Focus on these three areas (80% of reliability improvement):

| Practice | Impact | Key Metric |
|----------|--------|------------|
| SLO-based alerting | Eliminates noise, focuses on user impact | Error budget burn rate |
| Toil reduction | Frees engineering time for reliability work | % time on toil (<50%) |
| Blameless postmortems | Prevents recurrence, builds knowledge | Action items completed |

## SLOs, SLIs, and SLAs

### Hierarchy

| Concept | Definition | Owner |
|---------|-----------|-------|
| **SLA** | Contractual commitment with consequences | Business |
| **SLO** | Internal reliability target (stricter than SLA) | Engineering |
| **SLI** | Measured metric that feeds the SLO | Monitoring |

### Setting Effective SLOs

```yaml
# Example SLO definition
service: payment-api
slos:
  - name: availability
    sli: successful_requests / total_requests
    target: 99.95%
    window: 30d
  - name: latency
    sli: requests_under_300ms / total_requests
    target: 99.0%
    window: 30d
```

**Rules of thumb**:
- Start with 99.9% availability (allows ~43 min/month downtime)
- Set SLO stricter than SLA by at least 0.05%
- Use rolling windows (30d) not calendar months
- Measure from the user perspective, not internal health checks

## Error Budgets

The error budget is `1 - SLO target`. For a 99.9% SLO, the error budget is 0.1%.

**Budget policies**:
- Budget remaining > 50%: ship features freely
- Budget remaining 20-50%: require extra review for risky changes
- Budget exhausted: freeze deployments, focus on reliability

**Burn rate alerts**:
- 14.4x burn rate over 1h = page (budget gone in ~1 day)
- 6x burn rate over 6h = page (budget gone in ~5 days)
- 1x burn rate over 3d = ticket (on track to exhaust)

## Toil Reduction

Toil is manual, repetitive, automatable work that scales linearly with service growth.

**Identification checklist**:
- [ ] Manual (human performs it)
- [ ] Repetitive (done more than twice)
- [ ] Automatable (could be scripted)
- [ ] Reactive (triggered by events, not planned)
- [ ] No lasting value (doesn't improve the system)

**Reduction strategies**:
1. Automate the most frequent toil first (Pareto)
2. Build self-healing systems (auto-restart, auto-scale)
3. Improve deployment pipelines to reduce rollback toil
4. Create runbooks, then automate runbook steps

## On-Call Best Practices

- Maximum 25% of time on-call per engineer
- Handoff documentation between rotations
- Escalation path defined and tested
- Compensation or time-off for pages
- Alert quality reviews: every page should be actionable

## Blameless Postmortems

**Template**:
1. **Summary**: What happened, duration, impact
2. **Timeline**: Sequence of events with timestamps
3. **Root cause**: Technical cause (use 5-whys)
4. **Contributing factors**: Process/tooling gaps
5. **Action items**: Prioritized with owners and deadlines
6. **Lessons learned**: What went well, what to improve

**Rules**:
- Focus on systems, not people
- Document within 48 hours
- Share widely across the organization
- Track action item completion

## When to Load References

- **For SLO framework details**: See `references/slo-framework.md`
- **For error budget policies**: See `references/error-budgets.md`
- **For toil reduction patterns**: See `references/toil-reduction.md`

## Cross-References

- **Monitoring**: See `quality/observability` skill
- **Incident response**: See `operations/incident-response` skill
- **Alerting**: See `operations/monitoring` skill
