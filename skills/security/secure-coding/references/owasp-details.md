---
title: OWASP Top 10 Details Reference
category: security
type: reference
version: "1.0.0"
---

# OWASP Top 10 2021 Complete Reference

> Part of the security/owasp knowledge skill

## Overview

The OWASP Top 10 represents the most critical security risks to web applications. This reference provides detailed coverage of each vulnerability category with detection and prevention strategies.

## 80/20 Quick Reference

**Top 3 vulnerabilities to focus on (80% of risk):**

| Rank | Category | Prevalence | Key Defense |
|------|----------|------------|-------------|
| A01 | Broken Access Control | 34% of apps | Authorization checks everywhere |
| A03 | Injection | 94% tested | Parameterized queries |
| A02 | Cryptographic Failures | Common | Strong encryption, TLS |

## A01: Broken Access Control

**CWE Mappings**: 34 CWEs including CWE-200, CWE-201, CWE-352

**Common Vulnerabilities**:
- Bypassing access controls by modifying URL, state, or HTML
- Elevation of privilege (acting as admin without being one)
- Metadata manipulation (JWT tampering, cookie replay)
- CORS misconfiguration allowing unauthorized API access
- Accessing API with missing access controls for POST, PUT, DELETE

**Prevention**:
```typescript
// Deny by default
function checkPermission(user: User | null, resource: Resource, action: string): boolean {
  // No user = no access
  if (!user) return false;

  // Check explicit permission grants
  return permissionService.hasPermission(user.id, resource.id, action);
}

// Verify ownership
app.put('/api/posts/:id', requireAuth, async (req, res) => {
  const post = await Post.findById(req.params.id);

  if (!post) {
    return res.status(404).json({ error: 'Not found' });
  }

  // Ownership check - don't reveal existence
  if (post.authorId !== req.user.id && !req.user.roles.includes('admin')) {
    return res.status(404).json({ error: 'Not found' });
  }

  // Authorized - proceed
});

// Rate limiting
import rateLimit from 'express-rate-limit';
app.use('/api/', rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));
```

**Detection**:
- Monitor for multiple 403/404 responses from single user
- Log all authorization failures
- Watch for sequential ID access patterns

---

## A02: Cryptographic Failures

**CWE Mappings**: 29 CWEs including CWE-259, CWE-327, CWE-331

**Common Vulnerabilities**:
- Transmitting data in clear text (HTTP instead of HTTPS)
- Using weak cryptographic algorithms (MD5, SHA1, DES)
- Hard-coded encryption keys
- Missing encryption at rest
- Weak password hashing

**Prevention**:
```typescript
// Strong password hashing
import bcrypt from 'bcrypt';
const SALT_ROUNDS = 12;

async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

// Strong encryption at rest
import crypto from 'crypto';

function encrypt(plaintext: string): EncryptedData {
  const algorithm = 'aes-256-gcm';
  const key = Buffer.from(process.env.ENCRYPTION_KEY!, 'hex');
  const iv = crypto.randomBytes(16);

  const cipher = crypto.createCipheriv(algorithm, key, iv);
  const encrypted = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);

  return {
    ciphertext: encrypted.toString('base64'),
    iv: iv.toString('base64'),
    authTag: cipher.getAuthTag().toString('base64')
  };
}

// Enforce HTTPS
app.use((req, res, next) => {
  if (!req.secure && process.env.NODE_ENV === 'production') {
    return res.redirect(301, `https://${req.headers.host}${req.url}`);
  }
  next();
});
```

**Detection**:
- Audit for sensitive data in logs
- Check for HTTP endpoints handling sensitive data
- Review cipher suite configurations

---

## A03: Injection

**CWE Mappings**: 33 CWEs including CWE-79, CWE-89, CWE-73

**Common Vulnerabilities**:
- SQL injection via string concatenation
- NoSQL injection via operator injection
- OS command injection
- LDAP injection
- XPath/XQuery injection

**Prevention**: See injection-prevention.md for detailed patterns

```typescript
// SQL - parameterized
const [users] = await db.execute('SELECT * FROM users WHERE email = ?', [email]);

// NoSQL - type validation
if (typeof password !== 'string') throw new Error('Invalid input');

// Command - use spawn, not exec
spawn('ping', ['-c', '4', validatedHost]);
```

---

## A04: Insecure Design

**CWE Mappings**: 40 CWEs

**Common Vulnerabilities**:
- Missing rate limiting on sensitive operations
- Race conditions in checkout/booking flows
- Missing business logic validation
- No workflow state management

**Prevention**:
```typescript
// Rate limiting for password reset
const resetLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 3,
  skipSuccessfulRequests: true
});

app.post('/reset-password', resetLimiter, verifyCaptcha, handleReset);

// Transaction isolation for race conditions
await db.transaction(async (trx) => {
  const ticket = await trx('tickets').where('id', ticketId).forUpdate().first();

  if (ticket.status !== 'available') {
    throw new Error('Ticket no longer available');
  }

  await trx('tickets').where('id', ticketId).update({ status: 'reserved' });
  await trx('orders').insert({ ticketId, userId });
});
```

**Threat Modeling Questions**:
- What could go wrong?
- What are the trust boundaries?
- What assets need protection?

---

## A05: Security Misconfiguration

**CWE Mappings**: 20 CWEs including CWE-16, CWE-611

**Common Vulnerabilities**:
- Default accounts/passwords enabled
- Unnecessary features enabled
- Verbose error messages in production
- Missing security headers
- Outdated software with known vulnerabilities

**Prevention**:
```typescript
// Safe error handling
app.use((err, req, res, next) => {
  logger.error({ err, url: req.url, userId: req.user?.id });

  res.status(500).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message
  });
});

// Security headers
import helmet from 'helmet';
app.use(helmet());

// Remove unnecessary headers
app.disable('x-powered-by');
```

---

## A06: Vulnerable and Outdated Components

**CWE Mappings**: 3 CWEs including CWE-1104

**Prevention**:
```bash
# Regular scanning
npm audit
npm audit fix

# Automated tools
snyk test
snyk monitor

# Dependency updates
npm update
npm outdated
```

**CI/CD Integration**:
```yaml
- name: Security Audit
  run: |
    npm audit --audit-level=high
    npx snyk test --severity-threshold=high
```

---

## A07: Identification and Authentication Failures

**CWE Mappings**: 22 CWEs including CWE-287, CWE-384

**Common Vulnerabilities**:
- Weak password policies
- Missing brute force protection
- Session fixation
- Predictable session IDs

**Prevention**:
```typescript
// Account lockout
const MAX_ATTEMPTS = 5;
const LOCKOUT_DURATION = 15 * 60 * 1000;

async function checkAccountLockout(userId: string): Promise<boolean> {
  const attempts = await redis.get(`login_attempts:${userId}`);
  const lockedUntil = await redis.get(`lockout:${userId}`);

  if (lockedUntil && Date.now() < parseInt(lockedUntil)) {
    return true;
  }

  return false;
}

// Session regeneration
app.post('/login', async (req, res) => {
  const user = await authenticate(req.body);

  req.session.regenerate((err) => {
    req.session.userId = user.id;
    res.json({ success: true });
  });
});
```

---

## A08: Software and Data Integrity Failures

**CWE Mappings**: 10 CWEs including CWE-502, CWE-829

**Prevention**:
```typescript
// Verify package integrity
// package-lock.json with npm ci

// Subresource Integrity
<script src="https://cdn.example.com/lib.js"
        integrity="sha384-..."
        crossorigin="anonymous"></script>

// Avoid unsafe deserialization
// Don't use eval(), new Function(), or deserialize untrusted data
```

---

## A09: Security Logging and Monitoring Failures

**CWE Mappings**: 4 CWEs including CWE-778

**Prevention**:
```typescript
// Comprehensive logging
const auditLog = {
  authentication: (userId: string, success: boolean, ip: string) => {
    logger.info({
      event: success ? 'AUTH_SUCCESS' : 'AUTH_FAILURE',
      userId,
      ip,
      timestamp: new Date().toISOString()
    });
  },

  authorization: (userId: string, resource: string, action: string, granted: boolean) => {
    logger.info({
      event: granted ? 'ACCESS_GRANTED' : 'ACCESS_DENIED',
      userId,
      resource,
      action,
      timestamp: new Date().toISOString()
    });
  }
};

// Never log sensitive data
function sanitizeForLog(obj: any): any {
  const sensitiveFields = ['password', 'token', 'apiKey', 'secret', 'ssn', 'creditCard'];
  // ... redact sensitive fields
}
```

---

## A10: Server-Side Request Forgery (SSRF)

**CWE Mappings**: 1 CWE (CWE-918)

**Prevention**:
```typescript
// URL validation
function validateUrl(url: string): boolean {
  try {
    const parsed = new URL(url);

    // Only allow HTTPS
    if (parsed.protocol !== 'https:') return false;

    // Block private IPs
    const hostname = parsed.hostname;
    if (hostname === 'localhost' || hostname === '127.0.0.1') return false;
    if (/^(10|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\./.test(hostname)) return false;

    // Allowlist domains
    const allowedDomains = ['api.trusted.com', 'cdn.trusted.com'];
    if (!allowedDomains.some(d => hostname.endsWith(d))) return false;

    return true;
  } catch {
    return false;
  }
}

// Disable redirects
const response = await fetch(url, { redirect: 'error' });
```

## Checklist

- [ ] Access controls checked on every request
- [ ] All data classified by sensitivity
- [ ] Strong encryption for sensitive data
- [ ] Parameterized queries everywhere
- [ ] Rate limiting on sensitive operations
- [ ] Security headers configured
- [ ] Dependencies regularly updated
- [ ] MFA available for users
- [ ] Comprehensive audit logging
- [ ] URL/input validation for external requests

## References

- [OWASP Top 10 2021](https://owasp.org/Top10/)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [CWE Top 25](https://cwe.mitre.org/top25/)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
