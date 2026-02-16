---
title: CI/CD Secrets Management Reference
category: security
type: reference
version: "1.0.0"
---

# CI/CD Secrets Management

> Part of the security/secrets knowledge skill

## Overview

CI/CD pipelines require access to secrets for building, testing, and deploying applications. This reference covers secure secret injection, environment isolation, and provider-specific patterns for GitHub Actions, GitLab CI, and Jenkins.

## 80/20 Quick Reference

**CI/CD secret security priorities:**

| Priority | Practice | Reason |
|----------|----------|--------|
| 1 | Never log secrets | Prevents exposure in build logs |
| 2 | Use secret managers | Centralized control and rotation |
| 3 | Limit scope | Only inject needed secrets |
| 4 | Audit access | Track who uses what |
| 5 | Rotate after exposure | Minimize compromise window |

**Secret injection methods:**
- Environment variables (masked)
- Mounted files (for certificates)
- Secret managers (HashiCorp Vault, AWS Secrets Manager)
- Platform-native secrets (GitHub Secrets, GitLab CI Variables)

## Patterns

### Pattern 1: GitHub Actions Secrets

**When to Use**: GitHub-hosted repositories

**Implementation**:
```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Use GitHub Environments for approval gates

    steps:
      - uses: actions/checkout@v4

      # Secrets are automatically masked in logs
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          # Secrets available as environment variables
          ./deploy.sh

      # Using OIDC for keyless authentication (preferred)
      - name: Configure AWS OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions
          aws-region: us-east-1
          # No static credentials needed!
```

**Organization-level secrets with inheritance**:
```yaml
# Access organization secrets
env:
  NPM_TOKEN: ${{ secrets.NPM_TOKEN }}  # Org secret
  APP_SECRET: ${{ secrets.APP_SECRET }}  # Repo secret (overrides org)
```

**Preventing secret exposure**:
```yaml
- name: Build with secrets
  env:
    SECRET: ${{ secrets.MY_SECRET }}
  run: |
    # WRONG - will be masked but risky
    echo "The secret is $SECRET"

    # WRONG - base64 bypass attempt
    echo "$SECRET" | base64  # Still masked!

    # CORRECT - use secrets, don't print
    ./build.sh  # Script uses SECRET env var internally
```

### Pattern 2: GitLab CI Variables

**When to Use**: GitLab-hosted repositories

**Implementation**:
```yaml
# .gitlab-ci.yml
variables:
  # Non-sensitive defaults
  NODE_ENV: production

stages:
  - build
  - test
  - deploy

build:
  stage: build
  # Protected variables only on protected branches
  only:
    - main
  script:
    - echo "Building with $CI_REGISTRY credentials"
    - docker build -t $CI_REGISTRY_IMAGE .
    - docker push $CI_REGISTRY_IMAGE

deploy_production:
  stage: deploy
  environment:
    name: production
  # Use HashiCorp Vault integration
  secrets:
    DATABASE_URL:
      vault: production/database/url@secrets
    API_KEY:
      vault: production/api/key@secrets
  script:
    - ./deploy.sh
  only:
    - main
  when: manual  # Require approval

# File-type secrets
deploy_with_cert:
  stage: deploy
  script:
    - echo "$DEPLOY_SSH_KEY" > ~/.ssh/id_rsa
    - chmod 600 ~/.ssh/id_rsa
    - ssh user@server "./deploy.sh"
  after_script:
    - rm -f ~/.ssh/id_rsa  # Cleanup
```

**Vault integration**:
```yaml
# GitLab Vault integration
include:
  - template: Security/Secret-Detection.gitlab-ci.yml

variables:
  VAULT_SERVER_URL: https://vault.example.com
  VAULT_AUTH_ROLE: gitlab-ci

.vault_auth: &vault_auth
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com

deploy:
  <<: *vault_auth
  secrets:
    DATABASE_PASSWORD:
      vault: myapp/data/database/password@secrets
      file: false  # Expose as env var, not file
```

### Pattern 3: Jenkins Credentials

**When to Use**: Jenkins-based CI/CD

**Implementation**:
```groovy
// Jenkinsfile
pipeline {
    agent any

    environment {
        // Inject credentials as environment variables
        AWS_ACCESS_KEY_ID = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
    }

    stages {
        stage('Deploy') {
            steps {
                // Using withCredentials for scoped access
                withCredentials([
                    usernamePassword(
                        credentialsId: 'database-creds',
                        usernameVariable: 'DB_USER',
                        passwordVariable: 'DB_PASS'
                    ),
                    string(
                        credentialsId: 'api-key',
                        variable: 'API_KEY'
                    ),
                    file(
                        credentialsId: 'kubeconfig',
                        variable: 'KUBECONFIG_FILE'
                    )
                ]) {
                    sh '''
                        export KUBECONFIG=$KUBECONFIG_FILE
                        kubectl apply -f deployment.yaml
                    '''
                }
            }
        }
    }

    post {
        always {
            // Cleanup any temporary credential files
            cleanWs()
        }
    }
}
```

**HashiCorp Vault plugin**:
```groovy
// Using HashiCorp Vault Plugin
pipeline {
    agent any

    stages {
        stage('Deploy') {
            steps {
                withVault(
                    configuration: [
                        vaultUrl: 'https://vault.example.com',
                        vaultCredentialId: 'vault-approle'
                    ],
                    vaultSecrets: [
                        [
                            path: 'secret/myapp/database',
                            secretValues: [
                                [envVar: 'DB_HOST', vaultKey: 'host'],
                                [envVar: 'DB_PASS', vaultKey: 'password']
                            ]
                        ]
                    ]
                ) {
                    sh './deploy.sh'
                }
            }
        }
    }
}
```

### Pattern 4: External Secret Managers

**When to Use**: Centralized secret management across platforms

**Implementation**:
```yaml
# GitHub Actions with AWS Secrets Manager
name: Deploy
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # For OIDC
      contents: read

    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions
          aws-region: us-east-1

      - name: Get secrets
        uses: aws-actions/aws-secretsmanager-get-secrets@v1
        with:
          secret-ids: |
            DB,myapp/production/database
            API,myapp/production/api-keys
          parse-json-secrets: true

      - name: Deploy
        env:
          DATABASE_URL: ${{ env.DB_URL }}
          API_KEY: ${{ env.API_KEY }}
        run: ./deploy.sh
```

**HashiCorp Vault with GitHub Actions**:
```yaml
name: Deploy with Vault

on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - name: Import Secrets
        uses: hashicorp/vault-action@v2
        with:
          url: https://vault.example.com
          method: jwt
          role: github-actions
          secrets: |
            secret/data/myapp/database password | DATABASE_PASSWORD ;
            secret/data/myapp/api key | API_KEY

      - name: Deploy
        run: |
          # Secrets available as environment variables
          ./deploy.sh
```

### Pattern 5: Secret Scanning and Prevention

**When to Use**: All repositories

**Implementation**:
```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
  pull_request:

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for scanning

      # TruffleHog for secret detection
      - name: TruffleHog Scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD
          extra_args: --only-verified

      # Gitleaks alternative
      - name: Gitleaks Scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Pre-commit hooks**:
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/awslabs/git-secrets
    rev: master
    hooks:
      - id: git-secrets
```

### Pattern 6: Environment-Specific Secrets

**When to Use**: Multiple deployment environments

**Implementation**:
```yaml
# GitHub Actions with environments
name: Deploy

on:
  push:
    branches: [main, develop]

jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment: staging  # Uses staging secrets
    steps:
      - name: Deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}  # Staging DB
        run: ./deploy.sh staging

  deploy-production:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production  # Uses production secrets
    needs: [approval]  # Requires approval
    steps:
      - name: Deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}  # Production DB
        run: ./deploy.sh production
```

**GitLab environment-scoped variables**:
```yaml
# Variables scoped to environments
deploy_staging:
  stage: deploy
  environment: staging
  variables:
    DEPLOY_TARGET: staging
  script:
    - echo "Deploying to $DEPLOY_TARGET"
    - echo "Using $DATABASE_URL"  # Staging-specific
  only:
    - develop

deploy_production:
  stage: deploy
  environment: production
  variables:
    DEPLOY_TARGET: production
  script:
    - echo "Deploying to $DEPLOY_TARGET"
    - echo "Using $DATABASE_URL"  # Production-specific
  only:
    - main
  when: manual
```

## Checklist

- [ ] All secrets stored in platform secret stores (not repo)
- [ ] Secret scanning enabled in CI pipeline
- [ ] Pre-commit hooks prevent secret commits
- [ ] OIDC authentication used where possible (no static credentials)
- [ ] Secrets scoped to specific environments
- [ ] Protected branches/environments for production secrets
- [ ] Build logs reviewed for secret leakage
- [ ] Secret access audited
- [ ] Rotation procedure for CI/CD secrets documented
- [ ] Manual approval gates for production deployments

## References

- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GitLab CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)
- [Jenkins Credentials](https://www.jenkins.io/doc/book/using/using-credentials/)
- [GitHub OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-cloud-providers)
