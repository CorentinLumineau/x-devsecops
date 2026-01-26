---
title: Release Automation Reference
category: delivery
type: reference
version: "1.0.0"
---

# Release Automation

> Part of the delivery/release-management knowledge skill

## Overview

Release automation reduces manual errors and accelerates delivery. This reference covers automated versioning, release pipelines, and deployment orchestration.

## Quick Reference (80/20)

| Tool | Purpose |
|------|---------|
| semantic-release | Automated versioning and publishing |
| release-please | Google's release automation |
| changesets | Monorepo versioning |
| goreleaser | Go binary releases |
| standard-version | Changelog and versioning |

## Patterns

### Pattern 1: Semantic Release

**When to Use**: Fully automated releases based on commits

**Example**:
```json
// package.json
{
  "name": "myapp",
  "version": "0.0.0-semantically-released",
  "scripts": {
    "release": "semantic-release"
  },
  "devDependencies": {
    "@semantic-release/changelog": "^6.0.0",
    "@semantic-release/git": "^10.0.0",
    "semantic-release": "^22.0.0"
  }
}
```

```javascript
// .releaserc.js
module.exports = {
  branches: [
    'main',
    { name: 'next', prerelease: true },
    { name: 'beta', prerelease: true }
  ],
  plugins: [
    // Analyze commits to determine version bump
    ['@semantic-release/commit-analyzer', {
      preset: 'conventionalcommits',
      releaseRules: [
        { breaking: true, release: 'major' },
        { type: 'feat', release: 'minor' },
        { type: 'fix', release: 'patch' },
        { type: 'perf', release: 'patch' },
        { type: 'revert', release: 'patch' },
        { scope: 'no-release', release: false }
      ]
    }],

    // Generate release notes
    ['@semantic-release/release-notes-generator', {
      preset: 'conventionalcommits'
    }],

    // Update CHANGELOG.md
    ['@semantic-release/changelog', {
      changelogFile: 'CHANGELOG.md'
    }],

    // Update package.json version
    '@semantic-release/npm',

    // Commit changes
    ['@semantic-release/git', {
      assets: ['CHANGELOG.md', 'package.json', 'package-lock.json'],
      message: 'chore(release): ${nextRelease.version}\n\n${nextRelease.notes}'
    }],

    // Create GitHub release
    '@semantic-release/github'
  ]
};
```

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main, next, beta]

permissions:
  contents: write
  issues: write
  pull-requests: write
  id-token: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
        run: npx semantic-release
```

**Anti-Pattern**: Manual version bumps in CI.

### Pattern 2: Release Please (Google)

**When to Use**: PR-based release workflow

**Example**:
```yaml
# .github/workflows/release-please.yml
on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
    steps:
      - uses: google-github-actions/release-please-action@v4
        id: release
        with:
          release-type: node
          package-name: myapp
          changelog-types: |
            [
              {"type":"feat","section":"Features","hidden":false},
              {"type":"fix","section":"Bug Fixes","hidden":false},
              {"type":"perf","section":"Performance","hidden":false},
              {"type":"docs","section":"Documentation","hidden":true},
              {"type":"chore","section":"Miscellaneous","hidden":true}
            ]

  publish:
    needs: release-please
    if: ${{ needs.release-please.outputs.release_created }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - run: npm ci
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

```json
// release-please-config.json
{
  "packages": {
    ".": {
      "release-type": "node",
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": true,
      "draft": false,
      "prerelease": false
    }
  }
}
```

**Anti-Pattern**: Skipping the release PR review.

### Pattern 3: Monorepo Release (Changesets)

**When to Use**: Versioning multiple packages

**Example**:
```bash
# Initialize changesets
npx @changesets/cli init
```

```json
// .changeset/config.json
{
  "$schema": "https://unpkg.com/@changesets/config@3.0.0/schema.json",
  "changelog": [
    "@changesets/changelog-github",
    { "repo": "org/repo" }
  ],
  "commit": false,
  "fixed": [],
  "linked": [
    ["@myorg/core", "@myorg/utils"]
  ],
  "access": "public",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
```

```bash
# Create a changeset
npx changeset
# ? What packages would you like to include?
# ? Which packages should have a major bump?
# ? Summary: Add new authentication feature

# This creates .changeset/random-name.md
```

```markdown
<!-- .changeset/orange-panda-dance.md -->
---
"@myorg/auth": minor
"@myorg/core": patch
---

Add OAuth 2.0 support to authentication package
```

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - run: npm ci

      - name: Create Release PR or Publish
        uses: changesets/action@v1
        with:
          version: npm run version
          publish: npm run release
          commit: 'chore: version packages'
          title: 'chore: version packages'
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

```json
// package.json (root)
{
  "scripts": {
    "version": "changeset version && npm install --package-lock-only",
    "release": "npm run build && changeset publish"
  }
}
```

**Anti-Pattern**: Independent versioning without linked packages.

### Pattern 4: Go Releaser

**When to Use**: Go binary releases with multiple platforms

**Example**:
```yaml
# .goreleaser.yaml
version: 2

project_name: myapp

before:
  hooks:
    - go mod tidy
    - go generate ./...

builds:
  - id: myapp
    main: ./cmd/myapp
    binary: myapp
    env:
      - CGO_ENABLED=0
    goos:
      - linux
      - darwin
      - windows
    goarch:
      - amd64
      - arm64
    ldflags:
      - -s -w
      - -X main.version={{.Version}}
      - -X main.commit={{.Commit}}
      - -X main.date={{.Date}}

archives:
  - id: default
    format: tar.gz
    name_template: >-
      {{ .ProjectName }}_
      {{- .Version }}_
      {{- .Os }}_
      {{- .Arch }}
    format_overrides:
      - goos: windows
        format: zip
    files:
      - LICENSE
      - README.md

checksum:
  name_template: 'checksums.txt'

snapshot:
  name_template: "{{ incpatch .Version }}-next"

changelog:
  sort: asc
  filters:
    exclude:
      - '^docs:'
      - '^test:'
      - '^ci:'

dockers:
  - image_templates:
      - "ghcr.io/org/myapp:{{ .Version }}"
      - "ghcr.io/org/myapp:latest"
    dockerfile: Dockerfile
    build_flag_templates:
      - "--label=org.opencontainers.image.created={{.Date}}"
      - "--label=org.opencontainers.image.revision={{.FullCommit}}"
      - "--label=org.opencontainers.image.version={{.Version}}"

brews:
  - repository:
      owner: org
      name: homebrew-tap
    homepage: https://github.com/org/myapp
    description: My application
    license: MIT
    install: |
      bin.install "myapp"

nfpms:
  - package_name: myapp
    vendor: My Company
    homepage: https://example.com
    maintainer: Team <team@example.com>
    description: My application
    license: MIT
    formats:
      - deb
      - rpm
    dependencies:
      - ca-certificates
```

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write
  packages: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: goreleaser/goreleaser-action@v5
        with:
          version: latest
          args: release --clean
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Anti-Pattern**: Building binaries manually for each platform.

### Pattern 5: Release Gates

**When to Use**: Quality gates before release

**Example**:
```yaml
# .github/workflows/release-gates.yml
name: Release Gates

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to release'
        required: true
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - production

jobs:
  quality-gates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: npm test

      - name: Check code coverage
        run: |
          COVERAGE=$(npm run coverage:report | grep "All files" | awk '{print $4}')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80%"
            exit 1
          fi

      - name: Security scan
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

      - name: License compliance
        run: npx license-checker --production --onlyAllow "MIT;Apache-2.0;BSD-3-Clause;ISC"

  performance-tests:
    needs: quality-gates
    runs-on: ubuntu-latest
    steps:
      - name: Run load tests
        run: |
          k6 run tests/load.js --out json=results.json

      - name: Check performance thresholds
        run: |
          P95=$(jq '.metrics.http_req_duration.values.p95' results.json)
          if (( $(echo "$P95 > 500" | bc -l) )); then
            echo "P95 latency $P95ms exceeds 500ms threshold"
            exit 1
          fi

  approval:
    needs: [quality-gates, performance-tests]
    runs-on: ubuntu-latest
    environment: release-approval
    steps:
      - name: Approval checkpoint
        run: echo "Release approved"

  release:
    needs: approval
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create release
        run: |
          gh release create v${{ inputs.version }} \
            --title "v${{ inputs.version }}" \
            --generate-notes
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  deploy:
    needs: release
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - name: Deploy to ${{ inputs.environment }}
        run: ./deploy.sh ${{ inputs.environment }} ${{ inputs.version }}
```

**Anti-Pattern**: Releasing without quality validation.

### Pattern 6: Rollback Automation

**When to Use**: Automated rollback on failure

**Example**:
```typescript
// release-orchestrator.ts
interface ReleaseConfig {
  version: string;
  environment: string;
  canaryPercentage: number;
  healthCheckUrl: string;
  rollbackOnFailure: boolean;
}

class ReleaseOrchestrator {
  async release(config: ReleaseConfig): Promise<ReleaseResult> {
    const previousVersion = await this.getCurrentVersion(config.environment);

    try {
      // Phase 1: Deploy canary
      console.log(`Deploying canary (${config.canaryPercentage}%)`);
      await this.deployCanary(config);
      await this.waitForHealthy(config.healthCheckUrl);

      // Phase 2: Monitor canary
      console.log('Monitoring canary...');
      const canaryHealthy = await this.monitorCanary(config, 5 * 60 * 1000);

      if (!canaryHealthy) {
        throw new Error('Canary failed health checks');
      }

      // Phase 3: Full rollout
      console.log('Rolling out to all instances');
      await this.fullRollout(config);
      await this.waitForHealthy(config.healthCheckUrl);

      // Phase 4: Post-deployment validation
      const validated = await this.validateDeployment(config);

      if (!validated) {
        throw new Error('Post-deployment validation failed');
      }

      return { success: true, version: config.version };

    } catch (error) {
      console.error('Release failed:', error);

      if (config.rollbackOnFailure) {
        console.log(`Rolling back to ${previousVersion}`);
        await this.rollback(config.environment, previousVersion);
      }

      return {
        success: false,
        version: config.version,
        error: error.message,
        rolledBackTo: previousVersion
      };
    }
  }

  private async monitorCanary(
    config: ReleaseConfig,
    duration: number
  ): Promise<boolean> {
    const startTime = Date.now();
    const checkInterval = 30000; // 30 seconds

    while (Date.now() - startTime < duration) {
      const metrics = await this.getCanaryMetrics(config.environment);

      if (metrics.errorRate > 0.01) {
        console.error(`Error rate ${metrics.errorRate} exceeds threshold`);
        return false;
      }

      if (metrics.p99Latency > 500) {
        console.error(`P99 latency ${metrics.p99Latency}ms exceeds threshold`);
        return false;
      }

      await this.sleep(checkInterval);
    }

    return true;
  }

  private async rollback(environment: string, version: string): Promise<void> {
    // Rollback deployment
    await this.deploy({ environment, version });

    // Clear caches
    await this.clearCaches(environment);

    // Notify team
    await this.notify(`Rolled back ${environment} to ${version}`);
  }
}

// Usage in CI
const orchestrator = new ReleaseOrchestrator();

const result = await orchestrator.release({
  version: process.env.VERSION,
  environment: 'production',
  canaryPercentage: 10,
  healthCheckUrl: 'https://api.example.com/health',
  rollbackOnFailure: true
});

if (!result.success) {
  process.exit(1);
}
```

**Anti-Pattern**: Manual rollbacks under pressure.

## Checklist

- [ ] Versioning automated based on commits
- [ ] Changelog generated automatically
- [ ] Release artifacts built in CI
- [ ] Quality gates enforce standards
- [ ] Environment approvals configured
- [ ] Rollback procedure automated
- [ ] Release notifications sent
- [ ] Artifacts signed and verified
- [ ] Release tested in staging first
- [ ] Documentation updated with release

## References

- [Semantic Release](https://semantic-release.gitbook.io/)
- [Release Please](https://github.com/googleapis/release-please)
- [Changesets](https://github.com/changesets/changesets)
- [GoReleaser](https://goreleaser.com/)
