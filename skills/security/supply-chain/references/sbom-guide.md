---
title: SBOM Generation Guide Reference
category: security
type: reference
version: "1.0.0"
---

# Software Bill of Materials (SBOM) Guide

> Part of the security/supply-chain knowledge skill

## Overview

A Software Bill of Materials (SBOM) is a formal, machine-readable inventory of software components and dependencies. This reference covers SBOM formats, generation tools, and integration patterns for supply chain transparency.

## 80/20 Quick Reference

**SBOM formats comparison:**

| Format | Standard | Best For | Tooling |
|--------|----------|----------|---------|
| SPDX | ISO/IEC 5962 | License compliance | OSS ecosystem |
| CycloneDX | OWASP | Security/VEX | Security tools |
| SWID | ISO/IEC 19770-2 | Software asset mgmt | Enterprise |

**SBOM components to capture:**
- Package name and version
- Supplier/author information
- Unique identifiers (purl, CPE)
- Dependencies (direct and transitive)
- Licenses
- Hashes/checksums

## Patterns

### Pattern 1: SBOM Generation with Syft

**When to Use**: Container images, filesystem scanning

**Implementation**:
```yaml
# GitHub Actions SBOM generation
name: Generate SBOM

on:
  push:
    tags:
      - 'v*'

jobs:
  sbom:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Install Syft
        uses: anchore/sbom-action/download-syft@v0

      - name: Generate filesystem SBOM (SPDX)
        run: |
          syft dir:. -o spdx-json=sbom-spdx.json

      - name: Generate filesystem SBOM (CycloneDX)
        run: |
          syft dir:. -o cyclonedx-json=sbom-cyclonedx.json

      - name: Build container
        run: docker build -t myapp:${{ github.ref_name }} .

      - name: Generate container SBOM
        run: |
          syft myapp:${{ github.ref_name }} \
            -o spdx-json=container-sbom.json

      - name: Upload SBOMs
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: |
            sbom-spdx.json
            sbom-cyclonedx.json
            container-sbom.json

      - name: Attach SBOM to release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: |
            sbom-spdx.json
            sbom-cyclonedx.json
```

**CLI examples**:
```bash
# Scan directory
syft dir:./myproject -o spdx-json

# Scan container image
syft myimage:latest -o cyclonedx-json

# Scan from registry
syft registry:ghcr.io/myorg/myapp:v1.0.0 -o spdx-json

# Multiple output formats
syft . -o spdx-json=sbom.spdx.json -o cyclonedx-json=sbom.cdx.json

# Include file metadata
syft . -o spdx-json --file-metadata

# Scan archive
syft myapp.tar.gz -o spdx-json
```

### Pattern 2: Language-Specific SBOM Generation

**When to Use**: Detailed dependency information

**Implementation**:
```yaml
# Multi-language SBOM generation
name: Multi-Language SBOM

on:
  push:
    branches: [main]

jobs:
  javascript:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: npm ci

      - name: Generate SBOM with npm
        run: |
          npx @cyclonedx/cyclonedx-npm --output-file npm-sbom.json

      - name: Alternative: SPDX with spdx-sbom-generator
        run: |
          npm install -g @spdx/sbom-generator
          spdx-sbom-generator -p . -o spdx

  python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Generate SBOM
        run: |
          pip install cyclonedx-bom
          cyclonedx-py requirements \
            --input requirements.txt \
            --output python-sbom.json \
            --format json

  go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Generate SBOM
        run: |
          go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest
          cyclonedx-gomod mod -json -output go-sbom.json

  java:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Generate SBOM with Maven
        run: |
          mvn org.cyclonedx:cyclonedx-maven-plugin:makeAggregateBom \
            -DoutputFormat=json \
            -DoutputName=java-sbom
```

### Pattern 3: Container SBOM with BuildKit

**When to Use**: Integrated container SBOM generation

**Implementation**:
```dockerfile
# syntax=docker/dockerfile:1.5
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./

USER node
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

```yaml
# Build with SBOM attestation
name: Container with SBOM

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push with SBOM
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          # Generate and attach SBOM
          sbom: true
          # Generate provenance
          provenance: true

      - name: Extract SBOM
        run: |
          docker buildx imagetools inspect \
            ghcr.io/${{ github.repository }}:${{ github.ref_name }} \
            --format '{{ json .SBOM.SPDX }}' > container-sbom.json
```

### Pattern 4: SBOM Attestation and Signing

**When to Use**: Verifiable SBOMs for compliance

**Implementation**:
```yaml
# Sign and attest SBOM
name: Attested SBOM

on:
  push:
    tags: ['v*']

jobs:
  sbom-attest:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
      packages: write
      attestations: write

    steps:
      - uses: actions/checkout@v4

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          artifact-name: sbom.spdx.json
          output-file: sbom.spdx.json

      - name: Install cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign SBOM
        run: |
          cosign sign-blob --yes \
            --output-signature sbom.spdx.json.sig \
            --output-certificate sbom.spdx.json.cert \
            sbom.spdx.json

      - name: Verify SBOM signature
        run: |
          cosign verify-blob \
            --signature sbom.spdx.json.sig \
            --certificate sbom.spdx.json.cert \
            --certificate-identity-regexp ".*github.com/${{ github.repository }}.*" \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com \
            sbom.spdx.json

      - name: Build image
        uses: docker/build-push-action@v5
        id: build
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}

      - name: Attest SBOM
        uses: actions/attest-sbom@v1
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.build.outputs.digest }}
          sbom-path: sbom.spdx.json
```

### Pattern 5: SBOM Analysis and Vulnerability Correlation

**When to Use**: Using SBOM for vulnerability management

**Implementation**:
```typescript
import { parse as parseSpdx } from '@spdx/spdx-sbom-parser';
import { parse as parseCycloneDx } from '@cyclonedx/cyclonedx-library';

interface SBOMComponent {
  name: string;
  version: string;
  purl?: string;
  cpe?: string;
  licenses: string[];
  supplier?: string;
  hashes?: Record<string, string>;
}

class SBOMAnalyzer {
  async parseSBOM(content: string, format: 'spdx' | 'cyclonedx'): Promise<SBOMComponent[]> {
    if (format === 'spdx') {
      return this.parseSpdxSBOM(content);
    }
    return this.parseCycloneDxSBOM(content);
  }

  async correlateVulnerabilities(
    components: SBOMComponent[]
  ): Promise<VulnerabilityReport[]> {
    const reports: VulnerabilityReport[] = [];

    for (const component of components) {
      // Query vulnerability databases
      const vulns = await this.queryVulnDatabases(component);

      if (vulns.length > 0) {
        reports.push({
          component,
          vulnerabilities: vulns,
          riskScore: this.calculateRiskScore(vulns)
        });
      }
    }

    return reports.sort((a, b) => b.riskScore - a.riskScore);
  }

  private async queryVulnDatabases(
    component: SBOMComponent
  ): Promise<Vulnerability[]> {
    const results: Vulnerability[] = [];

    // Query OSV (Open Source Vulnerabilities)
    if (component.purl) {
      const osvResults = await this.queryOSV(component.purl);
      results.push(...osvResults);
    }

    // Query NVD (National Vulnerability Database)
    if (component.cpe) {
      const nvdResults = await this.queryNVD(component.cpe);
      results.push(...nvdResults);
    }

    return this.deduplicateVulns(results);
  }

  async generateVEX(
    sbom: SBOMComponent[],
    vulnerabilities: VulnerabilityReport[]
  ): Promise<VEXDocument> {
    // VEX (Vulnerability Exploitability eXchange)
    return {
      '@context': 'https://openvex.dev/ns',
      '@id': `urn:uuid:${generateUUID()}`,
      author: 'security-team',
      role: 'Document Creator',
      timestamp: new Date().toISOString(),
      version: '1',
      statements: vulnerabilities.map(v => ({
        vulnerability: v.vulnerabilities[0].id,
        products: [{
          '@id': v.component.purl,
          subcomponents: []
        }],
        status: this.determineVexStatus(v),
        justification: this.getJustification(v),
        action_statement: this.getRecommendedAction(v)
      }))
    };
  }

  private determineVexStatus(
    report: VulnerabilityReport
  ): 'not_affected' | 'affected' | 'fixed' | 'under_investigation' {
    // Analyze if vulnerability is exploitable in context
    if (report.vulnerabilities.every(v => v.fixedIn && v.fixedIn <= report.component.version)) {
      return 'fixed';
    }
    // Add more analysis logic
    return 'affected';
  }
}

// Generate license compliance report from SBOM
class LicenseAnalyzer {
  private incompatibleLicenses = new Map<string, string[]>([
    ['GPL-3.0', ['Apache-2.0', 'MIT', 'BSD-3-Clause']],
    ['AGPL-3.0', ['Apache-2.0', 'MIT', 'BSD-3-Clause', 'GPL-2.0']]
  ]);

  analyzeLicenses(
    components: SBOMComponent[],
    projectLicense: string
  ): LicenseReport {
    const issues: LicenseIssue[] = [];
    const licenseCounts = new Map<string, number>();

    for (const component of components) {
      for (const license of component.licenses) {
        // Count licenses
        licenseCounts.set(license, (licenseCounts.get(license) || 0) + 1);

        // Check compatibility
        const incompatible = this.incompatibleLicenses.get(license);
        if (incompatible?.includes(projectLicense)) {
          issues.push({
            component: component.name,
            license,
            issue: `${license} is incompatible with project license ${projectLicense}`,
            severity: 'high'
          });
        }
      }
    }

    return {
      totalComponents: components.length,
      licenseCounts: Object.fromEntries(licenseCounts),
      issues,
      compliant: issues.filter(i => i.severity === 'high').length === 0
    };
  }
}
```

### Pattern 6: SBOM Storage and Distribution

**When to Use**: Enterprise SBOM management

**Implementation**:
```yaml
# Store SBOM in OCI registry
name: SBOM Distribution

on:
  push:
    tags: ['v*']

jobs:
  distribute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          output-file: sbom.spdx.json

      - name: Install ORAS
        run: |
          curl -LO https://github.com/oras-project/oras/releases/download/v1.1.0/oras_1.1.0_linux_amd64.tar.gz
          tar -xzf oras_1.1.0_linux_amd64.tar.gz
          sudo mv oras /usr/local/bin/

      - name: Login to registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | oras login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Push SBOM as OCI artifact
        run: |
          oras push ghcr.io/${{ github.repository }}/sbom:${{ github.ref_name }} \
            --artifact-type application/spdx+json \
            sbom.spdx.json:application/spdx+json

      - name: Reference SBOM from image
        run: |
          oras attach \
            ghcr.io/${{ github.repository }}:${{ github.ref_name }} \
            --artifact-type application/spdx+json \
            sbom.spdx.json
```

```typescript
// SBOM registry service
class SBOMRegistry {
  async storeSBOM(
    artifactRef: string,
    sbom: SBOM,
    metadata: SBOMMetadata
  ): Promise<string> {
    const sbomId = generateUUID();

    // Store in database
    await this.db.sboms.create({
      id: sbomId,
      artifactRef,
      format: sbom.format,
      content: JSON.stringify(sbom),
      componentCount: sbom.components.length,
      createdAt: new Date(),
      ...metadata
    });

    // Index components for search
    await this.indexComponents(sbomId, sbom.components);

    return sbomId;
  }

  async findAffectedArtifacts(
    vulnerabilityId: string
  ): Promise<AffectedArtifact[]> {
    // Find all SBOMs containing affected component
    const affectedComponents = await this.vulnDb.getAffectedPackages(vulnerabilityId);

    const affected: AffectedArtifact[] = [];

    for (const component of affectedComponents) {
      const sboms = await this.db.sboms.findByComponent(
        component.name,
        component.affectedVersions
      );

      affected.push(...sboms.map(s => ({
        artifactRef: s.artifactRef,
        component: component.name,
        version: s.componentVersion,
        sbomId: s.id
      })));
    }

    return affected;
  }
}
```

## Checklist

- [ ] SBOM generated for every release
- [ ] SBOM includes all dependencies (direct and transitive)
- [ ] SBOM signed and verifiable
- [ ] SBOM attached to container images
- [ ] SBOM stored and indexed for search
- [ ] Vulnerability correlation automated
- [ ] License compliance checked from SBOM
- [ ] VEX documents generated for known vulnerabilities
- [ ] SBOM format supports downstream tooling
- [ ] SBOM distribution mechanism established

## References

- [SPDX Specification](https://spdx.dev/specifications/)
- [CycloneDX Specification](https://cyclonedx.org/specification/overview/)
- [NTIA SBOM Minimum Elements](https://www.ntia.gov/files/ntia/publications/sbom_minimum_elements_report.pdf)
- [Syft Documentation](https://github.com/anchore/syft)
- [OpenVEX](https://github.com/openvex/spec)
