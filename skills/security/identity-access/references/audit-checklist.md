---
title: Compliance Audit Checklist Reference
category: security
type: reference
version: "1.0.0"
---

# Compliance Audit Preparation Checklist

> Part of the security/compliance knowledge skill

## Overview

This reference provides comprehensive checklists for preparing for security and compliance audits including SOC 2, ISO 27001, PCI DSS, and HIPAA. Use these checklists to assess readiness and gather required evidence.

## 80/20 Quick Reference

**Universal audit preparation priorities:**

| Priority | Area | Impact |
|----------|------|--------|
| 1 | Policy documentation | Foundation for all controls |
| 2 | Access control evidence | Most commonly tested |
| 3 | Change management logs | Demonstrates control |
| 4 | Incident records | Shows response capability |
| 5 | Vendor assessments | Third-party risk |

**Evidence collection timeline:**
- 90 days before: Start evidence collection
- 60 days before: Gap assessment
- 30 days before: Remediation complete
- 14 days before: Evidence package ready
- 7 days before: Walkthrough rehearsal

## Patterns

### Pattern 1: SOC 2 Type II Audit Checklist

**When to Use**: Annual SOC 2 audit preparation

**Pre-Audit Assessment**:
```markdown
## CC1: Control Environment

### Policies and Procedures
- [ ] Information security policy documented and approved
- [ ] Acceptable use policy distributed to employees
- [ ] Code of conduct signed by all employees
- [ ] Security awareness training completed (evidence: completion records)
- [ ] Policy review dates current (annual review documented)

### Organization Structure
- [ ] Organizational chart with security roles
- [ ] Security team responsibilities documented
- [ ] Background check policy and evidence
- [ ] Job descriptions include security responsibilities

## CC2: Communication and Information

### Internal Communication
- [ ] Security policies accessible to all employees
- [ ] Security incident reporting procedure documented
- [ ] Regular security communications (newsletters, alerts)
- [ ] Security metrics dashboard available

### External Communication
- [ ] Customer security documentation
- [ ] Breach notification procedures
- [ ] Third-party security requirements documented

## CC3: Risk Assessment

### Risk Management Process
- [ ] Risk register maintained and current
- [ ] Annual risk assessment completed
- [ ] Risk treatment plans documented
- [ ] Risk acceptance documented by management
- [ ] Vendor risk assessments completed

## CC4: Monitoring Activities

### Control Monitoring
- [ ] Control testing schedule documented
- [ ] Control exceptions tracked and remediated
- [ ] Management review of security metrics
- [ ] Internal audit reports

## CC5: Control Activities

### Policy Implementation
- [ ] Controls mapped to policies
- [ ] Control ownership assigned
- [ ] Control effectiveness testing results

## CC6: Logical and Physical Access

### User Access
- [ ] User provisioning procedure with approvals
- [ ] Access reviews completed quarterly
- [ ] Terminated user access removal (within 24 hours)
- [ ] Privileged access inventory and justification
- [ ] MFA enforcement evidence

### Authentication
- [ ] Password policy enforcement logs
- [ ] MFA enrollment statistics
- [ ] Failed login monitoring alerts
- [ ] Session timeout configuration

### Physical Access
- [ ] Data center access logs
- [ ] Visitor management records
- [ ] Badge access audit trails

## CC7: System Operations

### Vulnerability Management
- [ ] Vulnerability scan reports (monthly)
- [ ] Penetration test report (annual)
- [ ] Remediation tracking and SLAs
- [ ] Patch management records

### Incident Management
- [ ] Incident response plan tested
- [ ] Security incident log
- [ ] Post-incident reviews
- [ ] Lessons learned documentation

### Monitoring
- [ ] Security monitoring coverage
- [ ] Alert response procedures
- [ ] On-call schedules and escalation

## CC8: Change Management

### Change Process
- [ ] Change management policy
- [ ] Change approval records
- [ ] Emergency change procedures
- [ ] Rollback documentation
- [ ] Testing evidence before deployment

### Configuration Management
- [ ] Baseline configurations documented
- [ ] Configuration change logs
- [ ] Unauthorized change detection

## CC9: Risk Mitigation

### Business Continuity
- [ ] Business continuity plan tested
- [ ] Disaster recovery test results
- [ ] Backup verification logs
- [ ] RTO/RPO compliance evidence
```

### Pattern 2: Evidence Collection Automation

**When to Use**: Continuous compliance monitoring

**Implementation**:
```typescript
interface AuditEvidence {
  controlId: string;
  description: string;
  evidenceType: 'policy' | 'log' | 'screenshot' | 'report' | 'configuration';
  collectedAt: Date;
  validUntil: Date;
  artifacts: Artifact[];
}

class ComplianceEvidenceCollector {
  async collectAllEvidence(auditPeriod: DateRange): Promise<EvidencePackage> {
    const evidence: EvidencePackage = {
      auditPeriod,
      collectedAt: new Date(),
      controls: {}
    };

    // CC6 - Access Controls
    evidence.controls['CC6.1'] = await this.collectAccessControlEvidence(auditPeriod);
    evidence.controls['CC6.2'] = await this.collectAuthenticationEvidence(auditPeriod);
    evidence.controls['CC6.3'] = await this.collectTerminationEvidence(auditPeriod);

    // CC7 - System Operations
    evidence.controls['CC7.1'] = await this.collectVulnerabilityEvidence(auditPeriod);
    evidence.controls['CC7.2'] = await this.collectIncidentEvidence(auditPeriod);

    // CC8 - Change Management
    evidence.controls['CC8.1'] = await this.collectChangeEvidence(auditPeriod);

    return evidence;
  }

  private async collectAccessControlEvidence(period: DateRange): Promise<AuditEvidence[]> {
    return [
      {
        controlId: 'CC6.1.1',
        description: 'User provisioning approvals',
        evidenceType: 'log',
        collectedAt: new Date(),
        validUntil: addDays(new Date(), 90),
        artifacts: await this.getProvisioningApprovals(period)
      },
      {
        controlId: 'CC6.1.2',
        description: 'Quarterly access reviews',
        evidenceType: 'report',
        collectedAt: new Date(),
        validUntil: addDays(new Date(), 90),
        artifacts: await this.getAccessReviews(period)
      },
      {
        controlId: 'CC6.1.3',
        description: 'Privileged access inventory',
        evidenceType: 'report',
        collectedAt: new Date(),
        validUntil: addDays(new Date(), 30),
        artifacts: [await this.generatePrivilegedAccessReport()]
      }
    ];
  }

  private async collectVulnerabilityEvidence(period: DateRange): Promise<AuditEvidence[]> {
    return [
      {
        controlId: 'CC7.1.1',
        description: 'Monthly vulnerability scans',
        evidenceType: 'report',
        collectedAt: new Date(),
        validUntil: addDays(new Date(), 30),
        artifacts: await this.getVulnerabilityScans(period)
      },
      {
        controlId: 'CC7.1.2',
        description: 'Annual penetration test',
        evidenceType: 'report',
        collectedAt: new Date(),
        validUntil: addDays(new Date(), 365),
        artifacts: await this.getPenetrationTestReports(period)
      },
      {
        controlId: 'CC7.1.3',
        description: 'Vulnerability remediation tracking',
        evidenceType: 'log',
        collectedAt: new Date(),
        validUntil: addDays(new Date(), 30),
        artifacts: await this.getRemediationLogs(period)
      }
    ];
  }

  async generateAuditPackage(evidence: EvidencePackage): Promise<AuditPackage> {
    const package: AuditPackage = {
      metadata: {
        generatedAt: new Date(),
        auditPeriod: evidence.auditPeriod,
        preparedBy: 'Compliance Team'
      },
      tableOfContents: this.generateTOC(evidence),
      executiveSummary: this.generateSummary(evidence),
      controlMatrix: this.generateControlMatrix(evidence),
      evidence: evidence.controls,
      gaps: await this.identifyGaps(evidence),
      remediationPlan: await this.getRemediationPlan()
    };

    return package;
  }
}
```

### Pattern 3: ISO 27001 Audit Checklist

**When to Use**: ISO 27001 certification or surveillance audit

```markdown
## A.5: Information Security Policies

- [ ] A.5.1.1: Information security policy document approved by management
- [ ] A.5.1.2: Policy review records (annual minimum)

## A.6: Organization of Information Security

- [ ] A.6.1.1: Security roles and responsibilities defined
- [ ] A.6.1.2: Segregation of duties implemented
- [ ] A.6.2.1: Mobile device policy
- [ ] A.6.2.2: Teleworking policy

## A.7: Human Resource Security

- [ ] A.7.1.1: Background verification records
- [ ] A.7.2.1: Management responsibilities communicated
- [ ] A.7.2.2: Security awareness training records
- [ ] A.7.3.1: Termination responsibilities documented

## A.8: Asset Management

- [ ] A.8.1.1: Asset inventory complete and accurate
- [ ] A.8.1.2: Asset ownership assigned
- [ ] A.8.2.1: Information classification scheme
- [ ] A.8.2.3: Asset handling procedures

## A.9: Access Control

- [ ] A.9.1.1: Access control policy
- [ ] A.9.2.1: User registration and de-registration process
- [ ] A.9.2.2: User access provisioning
- [ ] A.9.2.3: Privileged access management
- [ ] A.9.2.4: User access review records
- [ ] A.9.2.5: Access rights removal on termination
- [ ] A.9.4.1: Information access restriction
- [ ] A.9.4.2: Secure log-on procedures
- [ ] A.9.4.3: Password management system

## A.10: Cryptography

- [ ] A.10.1.1: Cryptographic controls policy
- [ ] A.10.1.2: Key management procedures

## A.12: Operations Security

- [ ] A.12.1.1: Operating procedures documented
- [ ] A.12.1.2: Change management records
- [ ] A.12.2.1: Anti-malware controls
- [ ] A.12.3.1: Backup policy and testing records
- [ ] A.12.4.1: Event logging configuration
- [ ] A.12.4.3: System administrator logs protected
- [ ] A.12.5.1: Software installation controls
- [ ] A.12.6.1: Vulnerability management
- [ ] A.12.6.2: Software installation restrictions

## A.13: Communications Security

- [ ] A.13.1.1: Network controls
- [ ] A.13.1.2: Network services security
- [ ] A.13.2.1: Information transfer policies

## A.16: Information Security Incident Management

- [ ] A.16.1.1: Incident management procedures
- [ ] A.16.1.2: Security event reporting
- [ ] A.16.1.4: Incident assessment and decision
- [ ] A.16.1.5: Incident response records
- [ ] A.16.1.6: Learning from incidents

## A.17: Business Continuity

- [ ] A.17.1.1: Business continuity planning
- [ ] A.17.1.2: BCM implementation
- [ ] A.17.1.3: BCM review and testing

## A.18: Compliance

- [ ] A.18.1.1: Applicable legal requirements identified
- [ ] A.18.1.3: Records protection
- [ ] A.18.2.1: Independent security review
- [ ] A.18.2.2: Compliance with security policies
- [ ] A.18.2.3: Technical compliance review
```

### Pattern 4: PCI DSS Audit Checklist

**When to Use**: PCI DSS compliance assessment

```markdown
## Requirement 1: Install and maintain a firewall

- [ ] 1.1: Firewall and router configuration standards
- [ ] 1.2: Build firewall configuration restricting connections
- [ ] 1.3: Prohibit direct public access to CDE

## Requirement 2: Do not use vendor-supplied defaults

- [ ] 2.1: Change vendor defaults before installing on network
- [ ] 2.2: Configuration standards for all system components
- [ ] 2.3: Encrypt all non-console administrative access

## Requirement 3: Protect stored cardholder data

- [ ] 3.1: Data retention and disposal policies
- [ ] 3.2: Do not store sensitive authentication data post-authorization
- [ ] 3.4: Render PAN unreadable (encryption, hashing, truncation)
- [ ] 3.5: Key management procedures documented

## Requirement 4: Encrypt transmission

- [ ] 4.1: Strong cryptography for transmission over open networks
- [ ] 4.2: Never send unprotected PANs by end-user messaging

## Requirement 5: Protect against malware

- [ ] 5.1: Deploy anti-malware software
- [ ] 5.2: Keep anti-malware current and running
- [ ] 5.3: Anti-malware logging and monitoring

## Requirement 6: Develop secure systems

- [ ] 6.1: Establish process for identifying vulnerabilities
- [ ] 6.2: Install security patches within required timeframe
- [ ] 6.3: Develop software securely
- [ ] 6.4: Change control procedures
- [ ] 6.5: Address common coding vulnerabilities (OWASP Top 10)

## Requirement 7: Restrict access by business need

- [ ] 7.1: Limit access to system components
- [ ] 7.2: Access control system configured

## Requirement 8: Identify and authenticate access

- [ ] 8.1: Define policies for user identification
- [ ] 8.2: Strong authentication methods
- [ ] 8.3: MFA for all remote network access

## Requirement 9: Restrict physical access

- [ ] 9.1: Facility entry controls
- [ ] 9.2: Procedures for distinguishing visitors
- [ ] 9.5: Protect media against unauthorized access

## Requirement 10: Track and monitor access

- [ ] 10.1: Audit trails linking access to individuals
- [ ] 10.2: Implement automated audit trails
- [ ] 10.3: Record audit trail entries
- [ ] 10.5: Secure audit trails
- [ ] 10.6: Review logs daily

## Requirement 11: Test security systems

- [ ] 11.1: Test for wireless access points quarterly
- [ ] 11.2: Internal and external vulnerability scans
- [ ] 11.3: Penetration testing methodology
- [ ] 11.4: Intrusion detection/prevention systems

## Requirement 12: Maintain security policy

- [ ] 12.1: Security policy established and maintained
- [ ] 12.4: Security responsibilities defined
- [ ] 12.6: Security awareness program
- [ ] 12.10: Incident response plan
```

### Pattern 5: Continuous Compliance Dashboard

**When to Use**: Real-time compliance monitoring

**Implementation**:
```typescript
interface ComplianceMetric {
  controlId: string;
  name: string;
  status: 'compliant' | 'non-compliant' | 'partial' | 'not-tested';
  score: number;
  lastTested: Date;
  nextTestDue: Date;
  evidence: EvidenceRef[];
}

class ComplianceDashboard {
  async getComplianceStatus(framework: string): Promise<ComplianceReport> {
    const controls = await this.getControlsForFramework(framework);
    const metrics: ComplianceMetric[] = [];

    for (const control of controls) {
      const status = await this.evaluateControl(control);
      metrics.push(status);
    }

    return {
      framework,
      generatedAt: new Date(),
      overallScore: this.calculateOverallScore(metrics),
      controlStatuses: metrics,
      gaps: metrics.filter(m => m.status === 'non-compliant'),
      upcomingTests: metrics.filter(m => m.nextTestDue < addDays(new Date(), 30)),
      trends: await this.getComplianceTrends(framework)
    };
  }

  async getComplianceTrends(framework: string, months: number = 12): Promise<TrendData[]> {
    const trends: TrendData[] = [];

    for (let i = months; i >= 0; i--) {
      const date = subMonths(new Date(), i);
      const snapshot = await this.getHistoricalSnapshot(framework, date);

      trends.push({
        date,
        overallScore: snapshot.score,
        compliantControls: snapshot.compliant,
        totalControls: snapshot.total
      });
    }

    return trends;
  }

  async generateExecutiveReport(frameworks: string[]): Promise<ExecutiveReport> {
    const frameworkReports = await Promise.all(
      frameworks.map(f => this.getComplianceStatus(f))
    );

    return {
      generatedAt: new Date(),
      summary: {
        averageScore: this.average(frameworkReports.map(r => r.overallScore)),
        totalGaps: frameworkReports.reduce((sum, r) => sum + r.gaps.length, 0),
        criticalGaps: frameworkReports.flatMap(r =>
          r.gaps.filter(g => this.isCritical(g))
        )
      },
      frameworks: frameworkReports,
      recommendations: await this.generateRecommendations(frameworkReports),
      riskAssessment: await this.assessComplianceRisk(frameworkReports)
    };
  }
}
```

## Checklist

**Pre-Audit (90 days)**
- [ ] Identify audit scope and framework
- [ ] Assign audit coordinator
- [ ] Create evidence collection schedule
- [ ] Review previous audit findings
- [ ] Start evidence collection

**Gap Assessment (60 days)**
- [ ] Complete control assessment
- [ ] Document gaps and deficiencies
- [ ] Create remediation plan
- [ ] Prioritize remediation efforts
- [ ] Begin remediation work

**Remediation (30 days)**
- [ ] Complete critical remediations
- [ ] Test remediated controls
- [ ] Document exceptions and compensating controls
- [ ] Update policies as needed
- [ ] Finalize evidence package

**Final Preparation (14 days)**
- [ ] Complete evidence package
- [ ] Review with stakeholders
- [ ] Prepare audit team
- [ ] Schedule interviews
- [ ] Conduct walkthrough rehearsal

**Audit Week**
- [ ] Opening meeting
- [ ] Evidence presentation
- [ ] Control testing support
- [ ] Interview facilitation
- [ ] Daily status meetings
- [ ] Address auditor requests promptly

## References

- [SOC 2 Trust Services Criteria](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/sorhome)
- [ISO 27001:2022 Standard](https://www.iso.org/standard/27001)
- [PCI DSS v4.0](https://www.pcisecuritystandards.org/)
- [HIPAA Security Rule](https://www.hhs.gov/hipaa/for-professionals/security/)
