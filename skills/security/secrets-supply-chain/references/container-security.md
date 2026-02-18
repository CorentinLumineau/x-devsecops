# Container Security

Image security, Dockerfile best practices, runtime controls, and container scanning.

## Image Security

| Practice | Implementation |
|----------|----------------|
| Minimal base image | `FROM alpine:3.19` or `distroless` |
| Non-root user | `USER 1001` |
| No secrets in images | Use runtime injection |
| Pin versions | `node:20.10.0-alpine` not `node:latest` |
| Multi-stage builds | Separate build and runtime stages |

## Dockerfile Best Practices

```dockerfile
# 1. Use minimal base
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# 2. Multi-stage for smaller image
FROM node:20-alpine
WORKDIR /app

# 3. Create non-root user
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -D appuser

# 4. Copy built artifacts
COPY --from=builder /app/node_modules ./node_modules
COPY . .
RUN chown -R appuser:appgroup /app
USER appuser

HEALTHCHECK CMD wget -q --spider http://localhost:3000/health
EXPOSE 3000
CMD ["node", "server.js"]
```

## Runtime Security Controls

| Control | Purpose |
|---------|---------|
| Read-only filesystem | Prevent runtime modifications |
| No new privileges | `--security-opt=no-new-privileges` |
| Drop capabilities | Remove unnecessary Linux capabilities |
| Resource limits | Prevent DoS |
| Network isolation | Limit container communication |

## Container Scanning

| Tool | Purpose |
|------|---------|
| Trivy | Vulnerability scanning |
| Snyk | Container security |
| Clair | Static analysis |
| Docker Scout | Supply chain security |
