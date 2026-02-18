# Compliance Frameworks

Detailed compliance framework requirements and implementation guidance.

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

## GDPR Data Subject Rights

| Right | Implementation |
|-------|----------------|
| Access | Export user data endpoint |
| Rectification | Edit profile endpoint |
| Erasure | Delete account with cascade |
| Portability | JSON/CSV export |
| Restriction | Disable processing flag |
| Object | Opt-out preferences |

## Common Controls Across Frameworks

| Control | SOC 2 | GDPR | HIPAA |
|---------|-------|------|-------|
| Encryption at rest | Yes | Yes | Yes |
| Encryption in transit | Yes | Yes | Yes |
| Access logging | Yes | Yes | Yes |
| MFA | Yes | - | Yes |
| Data classification | Yes | Yes | Yes |
| Incident response | Yes | Yes | Yes |
