---
title: GitLab CI Reference
category: delivery
type: reference
version: "1.0.0"
---

# GitLab CI

> Part of the delivery/ci-cd knowledge skill

## Overview

GitLab CI/CD is integrated directly into GitLab, providing powerful pipeline capabilities. This reference covers pipeline configuration, stages, and advanced patterns.

## Quick Reference (80/20)

| Concept | Purpose |
|---------|---------|
| Pipeline | Collection of jobs organized in stages |
| Stage | Group of jobs that run in parallel |
| Job | Individual task with scripts |
| Runner | Agent that executes jobs |
| Artifact | Files passed between jobs |
| Cache | Dependencies reused across pipelines |

## Patterns

### Pattern 1: Basic Pipeline Structure

**When to Use**: Standard CI/CD pipeline

**Example**:
```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - build
  - deploy

default:
  image: node:20-alpine
  cache:
    key:
      files:
        - package-lock.json
    paths:
      - node_modules/
    policy: pull

variables:
  npm_config_cache: "$CI_PROJECT_DIR/.npm"
  FF_USE_FASTZIP: "true"

# Templates
.node_setup:
  before_script:
    - npm ci --cache .npm --prefer-offline

lint:
  stage: lint
  extends: .node_setup
  script:
    - npm run lint
  cache:
    policy: pull-push

test:
  stage: test
  extends: .node_setup
  script:
    - npm test -- --coverage
  coverage: '/All files\s+\|\s+[\d.]+\s+\|\s+[\d.]+\s+\|\s+[\d.]+\s+\|\s+([\d.]+)/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
      junit: junit.xml
    paths:
      - coverage/
    expire_in: 1 week

build:
  stage: build
  extends: .node_setup
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 day
  only:
    - main
    - merge_requests

deploy_staging:
  stage: deploy
  image: alpine:latest
  script:
    - apk add --no-cache curl
    - ./deploy.sh staging
  environment:
    name: staging
    url: https://staging.example.com
  only:
    - main

deploy_production:
  stage: deploy
  script:
    - ./deploy.sh production
  environment:
    name: production
    url: https://example.com
  when: manual
  only:
    - main
```

**Anti-Pattern**: No stages defined, all jobs run in default stage.

### Pattern 2: Include and Extend

**When to Use**: Reusing configuration across projects

**Example**:
```yaml
# templates/node-ci.yml (in shared repository)
.node_defaults:
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/

.lint_template:
  extends: .node_defaults
  stage: lint
  script:
    - npm ci
    - npm run lint

.test_template:
  extends: .node_defaults
  stage: test
  script:
    - npm ci
    - npm test

.build_template:
  extends: .node_defaults
  stage: build
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/

# Project .gitlab-ci.yml
include:
  - project: 'devops/ci-templates'
    ref: main
    file: '/templates/node-ci.yml'
  - local: '/.gitlab/security.yml'
  - remote: 'https://example.com/templates/deploy.yml'
  - template: Security/SAST.gitlab-ci.yml

stages:
  - lint
  - test
  - build
  - security
  - deploy

lint:
  extends: .lint_template

test:
  extends: .test_template
  coverage: '/Lines\s*:\s*(\d+\.\d+)%/'

build:
  extends: .build_template
  only:
    - main
    - merge_requests
```

**Anti-Pattern**: Copy-pasting CI configuration between projects.

### Pattern 3: Dynamic Child Pipelines

**When to Use**: Monorepos, dynamic pipeline generation

**Example**:
```yaml
# Parent pipeline
stages:
  - generate
  - trigger

generate_pipelines:
  stage: generate
  image: python:3.11
  script:
    - python scripts/generate-pipelines.py
  artifacts:
    paths:
      - generated-pipelines/

trigger_service_a:
  stage: trigger
  trigger:
    include:
      - artifact: generated-pipelines/service-a.yml
        job: generate_pipelines
    strategy: depend
  rules:
    - changes:
        - services/service-a/**/*

trigger_service_b:
  stage: trigger
  trigger:
    include:
      - artifact: generated-pipelines/service-b.yml
        job: generate_pipelines
    strategy: depend
  rules:
    - changes:
        - services/service-b/**/*

# scripts/generate-pipelines.py
import yaml
import os

services = ['service-a', 'service-b', 'service-c']

for service in services:
    pipeline = {
        'stages': ['test', 'build', 'deploy'],
        'variables': {
            'SERVICE_NAME': service
        },
        'test': {
            'stage': 'test',
            'image': 'node:20',
            'script': [
                f'cd services/{service}',
                'npm ci',
                'npm test'
            ]
        },
        'build': {
            'stage': 'build',
            'image': 'docker:24',
            'services': ['docker:24-dind'],
            'script': [
                f'docker build -t {service}:$CI_COMMIT_SHA services/{service}'
            ]
        }
    }

    os.makedirs('generated-pipelines', exist_ok=True)
    with open(f'generated-pipelines/{service}.yml', 'w') as f:
        yaml.dump(pipeline, f)
```

**Anti-Pattern**: Single monolithic pipeline for monorepos.

### Pattern 4: Rules and Workflow

**When to Use**: Conditional job execution

**Example**:
```yaml
workflow:
  rules:
    # Don't run on draft MRs
    - if: $CI_MERGE_REQUEST_TITLE =~ /^Draft:/
      when: never
    # Run on merge requests
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    # Run on main branch
    - if: $CI_COMMIT_BRANCH == "main"
    # Run on tags
    - if: $CI_COMMIT_TAG

variables:
  DEPLOY_ENABLED: "false"

# Override variable for main branch
.main_rules:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      variables:
        DEPLOY_ENABLED: "true"

test:
  stage: test
  script:
    - npm test
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_BRANCH == "develop"

build:
  stage: build
  script:
    - npm run build
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_COMMIT_TAG
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - src/**/*
        - package.json

deploy:
  stage: deploy
  script:
    - ./deploy.sh
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $DEPLOY_ENABLED == "true"
    - if: $CI_COMMIT_TAG
      when: manual
    - when: never

# Complex rules with needs
security_scan:
  stage: test
  needs: []
  script:
    - ./security-scan.sh
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      changes:
        - package*.json
        - Dockerfile
  allow_failure: true
```

**Anti-Pattern**: Using `only/except` instead of `rules` (deprecated).

### Pattern 5: Environments and Deployments

**When to Use**: Managed deployments with review apps

**Example**:
```yaml
stages:
  - build
  - review
  - staging
  - production

build:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

# Dynamic review environments
review:
  stage: review
  script:
    - kubectl apply -f k8s/review/
    - kubectl set image deployment/app app=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    on_stop: stop_review
    auto_stop_in: 1 week
  rules:
    - if: $CI_MERGE_REQUEST_IID

stop_review:
  stage: review
  script:
    - kubectl delete namespace review-$CI_COMMIT_REF_SLUG
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  rules:
    - if: $CI_MERGE_REQUEST_IID
      when: manual

staging:
  stage: staging
  script:
    - ./deploy.sh staging
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

production:
  stage: production
  script:
    - ./deploy.sh production
  environment:
    name: production
    url: https://example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  resource_group: production  # Prevent concurrent deploys
```

**Anti-Pattern**: No environment tracking, manual deployment management.

### Pattern 6: Secrets and Variables

**When to Use**: Secure credential management

**Example**:
```yaml
variables:
  # Public variables
  NODE_ENV: production
  LOG_LEVEL: info

  # File-type variable (defined in GitLab UI)
  # GOOGLE_CREDENTIALS: (File type, contains JSON)

deploy:
  stage: deploy
  variables:
    # Job-specific variable
    DEPLOY_ENV: staging
  script:
    # Access masked variable
    - echo "Deploying with token ${DEPLOY_TOKEN:0:4}..."

    # Use file-type variable
    - gcloud auth activate-service-account --key-file=$GOOGLE_CREDENTIALS

    # HashiCorp Vault integration
    - export DB_PASSWORD=$(vault kv get -field=password secret/db)

  # Protect secrets in job output
  secrets:
    DATABASE_URL:
      vault: production/db/url@secrets
    API_KEY:
      vault:
        engine:
          name: kv-v2
          path: secret
        path: app/api-key
        field: key
  id_tokens:
    VAULT_ID_TOKEN:
      aud: https://vault.example.com

# Using GitLab's secret management
.deploy_template:
  before_script:
    # Access CI/CD variables
    - 'echo "Using: ${CI_ENVIRONMENT_NAME}"'
  script:
    # Variables from protected environments
    - ./deploy.sh
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

**Anti-Pattern**: Storing secrets in repository or exposing in logs.

## Checklist

- [ ] Pipeline stages logically organized
- [ ] Templates used for reusable configuration
- [ ] Include files for shared configuration
- [ ] Rules used instead of only/except
- [ ] Environments defined for deployments
- [ ] Review apps for merge requests
- [ ] Secrets managed securely
- [ ] Caching configured for dependencies
- [ ] Artifacts passed between jobs
- [ ] Resource groups prevent concurrent deploys

## References

- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [.gitlab-ci.yml Reference](https://docs.gitlab.com/ee/ci/yaml/)
- [CI/CD Variables](https://docs.gitlab.com/ee/ci/variables/)
- [Environments and Deployments](https://docs.gitlab.com/ee/ci/environments/)
