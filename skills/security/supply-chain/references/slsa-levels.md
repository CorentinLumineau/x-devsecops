---
title: SLSA Framework Levels Reference
category: security
type: reference
version: "1.0.0"
---

# SLSA Framework Levels and Requirements

> Part of the security/supply-chain knowledge skill

## Overview

Supply-chain Levels for Software Artifacts (SLSA, pronounced "salsa") is a security framework for ensuring the integrity of software artifacts throughout the supply chain. This reference covers SLSA levels, requirements, and implementation patterns.

## 80/20 Quick Reference

**SLSA Levels summary:**

| Level | Focus | Key Requirements |
|-------|-------|------------------|
| SLSA 1 | Documentation | Provenance exists |
| SLSA 2 | Tamper resistance | Hosted build, signed provenance |
| SLSA 3 | Hardened builds | Isolated, parameterless builds |
| SLSA 4 | Two-party review | Hermetic, reproducible builds |

**Quick wins for SLSA compliance:**
1. Generate provenance (SLSA 1)
2. Use hosted CI/CD (SLSA 2)
3. Sign artifacts (SLSA 2)
4. Isolate build environments (SLSA 3)

## Patterns

### Pattern 1: SLSA 1 - Provenance Generation

**When to Use**: Starting SLSA journey, basic supply chain visibility

**Implementation**:
```yaml
# GitHub Actions with SLSA 1 provenance
name: Build with Provenance

on:
  push:
    branches: [main]
  release:
    types: [created]

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Build artifact
        id: build
        run: |
          npm ci
          npm run build

          # Calculate digest
          DIGEST=$(sha256sum dist/app.js | cut -d' ' -f1)
          echo "digest=sha256:${DIGEST}" >> $GITHUB_OUTPUT

      - name: Generate SLSA provenance
        run: |
          cat > provenance.json << EOF
          {
            "_type": "https://in-toto.io/Statement/v0.1",
            "subject": [
              {
                "name": "app.js",
                "digest": {
                  "sha256": "${{ steps.build.outputs.digest }}"
                }
              }
            ],
            "predicateType": "https://slsa.dev/provenance/v0.2",
            "predicate": {
              "builder": {
                "id": "https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }}"
              },
              "buildType": "https://github.com/actions/runner",
              "invocation": {
                "configSource": {
                  "uri": "git+https://github.com/${{ github.repository }}@${{ github.ref }}",
                  "digest": {
                    "sha1": "${{ github.sha }}"
                  },
                  "entryPoint": ".github/workflows/build.yml"
                }
              },
              "metadata": {
                "buildStartedOn": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
                "buildFinishedOn": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
                "completeness": {
                  "parameters": true,
                  "environment": false,
                  "materials": true
                },
                "reproducible": false
              },
              "materials": [
                {
                  "uri": "git+https://github.com/${{ github.repository }}",
                  "digest": {
                    "sha1": "${{ github.sha }}"
                  }
                }
              ]
            }
          }
          EOF

      - name: Upload provenance
        uses: actions/upload-artifact@v4
        with:
          name: provenance
          path: provenance.json
```

### Pattern 2: SLSA 2 - Hosted Build with Signed Provenance

**When to Use**: Tamper-resistant builds with verifiable provenance

**Implementation**:
```yaml
# GitHub Actions with SLSA 2 using official generator
name: SLSA Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}

    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: |
          npm ci --ignore-scripts
          npm run build
          tar -czf dist.tar.gz dist/

      - name: Generate hash
        id: hash
        run: |
          HASH=$(sha256sum dist.tar.gz | base64 -w0)
          echo "hashes=${HASH}" >> $GITHUB_OUTPUT

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist.tar.gz

  provenance:
    needs: [build]
    permissions:
      actions: read
      id-token: write
      contents: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v1.9.0
    with:
      base64-subjects: "${{ needs.build.outputs.hashes }}"
      upload-assets: true

  verify:
    needs: [build, provenance]
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: dist

      - name: Download provenance
        uses: actions/download-artifact@v4
        with:
          name: dist.tar.gz.intoto.jsonl

      - name: Verify provenance
        uses: slsa-framework/slsa-verifier/actions/installer@v2.4.1

      - name: Run verification
        run: |
          slsa-verifier verify-artifact dist.tar.gz \
            --provenance-path dist.tar.gz.intoto.jsonl \
            --source-uri github.com/${{ github.repository }} \
            --source-tag ${{ github.ref_name }}
```

**Container image with Sigstore**:
```yaml
# SLSA 2 container builds with cosign signing
name: Container Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write

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

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          provenance: true
          sbom: true

      - name: Install cosign
        uses: sigstore/cosign-installer@v3

      - name: Sign image
        run: |
          cosign sign --yes \
            ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}

      - name: Verify signature
        run: |
          cosign verify \
            --certificate-identity-regexp ".*github.com/${{ github.repository }}.*" \
            --certificate-oidc-issuer https://token.actions.githubusercontent.com \
            ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}
```

### Pattern 3: SLSA 3 - Isolated Build Environment

**When to Use**: High-security requirements, isolated builds

**Implementation**:
```yaml
# SLSA 3 with isolated build environment
name: SLSA 3 Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      # Isolated build environment - no network access during build
      - name: Build in isolated environment
        run: |
          # Download dependencies first (network allowed)
          npm ci --ignore-scripts

          # Build with network disabled
          docker run --rm \
            --network none \
            -v $(pwd):/workspace \
            -w /workspace \
            node:20-alpine \
            sh -c "npm run build"

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          artifact-name: sbom.spdx.json

      - name: Attest SBOM
        uses: actions/attest-sbom@v1
        with:
          subject-path: 'dist/**'
          sbom-path: 'sbom.spdx.json'

  # Use SLSA generator for provenance
  provenance:
    needs: [build]
    permissions:
      actions: read
      id-token: write
      contents: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v1.9.0
    with:
      base64-subjects: "${{ needs.build.outputs.hashes }}"
```

### Pattern 4: Provenance Verification

**When to Use**: Consuming SLSA-attested artifacts

**Implementation**:
```typescript
// Programmatic SLSA verification
import { verifyProvenance } from '@sigstore/verify';

interface VerificationResult {
  verified: boolean;
  builderID: string;
  sourceURI: string;
  digest: string;
  buildTimestamp: Date;
}

async function verifySLSAProvenance(
  artifactPath: string,
  provenancePath: string,
  expectedSource: string
): Promise<VerificationResult> {
  // Load artifact and provenance
  const artifact = await fs.readFile(artifactPath);
  const provenance = JSON.parse(await fs.readFile(provenancePath, 'utf8'));

  // Verify signature
  const signatureVerified = await verifyProvenance(provenance);
  if (!signatureVerified) {
    throw new Error('Provenance signature verification failed');
  }

  // Verify artifact digest matches
  const artifactDigest = crypto
    .createHash('sha256')
    .update(artifact)
    .digest('hex');

  const provenanceDigest = provenance.subject[0].digest.sha256;
  if (artifactDigest !== provenanceDigest) {
    throw new Error('Artifact digest mismatch');
  }

  // Verify source
  const sourceURI = provenance.predicate.invocation.configSource.uri;
  if (!sourceURI.includes(expectedSource)) {
    throw new Error(`Unexpected source: ${sourceURI}`);
  }

  // Verify builder
  const builderID = provenance.predicate.builder.id;
  const trustedBuilders = [
    'https://github.com/slsa-framework/slsa-github-generator',
    'https://cloudbuild.googleapis.com/GoogleHostedWorker'
  ];

  if (!trustedBuilders.some(b => builderID.startsWith(b))) {
    throw new Error(`Untrusted builder: ${builderID}`);
  }

  return {
    verified: true,
    builderID,
    sourceURI,
    digest: artifactDigest,
    buildTimestamp: new Date(provenance.predicate.metadata.buildFinishedOn)
  };
}

// CLI verification with slsa-verifier
async function verifyWithCLI(
  artifactPath: string,
  provenancePath: string,
  sourceRepo: string,
  sourceTag: string
): Promise<void> {
  const { execSync } = require('child_process');

  execSync(`slsa-verifier verify-artifact ${artifactPath} \
    --provenance-path ${provenancePath} \
    --source-uri github.com/${sourceRepo} \
    --source-tag ${sourceTag}`, {
    stdio: 'inherit'
  });
}
```

### Pattern 5: Policy Enforcement

**When to Use**: Enforcing SLSA requirements in deployment

**Implementation**:
```yaml
# Kyverno policy for SLSA verification
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-slsa-provenance
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
    - name: check-slsa-provenance
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestations:
            - predicateType: "https://slsa.dev/provenance/v0.2"
              conditions:
                - all:
                    # Verify builder
                    - key: "{{ builder.id }}"
                      operator: Equals
                      value: "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@*"
                    # Verify source
                    - key: "{{ invocation.configSource.uri }}"
                      operator: Equals
                      value: "git+https://github.com/myorg/*"
---
# OPA/Gatekeeper constraint
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: SLSAProvenance
metadata:
  name: require-slsa-level-2
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - production
  parameters:
    minimumLevel: 2
    trustedBuilders:
      - "https://github.com/slsa-framework/slsa-github-generator"
    trustedSources:
      - "github.com/myorg"
```

### Pattern 6: SLSA Compliance Dashboard

**When to Use**: Tracking SLSA adoption across organization

**Implementation**:
```typescript
interface SLSAComplianceStatus {
  repository: string;
  currentLevel: 0 | 1 | 2 | 3;
  requirements: {
    level1: RequirementStatus;
    level2: RequirementStatus;
    level3: RequirementStatus;
  };
  lastBuildVerified: Date;
  artifacts: ArtifactStatus[];
}

class SLSAComplianceTracker {
  async assessRepository(repo: string): Promise<SLSAComplianceStatus> {
    const workflows = await this.getWorkflows(repo);
    const releases = await this.getRecentReleases(repo);

    return {
      repository: repo,
      currentLevel: this.determineLevel(workflows, releases),
      requirements: {
        level1: await this.checkLevel1Requirements(repo, workflows),
        level2: await this.checkLevel2Requirements(repo, workflows),
        level3: await this.checkLevel3Requirements(repo, workflows)
      },
      lastBuildVerified: await this.getLastVerifiedBuild(repo),
      artifacts: await this.getArtifactStatuses(releases)
    };
  }

  private async checkLevel1Requirements(
    repo: string,
    workflows: Workflow[]
  ): Promise<RequirementStatus> {
    return {
      met: true,
      requirements: [
        {
          id: 'provenance-exists',
          description: 'Provenance is generated for builds',
          status: this.hasProvenanceGeneration(workflows)
        },
        {
          id: 'provenance-available',
          description: 'Provenance is available to consumers',
          status: await this.isProvenancePublished(repo)
        }
      ]
    };
  }

  private async checkLevel2Requirements(
    repo: string,
    workflows: Workflow[]
  ): Promise<RequirementStatus> {
    return {
      met: true,
      requirements: [
        {
          id: 'hosted-build',
          description: 'Build runs on hosted service',
          status: this.usesHostedBuild(workflows)
        },
        {
          id: 'signed-provenance',
          description: 'Provenance is signed',
          status: await this.hasSignedProvenance(repo)
        },
        {
          id: 'authenticated-provenance',
          description: 'Provenance generated by build service',
          status: this.usesOfficialGenerator(workflows)
        }
      ]
    };
  }

  async generateComplianceReport(
    organization: string
  ): Promise<OrganizationComplianceReport> {
    const repos = await this.getOrgRepositories(organization);
    const statuses = await Promise.all(
      repos.map(r => this.assessRepository(r))
    );

    return {
      organization,
      generatedAt: new Date(),
      summary: {
        totalRepos: statuses.length,
        level0: statuses.filter(s => s.currentLevel === 0).length,
        level1: statuses.filter(s => s.currentLevel === 1).length,
        level2: statuses.filter(s => s.currentLevel === 2).length,
        level3: statuses.filter(s => s.currentLevel === 3).length
      },
      repositories: statuses,
      recommendations: this.generateRecommendations(statuses)
    };
  }
}
```

## Checklist

**SLSA Level 1**
- [ ] Provenance generated for all builds
- [ ] Provenance published with artifacts
- [ ] Build process documented

**SLSA Level 2**
- [ ] Builds run on hosted CI/CD platform
- [ ] Provenance signed by build service
- [ ] Using official SLSA generator or equivalent
- [ ] Source and builder authenticated

**SLSA Level 3**
- [ ] Builds isolated from other tenants
- [ ] Build parameters not user-controlled
- [ ] Ephemeral build environments
- [ ] Build service is hardened

**Verification**
- [ ] Provenance verification in deployment pipeline
- [ ] Policy enforcement for SLSA requirements
- [ ] Audit trail of verification results

## References

- [SLSA Specification](https://slsa.dev/spec/v1.0/)
- [SLSA GitHub Generator](https://github.com/slsa-framework/slsa-github-generator)
- [SLSA Verifier](https://github.com/slsa-framework/slsa-verifier)
- [Sigstore](https://www.sigstore.dev/)
