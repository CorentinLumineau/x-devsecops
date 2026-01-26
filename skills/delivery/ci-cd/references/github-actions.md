---
title: GitHub Actions Reference
category: delivery
type: reference
version: "1.0.0"
---

# GitHub Actions

> Part of the delivery/ci-cd knowledge skill

## Overview

GitHub Actions enables CI/CD workflows directly in GitHub repositories. This reference covers workflow syntax, common patterns, and best practices for automation.

## Quick Reference (80/20)

| Concept | Purpose |
|---------|---------|
| Workflow | Automated process triggered by events |
| Job | Set of steps running on same runner |
| Step | Individual task within a job |
| Action | Reusable unit of code |
| Matrix | Run job with multiple configurations |
| Artifacts | Persist data between jobs |

## Patterns

### Pattern 1: Basic CI Workflow

**When to Use**: Standard test and build pipeline

**Example**:
```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix:
        node-version: [18, 20]
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test -- --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          fail_ci_if_error: true

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
          retention-days: 7
```

**Anti-Pattern**: Not using caching, slow pipelines.

### Pattern 2: Reusable Workflows

**When to Use**: Sharing workflows across repositories

**Example**:
```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      version:
        required: true
        type: string
    secrets:
      AWS_ACCESS_KEY_ID:
        required: true
      AWS_SECRET_ACCESS_KEY:
        required: true
    outputs:
      deployment_url:
        description: URL of the deployment
        value: ${{ jobs.deploy.outputs.url }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    outputs:
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - uses: actions/checkout@v4

      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Deploy to ${{ inputs.environment }}
        id: deploy
        run: |
          # Deploy logic
          echo "url=https://${{ inputs.environment }}.example.com" >> $GITHUB_OUTPUT

# Calling workflow
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  build:
    # ... build job

  deploy-staging:
    needs: build
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      version: ${{ github.sha }}
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}

  deploy-production:
    needs: deploy-staging
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
      version: ${{ github.sha }}
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**Anti-Pattern**: Duplicating workflow code across repositories.

### Pattern 3: Matrix Builds

**When to Use**: Testing across multiple configurations

**Example**:
```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node-version: [18, 20, 22]
        exclude:
          - os: windows-latest
            node-version: 18
        include:
          - os: ubuntu-latest
            node-version: 20
            coverage: true

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test ${{ matrix.coverage && '-- --coverage' || '' }}

      - name: Upload coverage
        if: matrix.coverage
        uses: codecov/codecov-action@v4
```

**Anti-Pattern**: Testing all combinations when most are redundant.

### Pattern 4: Composite Actions

**When to Use**: Creating reusable action steps

**Example**:
```yaml
# .github/actions/setup-project/action.yml
name: Setup Project
description: Setup Node.js project with caching

inputs:
  node-version:
    description: Node.js version
    required: false
    default: '20'
  install-command:
    description: Install command
    required: false
    default: 'npm ci'

outputs:
  cache-hit:
    description: Whether cache was hit
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: composite
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}

    - name: Get npm cache directory
      id: npm-cache
      shell: bash
      run: echo "dir=$(npm config get cache)" >> $GITHUB_OUTPUT

    - name: Cache npm dependencies
      id: cache
      uses: actions/cache@v4
      with:
        path: ${{ steps.npm-cache.outputs.dir }}
        key: ${{ runner.os }}-node-${{ inputs.node-version }}-${{ hashFiles('**/package-lock.json') }}
        restore-keys: |
          ${{ runner.os }}-node-${{ inputs.node-version }}-

    - name: Install dependencies
      shell: bash
      run: ${{ inputs.install-command }}

# Usage in workflow
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup
        uses: ./.github/actions/setup-project
        with:
          node-version: '20'

      - name: Build
        run: npm run build
```

**Anti-Pattern**: Repeating setup steps in every job.

### Pattern 5: Environment Protection

**When to Use**: Controlled deployments with approvals

**Example**:
```yaml
# Requires environment protection rules in GitHub settings
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - name: Deploy to staging
        run: ./deploy.sh staging

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment:
      name: production
      url: https://example.com
    steps:
      - name: Deploy to production
        run: ./deploy.sh production

# With manual approval gate
  approval:
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment: production-approval
    steps:
      - name: Approval checkpoint
        run: echo "Approved for production deployment"

  deploy-production:
    runs-on: ubuntu-latest
    needs: approval
    environment: production
    steps:
      - name: Deploy
        run: ./deploy.sh production
```

**Anti-Pattern**: Direct production deployments without protection.

### Pattern 6: Secrets and Security

**When to Use**: Handling sensitive data securely

**Example**:
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # For OIDC

    steps:
      - uses: actions/checkout@v4

      # Use OIDC instead of long-lived credentials
      - name: Configure AWS credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/GitHubActions
          aws-region: us-east-1

      # Access secrets
      - name: Deploy with secrets
        env:
          API_KEY: ${{ secrets.API_KEY }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          # Never echo secrets
          ./deploy.sh

      # Mask dynamic secrets
      - name: Generate and mask token
        run: |
          TOKEN=$(generate-token)
          echo "::add-mask::$TOKEN"
          echo "TOKEN=$TOKEN" >> $GITHUB_ENV

      # Use step outputs for sensitive data
      - name: Get credentials
        id: creds
        run: |
          CRED=$(vault read secret/app)
          echo "::add-mask::$CRED"
          echo "credential=$CRED" >> $GITHUB_OUTPUT

      - name: Use credentials
        env:
          CREDENTIAL: ${{ steps.creds.outputs.credential }}
        run: ./use-credential.sh
```

**Anti-Pattern**: Hardcoding secrets or echoing them in logs.

## Checklist

- [ ] Workflows triggered on appropriate events
- [ ] Concurrency configured to prevent duplicate runs
- [ ] Caching used for dependencies
- [ ] Matrix builds for cross-platform testing
- [ ] Reusable workflows for shared logic
- [ ] Environment protection for deployments
- [ ] Secrets properly managed
- [ ] Minimal permissions granted
- [ ] Artifacts retained appropriately
- [ ] Status checks required on PRs

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
