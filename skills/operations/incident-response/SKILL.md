---
name: incident-response
description: Incident response playbooks and runbooks. On-call, escalation, post-mortems.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: operations
---

# Incident Response

Structured incident management and resolution.

## Incident Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| P1 | Critical - Service down | 15 minutes |
| P2 | Major - Degraded service | 1 hour |
| P3 | Minor - Limited impact | 4 hours |
| P4 | Low - No immediate impact | Next business day |

## Incident Lifecycle

```
Detect → Triage → Mitigate → Resolve → Review
```

| Phase | Activities |
|-------|------------|
| Detect | Alerts, user reports, monitoring |
| Triage | Assess severity, assign owner |
| Mitigate | Stop bleeding, temporary fixes |
| Resolve | Root cause fix, full recovery |
| Review | Post-mortem, improvements |

## Response Roles

| Role | Responsibility |
|------|----------------|
| Incident Commander | Coordinates response |
| Technical Lead | Directs technical work |
| Communications | Updates stakeholders |
| Scribe | Documents timeline |

## Runbook Template

```markdown
# Runbook: [Service/Scenario]

## Symptoms
- What alerts fire
- What users report

## Diagnosis
1. Check [metrics dashboard]
2. Review [logs location]
3. Verify [dependent services]

## Mitigation
1. [Immediate action]
2. [Rollback steps if applicable]

## Resolution
1. [Root cause fix steps]
2. [Verification steps]

## Contacts
- Primary: [name/channel]
- Escalation: [name/channel]
```

## Communication Templates

### Initial
```
INCIDENT: [Brief description]
SEVERITY: P[1-4]
IMPACT: [What's affected]
STATUS: Investigating
UPDATES: [channel] every [interval]
```

### Resolution
```
RESOLVED: [Brief description]
DURATION: [start] - [end]
ROOT CAUSE: [brief]
FOLLOW-UP: Post-mortem scheduled [date]
```

## Post-Mortem Structure

| Section | Content |
|---------|---------|
| Summary | What happened |
| Timeline | Chronological events |
| Root Cause | Why it happened |
| Impact | Users/services affected |
| What Went Well | Positive aspects |
| What Went Wrong | Areas to improve |
| Action Items | Specific improvements |

## Checklist

- [ ] Incident severity assessed
- [ ] Stakeholders notified
- [ ] Response team assembled
- [ ] Communication channel established
- [ ] Timeline documented
- [ ] Mitigation applied
- [ ] Root cause identified
- [ ] Post-mortem scheduled

## When to Load References

- **For runbook templates**: See `references/runbook-templates.md`
- **For post-mortem guide**: See `references/post-mortem.md`
- **For escalation paths**: See `references/escalation.md`
