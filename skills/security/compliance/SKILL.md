---
name: compliance
description: |
  Regulatory compliance frameworks. SOC 2, GDPR, HIPAA requirements and controls.
  Activate when implementing data protection, privacy features, or audit requirements.
  Triggers: compliance, soc2, gdpr, hipaa, pci, audit, privacy, data protection.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Compliance

Regulatory frameworks and implementation requirements.

## Framework Overview

| Framework | Focus | Applies To |
|-----------|-------|------------|
| SOC 2 | Security controls | B2B SaaS |
| GDPR | Privacy (EU) | EU user data |
| HIPAA | Healthcare data | US healthcare |
| PCI DSS | Payment cards | Card processing |
| ISO 27001 | InfoSec management | Enterprise |

## SOC 2 Trust Service Criteria

| Criteria | Key Controls |
|----------|--------------|
| Security | Access control, encryption, firewalls |
| Availability | Uptime monitoring, redundancy, DR |
| Processing Integrity | Data validation, error handling |
| Confidentiality | Encryption, classification, access logs |
| Privacy | Consent, data minimization, retention |

## GDPR Requirements

| Right | Implementation |
|-------|----------------|
| Access | Export user data endpoint |
| Rectification | Edit profile endpoint |
| Erasure | Delete account with cascade |
| Portability | JSON/CSV export |
| Restriction | Disable processing flag |
| Object | Opt-out preferences |

### Data Processing Principles
- Lawful basis (consent, contract, legal obligation)
- Purpose limitation
- Data minimization
- Accuracy
- Storage limitation
- Integrity and confidentiality

## HIPAA Safeguards

| Type | Requirements |
|------|--------------|
| Administrative | Policies, training, risk assessment |
| Physical | Facility access, workstation security |
| Technical | Encryption, audit logs, access control |

## Common Controls

| Control | SOC 2 | GDPR | HIPAA |
|---------|-------|------|-------|
| Encryption at rest | ✓ | ✓ | ✓ |
| Encryption in transit | ✓ | ✓ | ✓ |
| Access logging | ✓ | ✓ | ✓ |
| MFA | ✓ | - | ✓ |
| Data classification | ✓ | ✓ | ✓ |
| Incident response | ✓ | ✓ | ✓ |
| Vendor management | ✓ | ✓ | ✓ |

## Implementation Checklist

- [ ] Data classification scheme
- [ ] Encryption for sensitive data (at rest and in transit)
- [ ] Access control with RBAC
- [ ] Comprehensive audit logging
- [ ] Incident response plan
- [ ] Data retention policies
- [ ] Privacy policy and consent flows
- [ ] Regular security assessments
- [ ] Vendor security reviews

## When to Load References

- **For SOC 2 controls**: See `references/soc2-controls.md`
- **For GDPR implementation**: See `references/gdpr-implementation.md`
- **For audit preparation**: See `references/audit-checklist.md`
