---
name: infrastructure
description: Use when provisioning infrastructure, configuring containers, or managing feature flags. Covers Infrastructure as Code patterns, container orchestration, and feature flag management.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---

# Infrastructure

Infrastructure as Code patterns, container best practices, and feature flag management.

## Quick Reference (80/20)

| Topic | Key Concepts |
|-------|-------------|
| **Terraform** | Providers, modules, state management, workspaces, plan-before-apply |
| **Docker** | Multi-stage builds, non-root user, layer caching, security hardening |
| **Kubernetes** | Deployments, Services, Ingress, HPA, NetworkPolicies, PDB |
| **IaC principles** | Version controlled, reproducible, immutable, documented |
| **Feature flags** | Release (short-lived), experiment (A/B), operational (kill switch), permission |
| **Flag lifecycle** | Create -> test -> rollout -> monitor -> cleanup |
| **A/B testing** | Statistical significance, sample size, guardrail metrics |
| **Environment mgmt** | Dev (fake data), staging (anonymized), production (real) |

## IaC Principles

| Principle | Description |
|-----------|-------------|
| Version controlled | All infra in git |
| Reproducible | Same config = same result |
| Documented | Code is documentation |
| Immutable | Replace, don't modify |

## Tool Selection

| Tool | Best For |
|------|----------|
| Terraform | Cloud infrastructure provisioning |
| Docker / Docker Compose | Containerization, local development |
| Kubernetes | Container orchestration at scale |
| Ansible | Configuration management |
| Pulumi | Code-native IaC |

## Terraform Structure

```
infrastructure/
+-- environments/
|   +-- dev/
|   +-- staging/
|   +-- prod/
+-- modules/
|   +-- vpc/
|   +-- eks/
|   +-- rds/
+-- shared/
    +-- providers.tf
    +-- versions.tf
```

## Docker Best Practices

| Practice | Why |
|----------|-----|
| Multi-stage builds | Smaller, more secure images |
| Non-root user | Principle of least privilege |
| Specific base image versions | Reproducible builds |
| Layer caching optimization | Faster builds |
| Health checks | Container health monitoring |

## Kubernetes Essentials

| Resource | Purpose |
|----------|---------|
| Deployment | Manage stateless applications |
| StatefulSet | Manage stateful applications |
| Service | Network access to pods |
| Ingress | External HTTP access with TLS |
| HPA | Auto-scale based on metrics |
| NetworkPolicy | Restrict pod-to-pod traffic |

## Environment Management

| Environment | Purpose | Data |
|-------------|---------|------|
| Development | Local dev | Fake/seed |
| Staging | Pre-production | Anonymized |
| Production | Live system | Real |

## Feature Flag Types

| Type | Purpose | Lifespan |
|------|---------|----------|
| Release | Gradual rollout of new features | Short (remove after 100%) |
| Experiment | A/B testing with statistical analysis | Medium (until decision) |
| Operational | Kill switches, circuit breakers | Permanent |
| Permission | User access control, premium features | Permanent |

## Feature Flag Lifecycle

| Stage | Action |
|-------|--------|
| Create | Define flag with default off |
| Test | Enable for internal/beta users |
| Rollout | Gradually increase percentage (5% -> 25% -> 50% -> 100%) |
| Monitor | Watch metrics and error rates |
| Cleanup | Remove flag code when at 100% |

## Flag Implementation Pattern

```
// Pseudo-code
if (featureFlag.isEnabled('new-checkout')) {
  showNewCheckout()
} else {
  showOldCheckout()
}
```

## A/B Testing Essentials

| Metric | Purpose |
|--------|---------|
| Sample size | Users needed for statistical significance |
| p-value | Probability of false positive (< 0.05) |
| Statistical power | Probability of detecting real effect (>= 0.80) |
| MDE | Minimum Detectable Effect |
| Confidence level | Certainty level (typically 95%) |

## Flag Best Practices

| Practice | Why |
|----------|-----|
| Default to off | Safe deployment |
| Short-lived release flags | Reduce technical debt |
| Set cleanup deadline | Prevent flag accumulation |
| Monitor flag usage | Track adoption and staleness |
| Automated cleanup scanning | Detect unused flags in CI |

## Flag Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Permanent release flags | Set cleanup deadline |
| Nested flags | Flatten logic |
| Too many active flags | Regular cleanup sprints |
| No monitoring | Add flag evaluation metrics |
| Manual tracking | Automated scanning in CI |

## Implementation Options

| Tool | Best For |
|------|----------|
| LaunchDarkly | Enterprise, full-featured |
| Unleash | Open source, self-hosted |
| ConfigCat | Simple, affordable |
| Custom | Simple needs, full control |

## Security Considerations

| Area | Practice |
|------|----------|
| Secrets | Use secret managers (Vault, AWS Secrets Manager), not files |
| State | Encrypt and secure Terraform backend |
| Access | Least privilege IAM roles |
| Network | Private subnets, firewalls, NetworkPolicies |
| Containers | Non-root, read-only filesystem, drop capabilities |

## Checklist

- [ ] Infrastructure version controlled
- [ ] Environments separated (dev/staging/prod)
- [ ] Secrets managed securely
- [ ] Terraform state stored remotely with locking
- [ ] Changes reviewed before apply
- [ ] Docker images use multi-stage builds and non-root users
- [ ] Kubernetes resources have limits, probes, and PDBs
- [ ] Feature flags have owners and expiration dates
- [ ] Stale flag detection automated
- [ ] A/B test sample sizes calculated before launch
- [ ] Flag cleanup integrated into CI

## When to Load References

- **For Terraform patterns**: See `references/terraform.md`
- **For Kubernetes patterns**: See `references/kubernetes.md`
- **For Docker best practices**: See `references/docker.md`
- **For A/B testing details**: See `references/ab-testing.md`
- **For flag implementation**: See `references/flag-implementation.md`
- **For flag cleanup strategies**: See `references/flag-cleanup.md`

## Related Skills

- **CI/CD & Delivery**: See `delivery/ci-cd-delivery` for pipelines and deployment strategies
- **Release & Git**: See `delivery/release-git` for versioning, branching, commit conventions
