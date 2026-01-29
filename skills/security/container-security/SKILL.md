---
name: container-security
description: |
  Docker and container security best practices. Image hardening, runtime security.
  Activate when building Docker images, configuring containers, or reviewing Dockerfiles.
  Triggers: docker, container, dockerfile, image, kubernetes, k8s, pod security.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Container Security

Secure container images and runtime environments.

## Image Security

| Practice | Implementation |
|----------|----------------|
| Minimal base image | `FROM alpine:3.19` or `distroless` |
| Non-root user | `USER 1001` |
| No secrets in images | Use runtime injection |
| Pin versions | `node:20.10.0-alpine` not `node:latest` |
| Multi-stage builds | Separate build and runtime |

## Dockerfile Best Practices

```dockerfile
# 1. Use minimal base
FROM node:20-alpine AS builder

# 2. Set working directory
WORKDIR /app

# 3. Copy only what's needed
COPY package*.json ./
RUN npm ci --only=production

# 4. Multi-stage for smaller image
FROM node:20-alpine
WORKDIR /app

# 5. Create non-root user
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D appuser

# 6. Copy built artifacts
COPY --from=builder /app/node_modules ./node_modules
COPY . .

# 7. Set ownership and user
RUN chown -R appuser:appgroup /app
USER appuser

# 8. Define healthcheck
HEALTHCHECK CMD wget -q --spider http://localhost:3000/health

# 9. Expose port
EXPOSE 3000

CMD ["node", "server.js"]
```

## Runtime Security

| Control | Purpose |
|---------|---------|
| Read-only filesystem | Prevent runtime modifications |
| No new privileges | `--security-opt=no-new-privileges` |
| Drop capabilities | Remove unnecessary Linux capabilities |
| Resource limits | Prevent DoS |
| Network isolation | Limit container communication |

## Scanning

| Tool | Purpose |
|------|---------|
| Trivy | Vulnerability scanning |
| Snyk | Container security |
| Clair | Static analysis |
| Docker Scout | Supply chain security |

```bash
# Scan image for vulnerabilities
trivy image myapp:latest

# Scan Dockerfile
trivy config Dockerfile
```

## Security Checklist

- [ ] Minimal base image (Alpine or distroless)
- [ ] Non-root user configured
- [ ] No secrets in image layers
- [ ] Dependencies pinned to specific versions
- [ ] Multi-stage build for smaller attack surface
- [ ] Vulnerability scanning in CI/CD
- [ ] Read-only filesystem where possible
- [ ] Resource limits configured
- [ ] Health checks defined

## When to Load References

- **For Kubernetes security**: See `references/k8s-security.md`
- **For scanning setup**: See `references/container-scanning.md`
- **For runtime policies**: See `references/runtime-policies.md`

---

## Related Skills

- **[supply-chain](../supply-chain/SKILL.md)** - Base image and dependency scanning
- **[secrets](../secrets/SKILL.md)** - Secrets injection in container environments
- **[compliance](../compliance/SKILL.md)** - Container runtime compliance policies
