---
title: SOC 2 Controls Reference
category: security
type: reference
version: "1.0.0"
---

# SOC 2 Type II Control Mapping

> Part of the security/compliance knowledge skill

## Overview

SOC 2 (Service Organization Control 2) is an auditing standard for service organizations that store customer data. This reference maps SOC 2 Trust Services Criteria to technical controls with implementation guidance.

## 80/20 Quick Reference

**Trust Services Categories (highest impact first):**

| Category | Focus | Key Controls |
|----------|-------|--------------|
| Security (CC) | Protection from unauthorized access | Access control, encryption, monitoring |
| Availability (A) | System uptime and recovery | Redundancy, backups, incident response |
| Confidentiality (C) | Data protection | Classification, encryption, DLP |
| Processing Integrity (PI) | Accurate processing | Validation, reconciliation |
| Privacy (P) | Personal data handling | Consent, retention, rights |

**Common Criteria (CC) - Required for all SOC 2 reports**

## Patterns

### Pattern 1: CC6 - Logical and Physical Access Controls

**SOC 2 Requirement**: Implement controls to restrict access to authorized users

**Implementation**:
```typescript
// CC6.1 - Logical access security software
class AccessControlImplementation {
  // Role-based access control
  async assignRole(userId: string, role: string, assignedBy: string): Promise<void> {
    // Validate assigner has permission
    const canAssign = await this.checkPermission(assignedBy, 'user:role:assign');
    if (!canAssign) {
      throw new UnauthorizedError('Cannot assign roles');
    }

    // Log assignment for audit
    await this.auditLog.log({
      action: 'ROLE_ASSIGNED',
      userId,
      role,
      assignedBy,
      timestamp: new Date()
    });

    await this.userService.assignRole(userId, role);
  }

  // CC6.2 - Authentication mechanisms
  async authenticate(credentials: Credentials): Promise<AuthResult> {
    const user = await this.userService.findByEmail(credentials.email);

    // Check account status
    if (user.status !== 'active') {
      await this.auditLog.log({
        action: 'AUTH_BLOCKED',
        reason: 'inactive_account',
        userId: user.id
      });
      throw new AuthenticationError('Account not active');
    }

    // Verify password
    if (!await this.verifyPassword(credentials.password, user.passwordHash)) {
      await this.recordFailedAttempt(user.id);
      throw new AuthenticationError('Invalid credentials');
    }

    // Check MFA if enabled
    if (user.mfaEnabled) {
      if (!credentials.mfaToken) {
        return { requiresMfa: true, userId: user.id };
      }
      if (!await this.verifyMfa(user.id, credentials.mfaToken)) {
        throw new AuthenticationError('Invalid MFA token');
      }
    }

    // Audit successful login
    await this.auditLog.log({
      action: 'AUTH_SUCCESS',
      userId: user.id,
      method: user.mfaEnabled ? 'password+mfa' : 'password'
    });

    return { token: this.generateToken(user), user };
  }

  // CC6.3 - Access removal on termination
  async terminateAccess(userId: string, terminatedBy: string, reason: string): Promise<void> {
    // Revoke all sessions
    await this.sessionService.revokeAllSessions(userId);

    // Disable account
    await this.userService.disable(userId);

    // Revoke API keys
    await this.apiKeyService.revokeAll(userId);

    // Remove from groups
    await this.groupService.removeFromAll(userId);

    // Audit
    await this.auditLog.log({
      action: 'ACCESS_TERMINATED',
      userId,
      terminatedBy,
      reason,
      timestamp: new Date()
    });
  }
}
```

**Evidence collection**:
```typescript
// Generate access review report
async function generateAccessReviewReport(): Promise<AccessReviewReport> {
  const users = await userService.getAllActive();
  const report: AccessReviewReport = {
    generatedAt: new Date(),
    period: { start: startOfQuarter(), end: endOfQuarter() },
    users: []
  };

  for (const user of users) {
    report.users.push({
      userId: user.id,
      email: user.email,
      roles: await roleService.getRoles(user.id),
      lastLogin: user.lastLoginAt,
      mfaEnabled: user.mfaEnabled,
      accessReviewed: await accessReviewService.wasReviewed(user.id),
      reviewedBy: await accessReviewService.getReviewer(user.id)
    });
  }

  return report;
}
```

### Pattern 2: CC7 - System Operations

**SOC 2 Requirement**: Monitor system operations for anomalies

**Implementation**:
```yaml
# CC7.1 - Detection and monitoring procedures
# Datadog monitoring configuration
---
apiVersion: monitoring.datadoghq.com/v1alpha1
kind: DatadogMonitor
metadata:
  name: authentication-anomaly
spec:
  name: "Authentication Anomaly Detection"
  type: anomaly
  query: |
    avg(last_1h):anomalies(
      sum:auth.login.failed{*}.as_count(),
      'agile', 2, direction='above'
    ) >= 1
  message: |
    ## Authentication Anomaly Detected

    Unusual number of failed authentication attempts.

    **Investigation Steps:**
    1. Check source IPs in auth logs
    2. Review affected user accounts
    3. Check for credential stuffing patterns

    @slack-security-alerts
  tags:
    - "soc2:cc7.1"
    - "service:authentication"
  options:
    thresholds:
      critical: 1
    notifyNoData: false
---
# CC7.2 - Incident management
apiVersion: monitoring.datadoghq.com/v1alpha1
kind: DatadogMonitor
metadata:
  name: security-incident-sla
spec:
  name: "Security Incident Response SLA"
  type: metric alert
  query: |
    sum(last_5m):count:security.incident{status:open,severity:critical} > 0
  message: |
    ## Critical Security Incident Open

    A critical security incident requires immediate response.

    **SLA Requirements:**
    - Acknowledge within 15 minutes
    - Containment within 1 hour
    - Resolution within 24 hours

    **Runbook:** https://runbooks.company.com/security-incident

    @pagerduty-security-oncall
```

**Incident tracking**:
```typescript
// CC7.3 - Incident evaluation and response
interface SecurityIncident {
  id: string;
  severity: 'critical' | 'high' | 'medium' | 'low';
  status: 'open' | 'acknowledged' | 'contained' | 'resolved';
  title: string;
  description: string;
  detectedAt: Date;
  acknowledgedAt?: Date;
  containedAt?: Date;
  resolvedAt?: Date;
  timeline: IncidentEvent[];
  affectedSystems: string[];
  rootCause?: string;
  remediation?: string;
}

class IncidentManager {
  async createIncident(data: CreateIncidentInput): Promise<SecurityIncident> {
    const incident = await this.repository.create({
      ...data,
      status: 'open',
      detectedAt: new Date(),
      timeline: [{
        timestamp: new Date(),
        event: 'Incident created',
        actor: 'system'
      }]
    });

    // Notify based on severity
    if (data.severity === 'critical') {
      await this.notifySecurityTeam(incident);
      await this.escalateToPagerDuty(incident);
    }

    return incident;
  }

  async addTimelineEvent(
    incidentId: string,
    event: string,
    actor: string
  ): Promise<void> {
    await this.repository.addTimelineEvent(incidentId, {
      timestamp: new Date(),
      event,
      actor
    });
  }

  async generatePostMortem(incidentId: string): Promise<PostMortem> {
    const incident = await this.repository.findById(incidentId);

    return {
      incident,
      timeline: incident.timeline,
      rootCause: incident.rootCause,
      impact: await this.calculateImpact(incident),
      lessonsLearned: [],
      actionItems: [],
      preventionMeasures: []
    };
  }
}
```

### Pattern 3: CC8 - Change Management

**SOC 2 Requirement**: Manage changes to prevent unauthorized modifications

**Implementation**:
```yaml
# CC8.1 - Change authorization and approval
# GitHub branch protection
name: Main Branch Protection

on:
  pull_request:
    branches: [main]

jobs:
  approval-check:
    runs-on: ubuntu-latest
    steps:
      - name: Check approvals
        uses: actions/github-script@v6
        with:
          script: |
            const { data: reviews } = await github.rest.pulls.listReviews({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.payload.pull_request.number
            });

            const approvals = reviews.filter(r => r.state === 'APPROVED');
            const codeOwnerApproval = approvals.some(
              r => ['security-team', 'senior-engineers'].includes(r.user.login)
            );

            if (approvals.length < 2 || !codeOwnerApproval) {
              core.setFailed('Requires 2 approvals including code owner');
            }

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Security scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'

      - name: Secret scan
        uses: trufflesecurity/trufflehog@main
        with:
          path: ./
          extra_args: --only-verified

  tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test

      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

**Change log automation**:
```typescript
// CC8.2 - Documentation of system changes
interface ChangeRecord {
  id: string;
  type: 'feature' | 'bugfix' | 'security' | 'infrastructure';
  title: string;
  description: string;
  prNumber: string;
  author: string;
  reviewers: string[];
  approvedAt: Date;
  deployedAt: Date;
  rollbackPlan: string;
  testEvidence: string;
}

class ChangeManagementService {
  async recordChange(pr: PullRequest, deployment: Deployment): Promise<ChangeRecord> {
    const change: ChangeRecord = {
      id: generateId(),
      type: this.classifyChange(pr),
      title: pr.title,
      description: pr.body,
      prNumber: pr.number.toString(),
      author: pr.user.login,
      reviewers: pr.requested_reviewers.map(r => r.login),
      approvedAt: new Date(pr.merged_at),
      deployedAt: deployment.completedAt,
      rollbackPlan: this.extractRollbackPlan(pr),
      testEvidence: await this.gatherTestEvidence(pr)
    };

    await this.repository.save(change);
    return change;
  }

  async generateChangeReport(period: DateRange): Promise<ChangeReport> {
    const changes = await this.repository.findByPeriod(period);

    return {
      period,
      totalChanges: changes.length,
      byType: this.groupByType(changes),
      averageReviewTime: this.calculateAverageReviewTime(changes),
      rollbacks: changes.filter(c => c.rolledBack),
      securityChanges: changes.filter(c => c.type === 'security')
    };
  }
}
```

### Pattern 4: CC9 - Risk Management

**SOC 2 Requirement**: Identify and manage risks

**Implementation**:
```typescript
// CC9.1 - Risk identification and assessment
interface RiskAssessment {
  id: string;
  name: string;
  category: 'technical' | 'operational' | 'compliance' | 'strategic';
  description: string;
  likelihood: 1 | 2 | 3 | 4 | 5;
  impact: 1 | 2 | 3 | 4 | 5;
  inherentRisk: number;
  controls: Control[];
  residualRisk: number;
  owner: string;
  reviewDate: Date;
  status: 'open' | 'mitigated' | 'accepted' | 'transferred';
}

class RiskManagementService {
  async assessRisk(risk: RiskInput): Promise<RiskAssessment> {
    const inherentRisk = risk.likelihood * risk.impact;
    const controls = await this.findApplicableControls(risk);
    const controlEffectiveness = this.calculateControlEffectiveness(controls);
    const residualRisk = inherentRisk * (1 - controlEffectiveness);

    return {
      ...risk,
      inherentRisk,
      controls,
      residualRisk,
      status: this.determineStatus(residualRisk)
    };
  }

  async generateRiskRegister(): Promise<RiskRegister> {
    const risks = await this.repository.findAll();

    return {
      generatedAt: new Date(),
      risks: risks.map(r => ({
        ...r,
        riskScore: r.residualRisk,
        trend: this.calculateTrend(r)
      })),
      summary: {
        totalRisks: risks.length,
        criticalRisks: risks.filter(r => r.residualRisk > 15).length,
        averageRiskScore: this.calculateAverage(risks.map(r => r.residualRisk))
      }
    };
  }
}
```

### Pattern 5: Evidence Collection Dashboard

**When to Use**: Preparing for SOC 2 audit

**Implementation**:
```typescript
// Automated evidence collection
class SOC2EvidenceCollector {
  async collectEvidence(period: DateRange): Promise<SOC2EvidencePackage> {
    return {
      period,
      generatedAt: new Date(),

      // CC6 - Access Controls
      cc6: {
        accessReviews: await this.getAccessReviews(period),
        roleAssignments: await this.getRoleAssignmentLogs(period),
        terminatedUsers: await this.getTerminatedUserLogs(period),
        mfaEnrollment: await this.getMfaEnrollmentReport(),
        privilegedAccessLogs: await this.getPrivilegedAccessLogs(period)
      },

      // CC7 - System Operations
      cc7: {
        securityIncidents: await this.getSecurityIncidents(period),
        monitoringAlerts: await this.getMonitoringAlerts(period),
        vulnerabilityScans: await this.getVulnerabilityScans(period),
        penetrationTests: await this.getPenetrationTestReports(period)
      },

      // CC8 - Change Management
      cc8: {
        changes: await this.getChangeRecords(period),
        approvals: await this.getChangeApprovals(period),
        deployments: await this.getDeploymentLogs(period),
        rollbacks: await this.getRollbackEvents(period)
      },

      // CC9 - Risk Management
      cc9: {
        riskRegister: await this.getRiskRegister(),
        riskAssessments: await this.getRiskAssessments(period),
        controlTests: await this.getControlTestResults(period)
      }
    };
  }

  async generateAuditReport(evidence: SOC2EvidencePackage): Promise<string> {
    // Generate formatted report for auditors
    const template = await this.loadTemplate('soc2-audit-report');
    return this.renderTemplate(template, evidence);
  }
}
```

## Checklist

**CC6 - Access Controls**
- [ ] Role-based access control implemented
- [ ] MFA enforced for privileged users
- [ ] Quarterly access reviews conducted
- [ ] Termination process includes access revocation
- [ ] Service accounts have minimal permissions

**CC7 - System Operations**
- [ ] Security monitoring active 24/7
- [ ] Incident response procedures documented
- [ ] Vulnerability scanning automated
- [ ] Annual penetration testing conducted

**CC8 - Change Management**
- [ ] All changes require approval
- [ ] Testing required before deployment
- [ ] Rollback procedures documented
- [ ] Change logs maintained

**CC9 - Risk Management**
- [ ] Risk register maintained
- [ ] Annual risk assessments conducted
- [ ] Control testing performed
- [ ] Vendor risk assessments completed

## References

- [AICPA SOC 2 Criteria](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/sorhome)
- [SOC 2 Trust Services Criteria](https://www.aicpa.org/content/dam/aicpa/interestareas/frc/assuranceadvisoryservices/downloadabledocuments/trust-services-criteria.pdf)
- [SOC 2 Compliance Guide](https://www.vanta.com/resources/soc-2-compliance-guide)
