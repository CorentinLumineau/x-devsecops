---
name: infrastructure
description: Infrastructure as Code patterns. Terraform, Docker Compose, Kubernetes basics.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob Bash
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: delivery
---

# Infrastructure

Infrastructure as Code patterns and best practices.

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
| Terraform | Cloud infrastructure |
| Docker Compose | Local development |
| Kubernetes | Container orchestration |
| Ansible | Configuration management |
| Pulumi | Code-native IaC |

## Docker Compose Basics

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## Terraform Structure

```
infrastructure/
├── main.tf           # Main configuration
├── variables.tf      # Input variables
├── outputs.tf        # Output values
├── providers.tf      # Provider config
├── terraform.tfvars  # Variable values (gitignored)
└── modules/
    └── vpc/
        ├── main.tf
        └── variables.tf
```

## Environment Management

| Environment | Purpose | Data |
|-------------|---------|------|
| Development | Local dev | Fake/seed |
| Staging | Pre-production | Anonymized |
| Production | Live system | Real |

## IaC Best Practices

| Practice | Benefit |
|----------|---------|
| State management | Track changes |
| Modules | Reusable components |
| Workspaces | Environment isolation |
| Lock files | Consistent versions |
| Plan before apply | Preview changes |

## Security Considerations

| Area | Practice |
|------|----------|
| Secrets | Use secret managers, not files |
| State | Encrypt and secure backend |
| Access | Least privilege IAM |
| Network | Private subnets, firewalls |

## Checklist

- [ ] Infrastructure version controlled
- [ ] Environments separated
- [ ] Secrets managed securely
- [ ] State stored remotely
- [ ] Changes reviewed before apply
- [ ] Rollback strategy exists
- [ ] Documentation up to date

## When to Load References

- **For Terraform patterns**: See `references/terraform.md`
- **For Kubernetes basics**: See `references/kubernetes.md`
- **For Docker best practices**: See `references/docker.md`
