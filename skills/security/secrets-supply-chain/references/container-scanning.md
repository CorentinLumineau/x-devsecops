---
title: Container Image Scanning Reference
category: security
type: reference
version: "1.0.0"
---

# Container Image Vulnerability Scanning

> Part of the security/container-security knowledge skill

## Overview

Container image scanning identifies vulnerabilities in base images, packages, and dependencies before deployment. This reference covers scanning tools, CI/CD integration, and vulnerability management workflows.

## 80/20 Quick Reference

**Scanning integration points:**

| Stage | Tool | Purpose |
|-------|------|---------|
| Build | Trivy, Grype | Block vulnerable images |
| Registry | Harbor, ECR | Continuous scanning |
| Runtime | Falco | Detect anomalies |
| Policy | OPA/Gatekeeper | Enforce thresholds |

**Vulnerability severity actions:**

| Severity | Action | SLA |
|----------|--------|-----|
| Critical | Block deployment | Immediate |
| High | Block, remediate | 7 days |
| Medium | Alert, remediate | 30 days |
| Low | Track | 90 days |

## Patterns

### Pattern 1: Trivy Integration

**When to Use**: Comprehensive vulnerability scanning

**Implementation**:
```yaml
# GitHub Actions with Trivy
name: Container Security

on:
  push:
    branches: [main]
  pull_request:

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:${{ github.sha }} .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail on findings

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

      # Also scan for secrets
      - name: Scan for secrets
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'myapp:${{ github.sha }}'
          scan-type: 'fs'
          scanners: 'secret'
          exit-code: '1'
```

**CLI usage**:
```bash
# Scan image
trivy image myapp:latest

# Scan with severity filter
trivy image --severity CRITICAL,HIGH myapp:latest

# Output as JSON
trivy image --format json --output results.json myapp:latest

# Scan filesystem (source code)
trivy fs --security-checks vuln,secret,config .

# Scan Kubernetes manifests
trivy config ./k8s/

# Ignore unfixed vulnerabilities
trivy image --ignore-unfixed myapp:latest

# Use custom policy
trivy image --policy ./policies myapp:latest
```

### Pattern 2: Grype Integration

**When to Use**: Alternative to Trivy with Syft SBOM integration

**Implementation**:
```yaml
# GitLab CI with Grype
container_scanning:
  stage: test
  image: anchore/grype:latest
  variables:
    GRYPE_DB_AUTO_UPDATE: "true"
  script:
    # Generate SBOM with Syft
    - syft myregistry/myapp:$CI_COMMIT_SHA -o json > sbom.json

    # Scan SBOM with Grype
    - grype sbom:./sbom.json --fail-on high -o json > grype-results.json

    # Upload results
    - |
      if [ -f grype-results.json ]; then
        curl -X POST "$SECURITY_DASHBOARD_URL/api/vulnerabilities" \
          -H "Content-Type: application/json" \
          -d @grype-results.json
      fi
  artifacts:
    paths:
      - sbom.json
      - grype-results.json
    reports:
      container_scanning: grype-results.json
```

**CLI usage**:
```bash
# Scan image
grype myapp:latest

# Fail on severity
grype myapp:latest --fail-on high

# Scan from SBOM
syft myapp:latest -o json | grype

# Output formats
grype myapp:latest -o json
grype myapp:latest -o table
grype myapp:latest -o cyclonedx

# Add to .grype.yaml for ignore rules
echo "ignore:
  - vulnerability: CVE-2023-12345
    reason: False positive in our usage" > .grype.yaml
```

### Pattern 3: Registry-Level Scanning

**When to Use**: Continuous scanning of stored images

**Implementation**:
```yaml
# Harbor configuration
# Enable Trivy scanner in Harbor
# Settings > Interrogation Services > Enable Trivy

# AWS ECR with scanning
# Enable in console or via CLI:
aws ecr put-image-scanning-configuration \
  --repository-name myapp \
  --image-scanning-configuration scanOnPush=true

# Get scan results
aws ecr describe-image-scan-findings \
  --repository-name myapp \
  --image-id imageTag=latest
```

**GCP Artifact Registry**:
```bash
# Enable vulnerability scanning
gcloud artifacts repositories update myrepo \
  --location=us-central1 \
  --enable-vulnerability-scanning

# Check vulnerabilities
gcloud artifacts docker images list-vulnerabilities \
  us-central1-docker.pkg.dev/project/myrepo/myapp:latest
```

### Pattern 4: Policy Enforcement with OPA

**When to Use**: Blocking vulnerable images from deployment

**Implementation**:
```rego
# policy/image-vulnerability.rego
package kubernetes.admission

import data.kubernetes.vulnerabilities

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    image := container.image

    # Query vulnerability database
    vulns := vulnerabilities[image]
    critical_count := count([v | v := vulns[_]; v.severity == "CRITICAL"])

    critical_count > 0
    msg := sprintf("Image %s has %d critical vulnerabilities", [image, critical_count])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    image := container.image

    # Check for allowed registries
    not startswith(image, "myregistry.com/")
    not startswith(image, "gcr.io/my-project/")

    msg := sprintf("Image %s is from untrusted registry", [image])
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    image := container.image

    # Require image digest
    not contains(image, "@sha256:")

    msg := sprintf("Image %s must use digest (sha256:), not tag", [image])
}
```

**Kyverno policy**:
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: check-vulnerabilities
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-image-vulnerabilities
      match:
        any:
          - resources:
              kinds:
                - Pod
      context:
        - name: imageData
          apiCall:
            urlPath: "/apis/aquasecurity.github.io/v1alpha1/namespaces/{{request.namespace}}/vulnerabilityreports"
            jmesPath: "items[?metadata.labels.\"trivy-operator.resource.name\"=='{{request.object.metadata.name}}']"
      validate:
        message: "Image has critical vulnerabilities"
        deny:
          conditions:
            any:
              - key: "{{ imageData[0].report.summary.criticalCount }}"
                operator: GreaterThan
                value: 0
```

### Pattern 5: Base Image Hardening

**When to Use**: Building secure container images

**Implementation**:
```dockerfile
# Use minimal base image
FROM cgr.dev/chainguard/node:latest AS base
# OR
FROM gcr.io/distroless/nodejs:18

# Multi-stage build
FROM node:20-alpine AS builder
WORKDIR /app

# Copy only package files first (cache dependencies)
COPY package*.json ./
RUN npm ci --only=production

# Copy source and build
COPY . .
RUN npm run build

# Production stage - minimal image
FROM gcr.io/distroless/nodejs:18 AS production
WORKDIR /app

# Copy only necessary files
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# Non-root user (distroless handles this)
USER nonroot

EXPOSE 8080
CMD ["dist/server.js"]
```

**Dockerfile best practices**:
```dockerfile
# Pin versions
FROM node:20.10.0-alpine3.18@sha256:abc123...

# Update packages (for non-distroless)
RUN apk update && apk upgrade --no-cache

# Remove unnecessary packages
RUN apk del curl wget

# Don't run as root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Set read-only filesystem friendly
ENV NODE_ENV=production
WORKDIR /app

# Minimize layers
COPY --chown=appuser:appgroup . .
RUN npm ci --only=production && npm cache clean --force
```

### Pattern 6: Vulnerability Tracking Dashboard

**When to Use**: Managing vulnerabilities across many images

**Implementation**:
```typescript
// Vulnerability aggregation service
interface VulnerabilityReport {
  image: string;
  digest: string;
  scanDate: Date;
  vulnerabilities: Vulnerability[];
  summary: {
    critical: number;
    high: number;
    medium: number;
    low: number;
  };
}

class VulnerabilityTracker {
  async ingestScanResults(report: TrivyReport): Promise<void> {
    const normalized = this.normalizeReport(report);

    // Store in database
    await this.db.vulnerabilities.upsert({
      where: { imageDigest: normalized.digest },
      create: normalized,
      update: normalized
    });

    // Check thresholds
    await this.checkThresholds(normalized);
  }

  async checkThresholds(report: VulnerabilityReport): Promise<void> {
    if (report.summary.critical > 0) {
      await this.notify({
        severity: 'critical',
        message: `Critical vulnerabilities in ${report.image}`,
        details: report.vulnerabilities.filter(v => v.severity === 'CRITICAL')
      });
    }
  }

  async getVulnerabilityTrends(days: number = 30): Promise<TrendData> {
    return this.db.vulnerabilities.aggregate({
      where: {
        scanDate: { gte: new Date(Date.now() - days * 24 * 60 * 60 * 1000) }
      },
      groupBy: ['scanDate'],
      _sum: {
        criticalCount: true,
        highCount: true
      }
    });
  }
}
```

## Checklist

- [ ] Scanning integrated in CI/CD pipeline
- [ ] Critical/High vulnerabilities block deployment
- [ ] Registry scanning enabled for continuous monitoring
- [ ] Base images are minimal (distroless, alpine)
- [ ] Images use digests, not mutable tags
- [ ] SBOM generated for each image
- [ ] Vulnerability exceptions documented
- [ ] SLA defined for each severity level
- [ ] Dashboard tracks vulnerability trends
- [ ] Regular base image updates scheduled

## References

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Grype Documentation](https://github.com/anchore/grype)
- [Distroless Images](https://github.com/GoogleContainerTools/distroless)
- [NIST Container Security Guide](https://csrc.nist.gov/publications/detail/sp/800-190/final)
