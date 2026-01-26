---
name: feature-flags
description: |
  Feature flag patterns for progressive rollouts. Toggles, A/B testing, kill switches.
  Activate when implementing feature toggles, gradual rollouts, or runtime configuration.
  Triggers: feature flag, toggle, rollout, a/b test, experiment, kill switch.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---

# Feature Flags

Progressive rollout and runtime feature control.

## Flag Types

| Type | Purpose | Lifespan |
|------|---------|----------|
| Release | Gradual rollout | Short (remove after 100%) |
| Experiment | A/B testing | Medium (until decision) |
| Operational | Kill switches | Permanent |
| Permission | User access | Permanent |

## Use Cases

| Scenario | Flag Type |
|----------|-----------|
| Deploy dark features | Release |
| Test new UI | Experiment |
| Disable problematic feature | Operational |
| Premium features | Permission |

## Implementation Pattern

```
// Pseudo-code
if (featureFlag.isEnabled('new-checkout')) {
  showNewCheckout()
} else {
  showOldCheckout()
}
```

## Rollout Strategy

```
1. Internal only (1%)
2. Beta users (5%)
3. Early adopters (25%)
4. General (50%)
5. Full rollout (100%)
6. Remove flag (cleanup)
```

## Flag Lifecycle

| Stage | Action |
|-------|--------|
| Create | Define flag with default off |
| Test | Enable for internal/beta |
| Rollout | Gradually increase percentage |
| Monitor | Watch metrics and errors |
| Cleanup | Remove flag code when at 100% |

## Best Practices

| Practice | Why |
|----------|-----|
| Default to off | Safe deployment |
| Short-lived release flags | Reduce technical debt |
| Monitor flag usage | Track adoption |
| Document flags | Know what exists |
| Regular cleanup | Remove old flags |

## Anti-Patterns

| Anti-pattern | Fix |
|--------------|-----|
| Permanent release flags | Set cleanup deadline |
| Nested flags | Flatten logic |
| Too many active flags | Regular cleanup |
| No monitoring | Add metrics |

## Implementation Options

| Tool | Best For |
|------|----------|
| LaunchDarkly | Enterprise, full-featured |
| Unleash | Open source, self-hosted |
| ConfigCat | Simple, affordable |
| Custom | Simple needs, full control |

## Flag Checklist

- [ ] Flag name is descriptive
- [ ] Default value is safe (off)
- [ ] Cleanup date set
- [ ] Monitoring in place
- [ ] Rollback plan exists
- [ ] Documentation updated

## When to Load References

- **For A/B testing**: See `references/ab-testing.md`
- **For implementation**: See `references/implementation.md`
- **For cleanup strategies**: See `references/cleanup.md`
