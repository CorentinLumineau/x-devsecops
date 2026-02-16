---
title: GDPR Implementation Reference
category: security
type: reference
version: "1.0.0"
---

# GDPR Implementation Requirements

> Part of the security/compliance knowledge skill

## Overview

The General Data Protection Regulation (GDPR) establishes data protection requirements for organizations handling EU residents' personal data. This reference covers technical implementations for GDPR compliance.

## 80/20 Quick Reference

**Key GDPR principles to implement:**

| Principle | Requirement | Technical Control |
|-----------|-------------|-------------------|
| Lawfulness | Valid legal basis | Consent management |
| Purpose Limitation | Use data only for stated purpose | Access controls |
| Data Minimization | Collect only necessary data | Schema validation |
| Accuracy | Keep data correct | Update mechanisms |
| Storage Limitation | Don't keep longer than needed | Retention policies |
| Integrity/Confidentiality | Protect data | Encryption |
| Accountability | Demonstrate compliance | Audit logging |

**Data Subject Rights to implement:**
- Right of access (DSAR)
- Right to rectification
- Right to erasure (Right to be forgotten)
- Right to data portability
- Right to object

## Patterns

### Pattern 1: Consent Management

**When to Use**: Collecting personal data based on consent

**Implementation**:
```typescript
// Consent data model
interface Consent {
  id: string;
  userId: string;
  purpose: string;
  legalBasis: 'consent' | 'contract' | 'legal_obligation' | 'vital_interest' | 'public_interest' | 'legitimate_interest';
  version: string;
  givenAt: Date;
  withdrawnAt?: Date;
  expiresAt?: Date;
  source: string;
  evidence: ConsentEvidence;
}

interface ConsentEvidence {
  ipAddress: string;
  userAgent: string;
  consentText: string;
  checkboxState: boolean;
  timestamp: Date;
}

class ConsentManager {
  // Record consent with full evidence
  async recordConsent(
    userId: string,
    purpose: string,
    evidence: ConsentEvidence
  ): Promise<Consent> {
    const consent: Consent = {
      id: generateId(),
      userId,
      purpose,
      legalBasis: 'consent',
      version: await this.getCurrentPolicyVersion(),
      givenAt: new Date(),
      source: 'web_form',
      evidence
    };

    // Store consent record
    await this.repository.save(consent);

    // Audit log
    await this.auditLog.log({
      action: 'CONSENT_GIVEN',
      userId,
      purpose,
      consentId: consent.id
    });

    return consent;
  }

  // Withdraw consent
  async withdrawConsent(userId: string, purpose: string): Promise<void> {
    const consent = await this.repository.findActive(userId, purpose);

    if (!consent) {
      throw new NotFoundError('No active consent found');
    }

    consent.withdrawnAt = new Date();
    await this.repository.update(consent);

    // Trigger data processing stop
    await this.dataProcessingService.stopProcessing(userId, purpose);

    // Audit log
    await this.auditLog.log({
      action: 'CONSENT_WITHDRAWN',
      userId,
      purpose,
      consentId: consent.id
    });
  }

  // Check if consent is valid
  async hasValidConsent(userId: string, purpose: string): Promise<boolean> {
    const consent = await this.repository.findActive(userId, purpose);

    if (!consent) return false;
    if (consent.withdrawnAt) return false;
    if (consent.expiresAt && consent.expiresAt < new Date()) return false;

    // Check if policy version is current
    const currentVersion = await this.getCurrentPolicyVersion();
    if (consent.version !== currentVersion) {
      // May need re-consent for material changes
      return this.isVersionCompatible(consent.version, currentVersion);
    }

    return true;
  }
}

// API endpoint
app.post('/api/consent', async (req, res) => {
  const { purpose, agreed } = req.body;

  if (!agreed) {
    return res.status(400).json({ error: 'Consent not provided' });
  }

  const consent = await consentManager.recordConsent(
    req.user.id,
    purpose,
    {
      ipAddress: req.ip,
      userAgent: req.headers['user-agent'],
      consentText: req.body.consentText,
      checkboxState: agreed,
      timestamp: new Date()
    }
  );

  res.json({ consentId: consent.id });
});
```

### Pattern 2: Data Subject Access Request (DSAR)

**When to Use**: Responding to Article 15 access requests

**Implementation**:
```typescript
interface DSARRequest {
  id: string;
  subjectId: string;
  type: 'access' | 'rectification' | 'erasure' | 'portability' | 'objection';
  status: 'received' | 'identity_verified' | 'processing' | 'completed' | 'rejected';
  receivedAt: Date;
  dueDate: Date;  // 30 days from receipt
  completedAt?: Date;
  identityVerification: IdentityVerification;
  response?: DSARResponse;
}

class DSARProcessor {
  async submitRequest(
    request: DSARRequestInput,
    identityProof: IdentityProof
  ): Promise<DSARRequest> {
    const dsar: DSARRequest = {
      id: generateId(),
      subjectId: request.subjectId,
      type: request.type,
      status: 'received',
      receivedAt: new Date(),
      dueDate: addDays(new Date(), 30),
      identityVerification: {
        method: identityProof.method,
        verified: false,
        verifiedAt: null
      }
    };

    await this.repository.save(dsar);

    // Start verification process
    await this.identityService.startVerification(dsar.id, identityProof);

    // Notify DPO
    await this.notifyDPO(dsar);

    return dsar;
  }

  async processAccessRequest(dsarId: string): Promise<DSARResponse> {
    const dsar = await this.repository.findById(dsarId);

    if (!dsar.identityVerification.verified) {
      throw new Error('Identity not verified');
    }

    // Collect all personal data
    const personalData = await this.collectPersonalData(dsar.subjectId);

    // Generate report
    const response: DSARResponse = {
      dsarId,
      generatedAt: new Date(),
      dataCategories: Object.keys(personalData),
      data: personalData,
      processingPurposes: await this.getProcessingPurposes(dsar.subjectId),
      recipients: await this.getDataRecipients(dsar.subjectId),
      retentionPeriods: await this.getRetentionInfo(),
      sourceOfData: await this.getDataSources(dsar.subjectId),
      automatedDecisionMaking: await this.getAutomatedDecisions(dsar.subjectId),
      dataTransfers: await this.getInternationalTransfers(dsar.subjectId)
    };

    // Update DSAR status
    dsar.status = 'completed';
    dsar.completedAt = new Date();
    dsar.response = response;
    await this.repository.update(dsar);

    // Audit log
    await this.auditLog.log({
      action: 'DSAR_COMPLETED',
      dsarId,
      type: 'access',
      subjectId: dsar.subjectId
    });

    return response;
  }

  private async collectPersonalData(subjectId: string): Promise<PersonalDataCollection> {
    return {
      profile: await this.userService.getProfile(subjectId),
      orders: await this.orderService.getByUser(subjectId),
      communications: await this.emailService.getSentEmails(subjectId),
      activityLogs: await this.activityService.getLogs(subjectId),
      preferences: await this.preferenceService.get(subjectId),
      consentRecords: await this.consentManager.getAll(subjectId),
      supportTickets: await this.supportService.getTickets(subjectId)
    };
  }
}
```

### Pattern 3: Right to Erasure (Right to Be Forgotten)

**When to Use**: Processing Article 17 deletion requests

**Implementation**:
```typescript
class DataErasureService {
  async processErasureRequest(dsarId: string): Promise<ErasureReport> {
    const dsar = await this.dsarRepository.findById(dsarId);
    const subjectId = dsar.subjectId;

    // Check for legal retention requirements
    const retentionBlocks = await this.checkRetentionRequirements(subjectId);

    if (retentionBlocks.length > 0) {
      return {
        status: 'partial',
        reason: 'Legal retention requirements',
        retainedData: retentionBlocks,
        deletedData: await this.performPartialDeletion(subjectId, retentionBlocks)
      };
    }

    // Perform full deletion
    const deletionReport = await this.performFullDeletion(subjectId);

    // Notify third parties
    await this.notifyThirdParties(subjectId);

    return deletionReport;
  }

  private async performFullDeletion(subjectId: string): Promise<ErasureReport> {
    const deletedItems: DeletionItem[] = [];

    // Delete from all data stores
    const dataSources = [
      { name: 'user_profiles', service: this.userService },
      { name: 'orders', service: this.orderService },
      { name: 'communications', service: this.emailService },
      { name: 'activity_logs', service: this.activityService },
      { name: 'analytics', service: this.analyticsService },
      { name: 'backups', service: this.backupService }
    ];

    for (const source of dataSources) {
      try {
        const result = await source.service.deleteUserData(subjectId);
        deletedItems.push({
          source: source.name,
          status: 'deleted',
          recordCount: result.count
        });
      } catch (error) {
        deletedItems.push({
          source: source.name,
          status: 'failed',
          error: error.message
        });
      }
    }

    // Audit log
    await this.auditLog.log({
      action: 'DATA_ERASED',
      subjectId,
      deletedItems,
      timestamp: new Date()
    });

    return {
      status: 'completed',
      deletedData: deletedItems,
      completedAt: new Date()
    };
  }

  private async checkRetentionRequirements(subjectId: string): Promise<RetentionBlock[]> {
    const blocks: RetentionBlock[] = [];

    // Check for legal holds
    const legalHold = await this.legalService.checkHold(subjectId);
    if (legalHold) {
      blocks.push({
        reason: 'legal_hold',
        dataType: 'all',
        retainUntil: legalHold.releaseDate
      });
    }

    // Check for tax/financial records (7 years)
    const hasFinancialRecords = await this.financialService.hasRecords(subjectId);
    if (hasFinancialRecords) {
      blocks.push({
        reason: 'tax_requirements',
        dataType: 'financial_records',
        retainUntil: addYears(new Date(), 7)
      });
    }

    return blocks;
  }
}
```

### Pattern 4: Data Portability

**When to Use**: Processing Article 20 portability requests

**Implementation**:
```typescript
class DataPortabilityService {
  async generatePortableData(subjectId: string): Promise<PortableDataPackage> {
    // Collect data provided by the data subject
    const providedData = await this.collectProvidedData(subjectId);

    // Format as machine-readable JSON
    const package: PortableDataPackage = {
      exportDate: new Date().toISOString(),
      dataSubject: {
        id: subjectId,
        exportFormat: 'JSON',
        gdprArticle: '20'
      },
      data: providedData
    };

    // Generate downloadable file
    const jsonContent = JSON.stringify(package, null, 2);
    const zipFile = await this.createSecureArchive(jsonContent, subjectId);

    // Audit log
    await this.auditLog.log({
      action: 'DATA_EXPORTED',
      subjectId,
      format: 'JSON',
      size: zipFile.size
    });

    return {
      ...package,
      downloadUrl: await this.generateSecureDownloadUrl(zipFile),
      expiresAt: addDays(new Date(), 7)
    };
  }

  private async collectProvidedData(subjectId: string): Promise<any> {
    // Only data provided by the subject (not derived/inferred data)
    return {
      profile: {
        name: await this.userService.getName(subjectId),
        email: await this.userService.getEmail(subjectId),
        address: await this.userService.getAddress(subjectId)
      },
      orders: await this.orderService.getOrderHistory(subjectId),
      content: await this.contentService.getUserContent(subjectId),
      communications: await this.emailService.getSentByUser(subjectId)
    };
  }

  // Transfer to another controller
  async transferToController(
    subjectId: string,
    targetController: ControllerInfo
  ): Promise<TransferResult> {
    const data = await this.generatePortableData(subjectId);

    // Verify target controller
    await this.verifyController(targetController);

    // Secure transfer
    const result = await this.secureTransfer.send({
      data,
      recipient: targetController,
      encryption: 'AES-256-GCM',
      verification: await this.generateTransferProof(data)
    });

    // Audit log
    await this.auditLog.log({
      action: 'DATA_TRANSFERRED',
      subjectId,
      targetController: targetController.name,
      transferId: result.id
    });

    return result;
  }
}
```

### Pattern 5: Privacy by Design Implementation

**When to Use**: Building GDPR-compliant systems

**Implementation**:
```typescript
// Data minimization decorator
function MinimalData(requiredFields: string[]) {
  return function (target: any, propertyKey: string, descriptor: PropertyDescriptor) {
    const original = descriptor.value;

    descriptor.value = async function (...args: any[]) {
      const result = await original.apply(this, args);

      // Strip non-required fields
      if (typeof result === 'object' && result !== null) {
        return pickFields(result, requiredFields);
      }
      return result;
    };

    return descriptor;
  };
}

// Purpose limitation
class PurposeLimitedService {
  private purposeRegistry: Map<string, string[]> = new Map([
    ['marketing', ['email', 'name']],
    ['order_fulfillment', ['name', 'address', 'email', 'phone']],
    ['support', ['name', 'email', 'order_history']]
  ]);

  @MinimalData(['name', 'email'])
  async getDataForMarketing(userId: string): Promise<UserData> {
    // Only returns name and email
    return this.userService.get(userId);
  }

  async accessData(userId: string, purpose: string): Promise<any> {
    // Verify consent for purpose
    const hasConsent = await this.consentManager.hasValidConsent(userId, purpose);
    if (!hasConsent) {
      throw new ConsentRequiredError(purpose);
    }

    // Get only allowed fields for purpose
    const allowedFields = this.purposeRegistry.get(purpose);
    if (!allowedFields) {
      throw new InvalidPurposeError(purpose);
    }

    const userData = await this.userService.get(userId);
    return pickFields(userData, allowedFields);
  }
}

// Retention policy enforcement
class RetentionPolicyEnforcer {
  private policies: RetentionPolicy[] = [
    { dataType: 'activity_logs', retentionDays: 90 },
    { dataType: 'order_data', retentionDays: 2555 }, // 7 years
    { dataType: 'marketing_preferences', retentionDays: 730 }, // 2 years
    { dataType: 'support_tickets', retentionDays: 365 }
  ];

  async enforceRetention(): Promise<RetentionReport> {
    const report: RetentionReport = {
      executedAt: new Date(),
      deletions: []
    };

    for (const policy of this.policies) {
      const cutoffDate = subDays(new Date(), policy.retentionDays);

      const deleted = await this.deleteExpiredData(policy.dataType, cutoffDate);

      report.deletions.push({
        dataType: policy.dataType,
        cutoffDate,
        recordsDeleted: deleted.count
      });
    }

    return report;
  }
}
```

## Checklist

**Lawful Basis**
- [ ] Consent management system implemented
- [ ] Consent records include evidence
- [ ] Consent withdrawal mechanism available
- [ ] Legal basis documented for each processing activity

**Data Subject Rights**
- [ ] DSAR intake process established
- [ ] Identity verification implemented
- [ ] 30-day response SLA tracked
- [ ] Data export in machine-readable format
- [ ] Erasure cascades to all systems

**Technical Measures**
- [ ] Data encrypted at rest and in transit
- [ ] Access controls implement purpose limitation
- [ ] Retention policies automated
- [ ] Audit logging comprehensive
- [ ] Breach detection and notification ready

**Documentation**
- [ ] Records of processing activities (ROPA)
- [ ] Data protection impact assessments (DPIA)
- [ ] Third-party processor agreements
- [ ] Privacy notices current

## References

- [GDPR Full Text](https://gdpr-info.eu/)
- [ICO GDPR Guidance](https://ico.org.uk/for-organisations/guide-to-data-protection/guide-to-the-general-data-protection-regulation-gdpr/)
- [Article 29 Working Party Guidelines](https://ec.europa.eu/newsroom/article29/news-overview.cfm)
- [EDPB Guidelines](https://edpb.europa.eu/our-work-tools/general-guidance/guidelines-recommendations-best-practices_en)
