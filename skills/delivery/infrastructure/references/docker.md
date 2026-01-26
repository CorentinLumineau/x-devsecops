---
title: Docker Reference
category: delivery
type: reference
version: "1.0.0"
---

# Docker

> Part of the delivery/infrastructure knowledge skill

## Overview

Docker containerizes applications for consistent deployment across environments. This reference covers Dockerfile best practices, multi-stage builds, and security hardening.

## Quick Reference (80/20)

| Instruction | Purpose |
|-------------|---------|
| FROM | Base image |
| RUN | Execute commands |
| COPY | Copy files |
| WORKDIR | Set working directory |
| ENV | Environment variables |
| EXPOSE | Document ports |
| CMD | Default command |
| ENTRYPOINT | Container entry point |

## Patterns

### Pattern 1: Multi-Stage Build

**When to Use**: Optimizing image size and security

**Example**:
```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy source and build
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy only production dependencies
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

# Security: Remove unnecessary packages
RUN apk --no-cache add dumb-init && \
    rm -rf /var/cache/apk/*

USER nodejs

EXPOSE 3000

ENV NODE_ENV=production

# Use dumb-init for proper signal handling
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
```

**Anti-Pattern**: Single stage with dev dependencies in production.

### Pattern 2: Go Application

**When to Use**: Minimal Go container

**Example**:
```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder

# Install certificates and timezone data
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Download dependencies first
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copy source and build
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s -X main.Version=${VERSION}" \
    -o /app/server ./cmd/server

# Final stage - distroless for minimal attack surface
FROM gcr.io/distroless/static-debian12:nonroot

# Copy timezone data and certificates
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary
COPY --from=builder /app/server /server

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/server"]
```

**Anti-Pattern**: Using full OS image for compiled binaries.

### Pattern 3: Python Application

**When to Use**: Python with proper dependency management

**Example**:
```dockerfile
# Build stage
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.12-slim AS production

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Create non-root user
RUN groupadd --gid 1000 python && \
    useradd --uid 1000 --gid python --shell /bin/bash python

WORKDIR /app

# Copy virtual environment
COPY --from=builder /opt/venv /opt/venv

# Copy application
COPY --chown=python:python . .

USER python

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:application"]
```

**Anti-Pattern**: Installing dev tools in production image.

### Pattern 4: Layer Caching Optimization

**When to Use**: Faster builds with proper layering

**Example**:
```dockerfile
FROM node:20-alpine

WORKDIR /app

# Layer 1: System dependencies (changes rarely)
RUN apk add --no-cache \
    dumb-init \
    tini

# Layer 2: Package files (changes occasionally)
COPY package.json package-lock.json ./

# Layer 3: Dependencies (changes with package files)
RUN npm ci --only=production

# Layer 4: Application code (changes frequently)
COPY . .

# Build step
RUN npm run build

# Cleanup
RUN npm prune --production && \
    rm -rf /root/.npm /tmp/*

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]
```

```yaml
# docker-compose.yml with build caching
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
      cache_from:
        - myapp/api:latest
        - myapp/api:cache
      args:
        BUILDKIT_INLINE_CACHE: 1
    image: myapp/api:${VERSION:-latest}
```

```bash
# BuildKit cache mount for faster builds
# syntax=docker/dockerfile:1
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production

COPY . .
RUN npm run build
```

**Anti-Pattern**: Copying all files before installing dependencies.

### Pattern 5: Security Hardening

**When to Use**: Production containers with security focus

**Example**:
```dockerfile
# Use specific version, not latest
FROM node:20.10.0-alpine3.19

# Security labels
LABEL maintainer="team@example.com" \
      org.opencontainers.image.source="https://github.com/org/repo" \
      org.opencontainers.image.version="1.0.0"

# Update and install security patches
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache dumb-init && \
    rm -rf /var/cache/apk/*

# Create app directory with restricted permissions
WORKDIR /app
RUN chmod 755 /app

# Create non-root user
RUN addgroup -g 1001 -S app && \
    adduser -S -u 1001 -G app app

# Copy with ownership
COPY --chown=app:app package*.json ./
RUN npm ci --only=production --ignore-scripts

COPY --chown=app:app . .
RUN npm run build && \
    npm prune --production && \
    rm -rf /root/.npm

# Remove unnecessary files
RUN rm -rf \
    .git \
    .gitignore \
    .env* \
    *.md \
    tests/ \
    __tests__/ \
    coverage/

# Switch to non-root user
USER app

# Read-only filesystem compatibility
VOLUME ["/tmp"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

EXPOSE 3000

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
```

```bash
# Scan for vulnerabilities
docker scout cves myapp:latest

# Or with Trivy
trivy image --severity HIGH,CRITICAL myapp:latest

# Run with security options
docker run -d \
    --name app \
    --read-only \
    --tmpfs /tmp \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --memory 512m \
    --cpus 0.5 \
    myapp:latest
```

**Anti-Pattern**: Running as root with full capabilities.

### Pattern 6: Docker Compose for Development

**When to Use**: Local development environment

**Example**:
```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile.dev
      target: development
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
      - "9229:9229"  # Debug port
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgres://user:pass@db:5432/app
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    command: npm run dev

  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: app
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d app"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"

  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
      - "80:80"
    depends_on:
      - api

volumes:
  postgres_data:
  redis_data:

networks:
  default:
    name: app-network
```

```dockerfile
# Dockerfile.dev
FROM node:20-alpine AS development

WORKDIR /app

RUN apk add --no-cache git

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000 9229

CMD ["npm", "run", "dev"]
```

**Anti-Pattern**: Using production Dockerfile for development.

## Checklist

- [ ] Multi-stage builds used
- [ ] Non-root user configured
- [ ] Specific base image versions
- [ ] Security patches applied
- [ ] Minimal final image
- [ ] Layer caching optimized
- [ ] Health checks configured
- [ ] Secrets not in image
- [ ] Images scanned for vulnerabilities
- [ ] .dockerignore configured

## References

- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [BuildKit Features](https://docs.docker.com/build/buildkit/)
