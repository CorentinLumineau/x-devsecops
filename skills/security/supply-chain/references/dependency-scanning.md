---
title: Dependency Vulnerability Scanning Reference
category: security
type: reference
version: "1.0.0"
---

# Dependency Vulnerability Scanning

> Part of the security/supply-chain knowledge skill

## Overview

Dependency scanning identifies vulnerabilities in third-party libraries and packages. This reference covers scanning tools, CI/CD integration, vulnerability prioritization, and remediation workflows.

## 80/20 Quick Reference

**Scanning tool comparison:**

| Tool | Languages | Features | Best For |
|------|-----------|----------|----------|
| npm audit | JavaScript | Built-in, fast | Quick checks |
| Snyk | Multi-language | Fix PRs, monitoring | Enterprise |
| Dependabot | Multi-language | Auto-PRs, GitHub native | GitHub repos |
| Trivy | Multi-language | Container + deps | DevOps |
| OWASP Dep-Check | Java, .NET | CVSS scores | Enterprise Java |

**Vulnerability severity response:**

| Severity | CVSS | Action | SLA |
|----------|------|--------|-----|
| Critical | 9.0-10.0 | Block + immediate fix | 24 hours |
| High | 7.0-8.9 | Block + prioritize | 7 days |
| Medium | 4.0-6.9 | Track + schedule | 30 days |
| Low | 0.1-3.9 | Track | 90 days |

## Patterns

### Pattern 1: npm Audit Integration

**When to Use**: JavaScript/Node.js projects

**Implementation**:
```yaml
# GitHub Actions with npm audit
name: Security Scan

on:
  push:
  pull_request:
  schedule:
    - cron: '0 9 * * 1'  # Weekly Monday 9am

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci --ignore-scripts

      - name: Run audit
        id: audit
        run: |
          # Run audit and capture output
          npm audit --json > audit-report.json || true

          # Parse results
          CRITICAL=$(jq '.metadata.vulnerabilities.critical' audit-report.json)
          HIGH=$(jq '.metadata.vulnerabilities.high' audit-report.json)

          echo "critical=${CRITICAL}" >> $GITHUB_OUTPUT
          echo "high=${HIGH}" >> $GITHUB_OUTPUT

          # Fail on critical/high
          if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
            echo "::error::Found ${CRITICAL} critical and ${HIGH} high vulnerabilities"
            exit 1
          fi

      - name: Upload audit report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: npm-audit-report
          path: audit-report.json

      - name: Comment on PR
        if: github.event_name == 'pull_request' && failure()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('audit-report.json'));

            const vulns = report.vulnerabilities;
            let comment = '## Security Audit Failed\n\n';
            comment += `| Severity | Count |\n|----------|-------|\n`;
            comment += `| Critical | ${report.metadata.vulnerabilities.critical} |\n`;
            comment += `| High | ${report.metadata.vulnerabilities.high} |\n`;
            comment += `| Medium | ${report.metadata.vulnerabilities.medium} |\n`;
            comment += `| Low | ${report.metadata.vulnerabilities.low} |\n\n`;

            comment += 'Run `npm audit fix` to address fixable vulnerabilities.';

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

**Auto-fix script**:
```bash
#!/bin/bash
# scripts/fix-vulnerabilities.sh

# Run audit fix
npm audit fix

# Check if any vulnerabilities remain
REMAINING=$(npm audit --json | jq '.metadata.vulnerabilities.total')

if [ "$REMAINING" -gt 0 ]; then
    echo "Some vulnerabilities require manual attention:"
    npm audit

    # Try force fix for semver-major updates (use with caution)
    read -p "Attempt force fix (may break compatibility)? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        npm audit fix --force
        echo "Run tests to verify compatibility"
    fi
fi
```

### Pattern 2: Snyk Integration

**When to Use**: Enterprise-grade vulnerability management

**Implementation**:
```yaml
# GitHub Actions with Snyk
name: Snyk Security

on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 0 * * *'

jobs:
  snyk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master
        continue-on-error: true
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high --json-file-output=snyk-report.json

      - name: Upload Snyk report
        uses: actions/upload-artifact@v4
        with:
          name: snyk-report
          path: snyk-report.json

      - name: Upload to Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          command: monitor

  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t myapp:test .

      - name: Scan container
        uses: snyk/actions/docker@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          image: myapp:test
          args: --severity-threshold=high

  iac-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Scan IaC files
        uses: snyk/actions/iac@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high
```

**Snyk CLI usage**:
```bash
# Test for vulnerabilities
snyk test

# Test with severity threshold
snyk test --severity-threshold=high

# Monitor project (continuous monitoring)
snyk monitor

# Generate report
snyk test --json > snyk-report.json

# Fix vulnerabilities
snyk wizard  # Interactive

# Test container
snyk container test myimage:tag

# Test IaC
snyk iac test ./terraform/
```

### Pattern 3: Dependabot Configuration

**When to Use**: Automated dependency updates on GitHub

**Implementation**:
```yaml
# .github/dependabot.yml
version: 2
updates:
  # npm dependencies
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
    open-pull-requests-limit: 10
    labels:
      - "dependencies"
      - "security"
    commit-message:
      prefix: "chore(deps)"
    groups:
      # Group minor/patch updates
      minor-and-patch:
        patterns:
          - "*"
        update-types:
          - "minor"
          - "patch"
      # Separate group for major updates
      major:
        patterns:
          - "*"
        update-types:
          - "major"
    ignore:
      # Ignore specific packages
      - dependency-name: "aws-sdk"
        versions: ["3.x"]
    # Reviewers for security updates
    reviewers:
      - "security-team"

  # Docker dependencies
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "docker"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "ci"

  # Terraform modules
  - package-ecosystem: "terraform"
    directory: "/infrastructure"
    schedule:
      interval: "weekly"
```

**Dependabot alerts automation**:
```yaml
# .github/workflows/dependabot-auto-merge.yml
name: Dependabot Auto-merge

on:
  pull_request:

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - name: Dependabot metadata
        id: metadata
        uses: dependabot/fetch-metadata@v1
        with:
          github-token: "${{ secrets.GITHUB_TOKEN }}"

      - name: Auto-merge patch updates
        if: steps.metadata.outputs.update-type == 'version-update:semver-patch'
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Auto-merge minor updates for dev deps
        if: |
          steps.metadata.outputs.update-type == 'version-update:semver-minor' &&
          steps.metadata.outputs.dependency-type == 'direct:development'
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Pattern 4: Multi-Language Scanning with Trivy

**When to Use**: Polyglot projects, container scanning

**Implementation**:
```yaml
# Comprehensive Trivy scanning
name: Security Scan

on:
  push:
  pull_request:
  schedule:
    - cron: '0 0 * * *'

jobs:
  trivy-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Scan filesystem
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-fs-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload FS results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-fs-results.sarif'
          category: 'trivy-filesystem'

      - name: Scan for secrets
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          scanners: 'secret'
          format: 'table'

      - name: Scan IaC
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: './infrastructure'
          format: 'sarif'
          output: 'trivy-iac-results.sarif'

      - name: Build container
        run: docker build -t app:test .

      - name: Scan container
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'app:test'
          format: 'sarif'
          output: 'trivy-image-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload container results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-image-results.sarif'
          category: 'trivy-container'
```

### Pattern 5: Vulnerability Prioritization

**When to Use**: Managing large numbers of findings

**Implementation**:
```typescript
interface Vulnerability {
  id: string;
  package: string;
  severity: 'critical' | 'high' | 'medium' | 'low';
  cvss: number;
  exploitAvailable: boolean;
  fixAvailable: boolean;
  inProductionPath: boolean;
  lastModified: Date;
}

class VulnerabilityPrioritizer {
  calculatePriority(vuln: Vulnerability): number {
    let score = vuln.cvss * 10;  // Base score 0-100

    // Boost for exploit availability
    if (vuln.exploitAvailable) {
      score += 30;
    }

    // Boost for production exposure
    if (vuln.inProductionPath) {
      score += 25;
    }

    // Reduction if fix available (easier to remediate)
    if (vuln.fixAvailable) {
      score -= 10;
    }

    // Recent vulnerabilities get priority
    const daysSinceModified = this.daysSince(vuln.lastModified);
    if (daysSinceModified < 7) {
      score += 15;  // Very recent
    } else if (daysSinceModified < 30) {
      score += 5;   // Recent
    }

    return Math.min(100, Math.max(0, score));
  }

  prioritize(vulnerabilities: Vulnerability[]): Vulnerability[] {
    return vulnerabilities
      .map(v => ({
        ...v,
        priorityScore: this.calculatePriority(v)
      }))
      .sort((a, b) => b.priorityScore - a.priorityScore);
  }

  generateRemediationPlan(
    vulnerabilities: Vulnerability[]
  ): RemediationPlan {
    const prioritized = this.prioritize(vulnerabilities);

    return {
      immediate: prioritized.filter(v =>
        v.priorityScore >= 80 || v.severity === 'critical'
      ),
      shortTerm: prioritized.filter(v =>
        v.priorityScore >= 50 && v.priorityScore < 80
      ),
      longTerm: prioritized.filter(v =>
        v.priorityScore < 50
      ),
      wontFix: vulnerabilities.filter(v =>
        !v.inProductionPath && !v.fixAvailable
      )
    };
  }
}
```

### Pattern 6: Vulnerability Exceptions

**When to Use**: Managing accepted risks

**Implementation**:
```yaml
# .snyk policy file
version: v1.25.0
ignore:
  SNYK-JS-LODASH-567746:
    - '*':
        reason: 'Not exploitable in our usage - we do not use affected function'
        expires: 2024-12-31T00:00:00.000Z
        created: 2024-01-15T00:00:00.000Z
        approvedBy: 'security-team'

  'npm:minimist:20200305':
    - 'package.json > test-lib':
        reason: 'Development dependency only, not in production build'
        expires: 2024-06-30T00:00:00.000Z
```

```typescript
// Vulnerability exception management
interface VulnerabilityException {
  vulnerabilityId: string;
  package: string;
  reason: string;
  type: 'not_exploitable' | 'dev_only' | 'accepted_risk' | 'false_positive';
  approvedBy: string;
  approvedAt: Date;
  expiresAt: Date;
  evidence?: string;
}

class ExceptionManager {
  async requestException(
    vuln: Vulnerability,
    request: ExceptionRequest
  ): Promise<ExceptionTicket> {
    // Create approval workflow
    const ticket = await this.ticketService.create({
      type: 'security-exception',
      vulnerability: vuln,
      requestedBy: request.requestedBy,
      reason: request.reason,
      evidenceLinks: request.evidenceLinks,
      proposedExpiry: request.proposedExpiry,
      status: 'pending_review'
    });

    // Notify security team
    await this.notifySecurityTeam(ticket);

    return ticket;
  }

  async approveException(
    ticketId: string,
    approver: string,
    conditions?: string
  ): Promise<VulnerabilityException> {
    const ticket = await this.ticketService.get(ticketId);

    // Validate approver has authority
    if (!await this.canApprove(approver, ticket.vulnerability.severity)) {
      throw new Error('Insufficient approval authority');
    }

    const exception: VulnerabilityException = {
      vulnerabilityId: ticket.vulnerability.id,
      package: ticket.vulnerability.package,
      reason: ticket.reason,
      type: ticket.exceptionType,
      approvedBy: approver,
      approvedAt: new Date(),
      expiresAt: ticket.proposedExpiry,
      evidence: conditions
    };

    // Store exception
    await this.exceptionRepository.save(exception);

    // Update policy files
    await this.updatePolicyFiles(exception);

    // Close ticket
    await this.ticketService.close(ticketId, 'approved');

    return exception;
  }
}
```

## Checklist

- [ ] Dependency scanning in CI/CD pipeline
- [ ] Blocking policy for critical/high vulnerabilities
- [ ] Automated dependency updates configured
- [ ] Exception process documented
- [ ] Development vs production dependency distinction
- [ ] Container image scanning enabled
- [ ] Regular scan schedule (daily/weekly)
- [ ] Vulnerability tracking dashboard
- [ ] SLA defined for each severity level
- [ ] License compliance scanning included

## References

- [npm audit Documentation](https://docs.npmjs.com/cli/v8/commands/npm-audit)
- [Snyk Documentation](https://docs.snyk.io/)
- [Dependabot Configuration](https://docs.github.com/en/code-security/dependabot)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
