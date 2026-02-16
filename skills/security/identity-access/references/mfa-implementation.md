---
title: MFA Implementation Reference
category: security
type: reference
version: "1.0.0"
---

# Multi-Factor Authentication Implementation

> Part of the security/authentication knowledge skill

## Overview

Multi-factor authentication (MFA) adds security layers beyond passwords by requiring something you know (password), something you have (device/token), or something you are (biometrics). This reference covers TOTP, WebAuthn, and SMS backup implementation patterns.

## 80/20 Quick Reference

**MFA methods ranked by security and usability:**

| Method | Security | Phishing Resistant | Usability |
|--------|----------|-------------------|-----------|
| WebAuthn/FIDO2 | Highest | Yes | High |
| Hardware Token | Very High | Yes | Medium |
| TOTP App | High | No | High |
| Push Notification | High | Partial | High |
| SMS/Voice | Low | No | High |

**Recommendation**: Implement TOTP as baseline, offer WebAuthn as upgrade path.

## Patterns

### Pattern 1: TOTP (Time-based One-Time Password)

**When to Use**: Standard second factor for most applications

**Implementation**:
```typescript
import speakeasy from 'speakeasy';
import QRCode from 'qrcode';

class TOTPService {
  // Step 1: Generate secret for user
  async enableMFA(userId: string, userEmail: string): Promise<MFASetupResponse> {
    const secret = speakeasy.generateSecret({
      name: `YourApp:${userEmail}`,
      issuer: 'YourApp',
      length: 32 // 256 bits
    });

    // Store secret temporarily until verified
    await this.mfaPendingRepository.save({
      userId,
      secret: this.encryptSecret(secret.base32),
      createdAt: new Date()
    });

    // Generate QR code
    const qrCodeUrl = await QRCode.toDataURL(secret.otpauth_url!);

    // Also provide manual entry option
    return {
      qrCode: qrCodeUrl,
      manualEntry: secret.base32,
      backupCodes: await this.generateBackupCodes(userId)
    };
  }

  // Step 2: Verify initial setup
  async verifyMFASetup(userId: string, token: string): Promise<boolean> {
    const pending = await this.mfaPendingRepository.findByUserId(userId);
    if (!pending) {
      throw new Error('No pending MFA setup');
    }

    const secret = this.decryptSecret(pending.secret);

    const isValid = speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2 // Allow 2 time steps (60 seconds) drift
    });

    if (isValid) {
      // Move to permanent storage
      await this.userRepository.update(userId, {
        mfaSecret: pending.secret, // Already encrypted
        mfaEnabled: true,
        mfaEnabledAt: new Date()
      });
      await this.mfaPendingRepository.delete(pending.id);
    }

    return isValid;
  }

  // Step 3: Verify during login
  async verifyMFALogin(userId: string, token: string): Promise<boolean> {
    const user = await this.userRepository.findById(userId);

    if (!user.mfaEnabled) {
      return true; // MFA not required
    }

    // Check backup code first
    if (token.length === 10) { // Backup codes are 10 chars
      return this.verifyBackupCode(userId, token);
    }

    const secret = this.decryptSecret(user.mfaSecret);

    return speakeasy.totp.verify({
      secret,
      encoding: 'base32',
      token,
      window: 2
    });
  }

  // Generate backup codes
  private async generateBackupCodes(userId: string): Promise<string[]> {
    const codes = Array.from({ length: 10 }, () =>
      crypto.randomBytes(5).toString('hex').toUpperCase()
    );

    // Store hashed codes
    const hashedCodes = await Promise.all(
      codes.map(code => bcrypt.hash(code, 10))
    );

    await this.backupCodeRepository.save({
      userId,
      codes: hashedCodes,
      usedCodes: []
    });

    return codes; // Return plaintext codes once for user to save
  }
}
```

**Anti-Pattern**: Not encrypting TOTP secrets at rest
```typescript
// VULNERABLE - secrets stored in plaintext
await userRepository.update(userId, {
  mfaSecret: secret.base32 // Should be encrypted!
});
```

### Pattern 2: WebAuthn/FIDO2 (Phishing-Resistant)

**When to Use**: High-security applications, passwordless authentication

**Implementation**:
```typescript
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse
} from '@simplewebauthn/server';

const rpName = 'YourApp';
const rpID = 'yourapp.com';
const origin = 'https://yourapp.com';

class WebAuthnService {
  // Step 1: Generate registration options
  async startRegistration(userId: string): Promise<PublicKeyCredentialCreationOptions> {
    const user = await this.userRepository.findById(userId);
    const existingCredentials = await this.credentialRepository.findByUserId(userId);

    const options = generateRegistrationOptions({
      rpName,
      rpID,
      userID: user.id,
      userName: user.email,
      userDisplayName: user.name,
      attestationType: 'none', // 'direct' for enterprise
      excludeCredentials: existingCredentials.map(cred => ({
        id: cred.credentialId,
        type: 'public-key',
        transports: cred.transports
      })),
      authenticatorSelection: {
        residentKey: 'preferred',
        userVerification: 'preferred',
        authenticatorAttachment: 'cross-platform' // or 'platform' for built-in
      }
    });

    // Store challenge for verification
    await this.challengeRepository.save({
      challenge: options.challenge,
      userId,
      type: 'registration',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000)
    });

    return options;
  }

  // Step 2: Verify registration
  async finishRegistration(
    userId: string,
    response: RegistrationResponseJSON
  ): Promise<WebAuthnCredential> {
    const challenge = await this.challengeRepository.findLatest(userId, 'registration');

    if (!challenge || challenge.expiresAt < new Date()) {
      throw new Error('Challenge expired');
    }

    const verification = await verifyRegistrationResponse({
      response,
      expectedChallenge: challenge.challenge,
      expectedOrigin: origin,
      expectedRPID: rpID
    });

    if (!verification.verified) {
      throw new Error('Registration verification failed');
    }

    const { credentialPublicKey, credentialID, counter } = verification.registrationInfo!;

    // Store credential
    const credential = await this.credentialRepository.save({
      userId,
      credentialId: Buffer.from(credentialID).toString('base64url'),
      publicKey: Buffer.from(credentialPublicKey).toString('base64'),
      counter,
      transports: response.response.transports,
      createdAt: new Date()
    });

    await this.challengeRepository.delete(challenge.id);

    return credential;
  }

  // Step 3: Generate authentication options
  async startAuthentication(userId?: string): Promise<PublicKeyCredentialRequestOptions> {
    const allowCredentials = userId
      ? (await this.credentialRepository.findByUserId(userId)).map(cred => ({
          id: Buffer.from(cred.credentialId, 'base64url'),
          type: 'public-key' as const,
          transports: cred.transports
        }))
      : [];

    const options = generateAuthenticationOptions({
      rpID,
      allowCredentials,
      userVerification: 'preferred'
    });

    await this.challengeRepository.save({
      challenge: options.challenge,
      userId,
      type: 'authentication',
      expiresAt: new Date(Date.now() + 5 * 60 * 1000)
    });

    return options;
  }

  // Step 4: Verify authentication
  async finishAuthentication(
    response: AuthenticationResponseJSON
  ): Promise<{ verified: boolean; userId: string }> {
    const credentialId = response.id;
    const credential = await this.credentialRepository.findByCredentialId(credentialId);

    if (!credential) {
      throw new Error('Credential not found');
    }

    const challenge = await this.challengeRepository.findLatest(
      credential.userId,
      'authentication'
    );

    const verification = await verifyAuthenticationResponse({
      response,
      expectedChallenge: challenge.challenge,
      expectedOrigin: origin,
      expectedRPID: rpID,
      authenticator: {
        credentialPublicKey: Buffer.from(credential.publicKey, 'base64'),
        credentialID: Buffer.from(credential.credentialId, 'base64url'),
        counter: credential.counter
      }
    });

    if (verification.verified) {
      // Update counter to prevent replay attacks
      await this.credentialRepository.update(credential.id, {
        counter: verification.authenticationInfo.newCounter
      });
    }

    return { verified: verification.verified, userId: credential.userId };
  }
}
```

**Anti-Pattern**: Not validating counter
```typescript
// VULNERABLE to replay attacks
// Missing counter validation allows reuse of captured assertions
```

### Pattern 3: MFA During Login Flow

**When to Use**: Integrating MFA into existing authentication

**Implementation**:
```typescript
class AuthService {
  async login(email: string, password: string, mfaToken?: string): Promise<LoginResponse> {
    // Step 1: Verify password
    const user = await this.userRepository.findByEmail(email);

    if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
      // Timing-safe response
      await bcrypt.hash(password, 10);
      return { error: 'Invalid credentials' };
    }

    // Step 2: Check if MFA required
    if (user.mfaEnabled) {
      if (!mfaToken) {
        // Return partial success, request MFA
        const tempToken = jwt.sign(
          { userId: user.id, type: 'mfa_pending' },
          process.env.JWT_SECRET!,
          { expiresIn: '5m' }
        );

        return {
          mfaRequired: true,
          tempToken,
          methods: user.mfaMethods // ['totp', 'webauthn', 'backup']
        };
      }

      // Step 3: Verify MFA
      const mfaValid = await this.mfaService.verifyMFALogin(user.id, mfaToken);

      if (!mfaValid) {
        await this.auditLog.log({
          userId: user.id,
          action: 'MFA_FAILED',
          ip: req.ip
        });
        return { error: 'Invalid MFA code' };
      }
    }

    // Step 4: Complete login
    const accessToken = this.generateAccessToken(user);
    const refreshToken = await this.generateRefreshToken(user);

    await this.auditLog.log({
      userId: user.id,
      action: 'LOGIN_SUCCESS',
      mfaUsed: user.mfaEnabled,
      ip: req.ip
    });

    return { accessToken, refreshToken, user: this.sanitizeUser(user) };
  }
}
```

## Checklist

- [ ] TOTP secrets encrypted at rest
- [ ] Backup codes generated and hashed
- [ ] Time window allows for clock drift (30-60 seconds)
- [ ] WebAuthn counter validated to prevent replay
- [ ] Challenges expire after 5 minutes
- [ ] MFA status cannot be modified without re-authentication
- [ ] Recovery flow requires identity verification
- [ ] Audit logging for all MFA events
- [ ] Rate limiting on MFA verification attempts
- [ ] Clear user guidance for MFA setup

## References

- [RFC 6238 - TOTP](https://tools.ietf.org/html/rfc6238)
- [WebAuthn Specification](https://www.w3.org/TR/webauthn-2/)
- [NIST SP 800-63B - Authentication](https://pages.nist.gov/800-63-3/sp800-63b.html)
- [OWASP MFA Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html)
