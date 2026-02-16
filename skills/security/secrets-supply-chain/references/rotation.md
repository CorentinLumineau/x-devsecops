---
title: Secret Rotation Reference
category: security
type: reference
version: "1.0.0"
---

# Secret Rotation Strategies

> Part of the security/secrets knowledge skill

## Overview

Secret rotation limits the window of exposure when credentials are compromised. This reference covers rotation strategies for different secret types, zero-downtime rotation patterns, and automation approaches.

## 80/20 Quick Reference

**Rotation frequency by secret type:**

| Secret Type | Rotation Period | Automation Priority |
|-------------|-----------------|---------------------|
| Database passwords | 30-90 days | Critical |
| API keys | 90 days | High |
| TLS certificates | Before expiry | Critical |
| Encryption keys | Annually | Medium |
| Service tokens | 24 hours | Critical |

**Rotation triggers:**
- Scheduled (time-based)
- Personnel changes (employee departure)
- Suspected compromise
- Compliance requirements

## Patterns

### Pattern 1: Zero-Downtime Rotation

**When to Use**: Production systems that cannot have outages

**Implementation**:
```typescript
// Dual-key rotation pattern
class KeyManager {
  private currentKey: Buffer;
  private previousKey: Buffer | null = null;
  private keyVersion: number = 1;

  constructor() {
    this.loadKeys();
  }

  private async loadKeys() {
    // Load current and previous key from secure storage
    const secrets = await vault.getSecret('myapp/encryption-keys');
    this.currentKey = Buffer.from(secrets.current, 'base64');
    this.keyVersion = secrets.version;

    if (secrets.previous) {
      this.previousKey = Buffer.from(secrets.previous, 'base64');
    }
  }

  // Always encrypt with current key
  encrypt(data: string): EncryptedData {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-gcm', this.currentKey, iv);
    const encrypted = Buffer.concat([cipher.update(data, 'utf8'), cipher.final()]);

    return {
      ciphertext: encrypted.toString('base64'),
      iv: iv.toString('base64'),
      authTag: cipher.getAuthTag().toString('base64'),
      keyVersion: this.keyVersion
    };
  }

  // Decrypt with appropriate key based on version
  decrypt(data: EncryptedData): string {
    const key = data.keyVersion === this.keyVersion
      ? this.currentKey
      : this.previousKey;

    if (!key) {
      throw new Error('Decryption key not available');
    }

    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      key,
      Buffer.from(data.iv, 'base64')
    );
    decipher.setAuthTag(Buffer.from(data.authTag, 'base64'));

    return decipher.update(Buffer.from(data.ciphertext, 'base64')) +
           decipher.final('utf8');
  }

  // Re-encrypt data with current key
  async reEncrypt(data: EncryptedData): Promise<EncryptedData> {
    if (data.keyVersion === this.keyVersion) {
      return data;  // Already using current key
    }

    const plaintext = this.decrypt(data);
    return this.encrypt(plaintext);
  }

  // Rotate keys
  async rotate() {
    // Generate new key
    const newKey = crypto.randomBytes(32);
    const newVersion = this.keyVersion + 1;

    // Store with previous key
    await vault.putSecret('myapp/encryption-keys', {
      current: newKey.toString('base64'),
      previous: this.currentKey.toString('base64'),
      version: newVersion
    });

    // Update in memory
    this.previousKey = this.currentKey;
    this.currentKey = newKey;
    this.keyVersion = newVersion;

    console.log(`Rotated to key version ${newVersion}`);
  }
}
```

### Pattern 2: Database Credential Rotation

**When to Use**: Rotating database passwords without downtime

**Implementation**:
```typescript
// Database rotation with connection pool management
class DatabaseRotator {
  private primaryPool: Pool;
  private secondaryPool: Pool | null = null;
  private isRotating = false;

  async rotate(): Promise<void> {
    if (this.isRotating) {
      throw new Error('Rotation already in progress');
    }

    this.isRotating = true;

    try {
      // Step 1: Generate new credentials
      const newPassword = crypto.randomBytes(32).toString('base64');

      // Step 2: Update database user password (requires admin connection)
      await this.updateDatabasePassword(newPassword);

      // Step 3: Create new connection pool with new credentials
      this.secondaryPool = new Pool({
        host: process.env.DB_HOST,
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: newPassword
      });

      // Step 4: Test new connection
      await this.secondaryPool.query('SELECT 1');

      // Step 5: Store new password in secret manager
      await vault.putSecret('myapp/database', {
        password: newPassword,
        rotatedAt: new Date().toISOString()
      });

      // Step 6: Swap pools
      const oldPool = this.primaryPool;
      this.primaryPool = this.secondaryPool;
      this.secondaryPool = null;

      // Step 7: Drain and close old pool
      await this.drainPool(oldPool);
      await oldPool.end();

      console.log('Database credential rotation completed');
    } finally {
      this.isRotating = false;
    }
  }

  private async updateDatabasePassword(newPassword: string): Promise<void> {
    // Connect with admin credentials
    const adminPool = new Pool({
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      user: process.env.DB_ADMIN_USER,
      password: process.env.DB_ADMIN_PASSWORD
    });

    try {
      await adminPool.query(
        'ALTER USER $1 WITH PASSWORD $2',
        [process.env.DB_USER, newPassword]
      );
    } finally {
      await adminPool.end();
    }
  }

  private async drainPool(pool: Pool): Promise<void> {
    // Wait for in-flight queries to complete
    const timeout = 30000;
    const start = Date.now();

    while (pool.totalCount > pool.idleCount) {
      if (Date.now() - start > timeout) {
        console.warn('Pool drain timeout, forcing close');
        break;
      }
      await new Promise(resolve => setTimeout(resolve, 100));
    }
  }

  // Get active pool
  getPool(): Pool {
    return this.primaryPool;
  }
}
```

### Pattern 3: API Key Rotation

**When to Use**: Rotating third-party API keys

**Implementation**:
```typescript
// API key rotation manager
class ApiKeyRotator {
  private keys: Map<string, ApiKeyInfo> = new Map();

  async rotateKey(service: string): Promise<void> {
    const current = this.keys.get(service);

    // Step 1: Generate new key from provider
    const newKey = await this.generateNewKey(service);

    // Step 2: Store both keys (overlap period)
    await vault.putSecret(`api-keys/${service}`, {
      current: newKey,
      previous: current?.key,
      rotatedAt: new Date().toISOString()
    });

    // Step 3: Update in-memory cache
    this.keys.set(service, {
      key: newKey,
      previousKey: current?.key,
      rotatedAt: new Date()
    });

    // Step 4: Wait for propagation
    await new Promise(resolve => setTimeout(resolve, 60000));

    // Step 5: Revoke old key (if supported by provider)
    if (current?.key) {
      await this.revokeKey(service, current.key);
    }

    // Step 6: Remove previous key from storage
    await vault.putSecret(`api-keys/${service}`, {
      current: newKey,
      previous: null,
      rotatedAt: new Date().toISOString()
    });
  }

  private async generateNewKey(service: string): Promise<string> {
    switch (service) {
      case 'stripe':
        // Stripe keys are rotated through dashboard or API
        // This is a placeholder - actual implementation varies by provider
        return await stripeAdmin.createApiKey();

      case 'sendgrid':
        return await sendgridAdmin.createApiKey({
          name: `app-key-${Date.now()}`,
          scopes: ['mail.send']
        });

      default:
        throw new Error(`Unknown service: ${service}`);
    }
  }

  private async revokeKey(service: string, key: string): Promise<void> {
    // Revoke old key through provider API
    // Implementation varies by provider
  }

  getKey(service: string): string {
    const info = this.keys.get(service);
    if (!info) {
      throw new Error(`No key found for service: ${service}`);
    }
    return info.key;
  }
}
```

### Pattern 4: Automated Rotation Schedule

**When to Use**: Implementing rotation schedules

**Implementation**:
```typescript
import cron from 'node-cron';

class RotationScheduler {
  private rotators: Map<string, RotationConfig> = new Map();

  addRotation(config: RotationConfig): void {
    this.rotators.set(config.name, config);
  }

  start(): void {
    // Database credentials - monthly
    cron.schedule('0 0 1 * *', async () => {
      await this.executeRotation('database');
    });

    // API keys - quarterly
    cron.schedule('0 0 1 */3 *', async () => {
      await this.executeRotation('api-keys');
    });

    // Encryption keys - annually
    cron.schedule('0 0 1 1 *', async () => {
      await this.executeRotation('encryption-keys');
    });

    // Session secrets - weekly
    cron.schedule('0 0 * * 0', async () => {
      await this.executeRotation('session-secret');
    });

    console.log('Rotation scheduler started');
  }

  private async executeRotation(name: string): Promise<void> {
    const config = this.rotators.get(name);
    if (!config) return;

    console.log(`Starting rotation for: ${name}`);

    try {
      await config.rotate();

      await this.notifySuccess(name);
      await this.auditLog(name, 'success');
    } catch (error) {
      console.error(`Rotation failed for ${name}:`, error);
      await this.notifyFailure(name, error);
      await this.auditLog(name, 'failure', error);
    }
  }

  // Emergency rotation (suspected compromise)
  async emergencyRotate(name: string): Promise<void> {
    console.warn(`Emergency rotation triggered for: ${name}`);

    const config = this.rotators.get(name);
    if (!config) {
      throw new Error(`Unknown rotation target: ${name}`);
    }

    // Immediate rotation
    await config.rotate();

    // Notify security team
    await this.notifySecurityTeam(name, 'Emergency rotation completed');

    // Audit
    await this.auditLog(name, 'emergency', { triggeredBy: 'manual' });
  }

  private async notifySuccess(name: string): Promise<void> {
    // Send to monitoring/Slack
  }

  private async notifyFailure(name: string, error: Error): Promise<void> {
    // Alert on-call engineer
  }

  private async notifySecurityTeam(name: string, message: string): Promise<void> {
    // Critical notification
  }

  private async auditLog(name: string, status: string, details?: any): Promise<void> {
    await auditLogger.log({
      event: 'SECRET_ROTATION',
      secret: name,
      status,
      details,
      timestamp: new Date()
    });
  }
}

// Configuration
interface RotationConfig {
  name: string;
  rotate: () => Promise<void>;
  schedule: string;
  notifyChannels: string[];
}
```

### Pattern 5: Certificate Rotation

**When to Use**: TLS certificate management

**Implementation**:
```typescript
import acme from 'acme-client';

class CertificateRotator {
  private client: acme.Client;

  async rotateCertificate(domain: string): Promise<void> {
    // Step 1: Generate new private key
    const privateKey = await acme.crypto.createPrivateKey();

    // Step 2: Create CSR
    const [, csr] = await acme.crypto.createCsr({
      commonName: domain,
      altNames: [`www.${domain}`]
    }, privateKey);

    // Step 3: Request certificate from ACME (Let's Encrypt)
    const certificate = await this.client.auto({
      csr,
      email: 'admin@example.com',
      termsOfServiceAgreed: true,
      challengeCreateFn: async (authz, challenge, keyAuthorization) => {
        // DNS-01 challenge
        await this.createDnsRecord(challenge, keyAuthorization);
      },
      challengeRemoveFn: async (authz, challenge) => {
        await this.removeDnsRecord(challenge);
      }
    });

    // Step 4: Store new certificate
    await vault.putSecret(`certificates/${domain}`, {
      certificate,
      privateKey: privateKey.toString(),
      issuedAt: new Date().toISOString(),
      expiresAt: this.getExpiryDate(certificate).toISOString()
    });

    // Step 5: Reload application/nginx
    await this.reloadService(domain);
  }

  private getExpiryDate(certificate: string): Date {
    const cert = new crypto.X509Certificate(certificate);
    return new Date(cert.validTo);
  }

  async checkExpiring(daysThreshold: number = 30): Promise<string[]> {
    const expiring: string[] = [];
    const domains = await this.listDomains();

    for (const domain of domains) {
      const cert = await vault.getSecret(`certificates/${domain}`);
      const expiresAt = new Date(cert.expiresAt);
      const daysUntilExpiry = (expiresAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24);

      if (daysUntilExpiry < daysThreshold) {
        expiring.push(domain);
      }
    }

    return expiring;
  }
}
```

## Checklist

- [ ] Rotation schedule defined for all secret types
- [ ] Zero-downtime rotation pattern implemented
- [ ] Dual-key support for encryption key rotation
- [ ] Automated rotation for database credentials
- [ ] Certificate expiry monitoring and auto-renewal
- [ ] Emergency rotation procedure documented
- [ ] Rotation events logged and audited
- [ ] Notifications configured for rotation events
- [ ] Rollback procedure documented
- [ ] Rotation tested in staging environment

## References

- [NIST Key Management Guidelines](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)
- [AWS Secrets Manager Rotation](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html)
- [HashiCorp Vault Dynamic Secrets](https://developer.hashicorp.com/vault/docs/secrets)
- [Let's Encrypt Certificate Automation](https://letsencrypt.org/docs/)
