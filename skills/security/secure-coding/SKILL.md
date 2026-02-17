---
name: secure-coding
description: Secure coding practices covering OWASP Top 10, input validation, and API security.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Secure Coding

Comprehensive secure coding practices: OWASP Top 10 prevention, input validation, and API security.

## 80/20 Focus

Master these areas to prevent 80% of web application vulnerabilities:

| Area | Impact | Key Prevention |
|------|--------|----------------|
| Injection (A03) | 94% of apps tested | Parameterized queries, input validation |
| Broken Access Control (A01) | 34% prevalence | Default deny, ownership checks |
| API abuse | Top attack vector | Rate limiting, CORS, schema validation |

## OWASP Top 10 (2021) Quick Reference

| ID | Vulnerability | Key Prevention |
|----|---------------|----------------|
| A01 | Broken Access Control | Default deny, check ownership on every request |
| A02 | Cryptographic Failures | HTTPS (TLS 1.3), bcrypt/Argon2, AES-256-GCM |
| A03 | Injection | Parameterized queries, type validation, whitelist |
| A04 | Insecure Design | Threat modeling, rate limiting, secure defaults |
| A05 | Security Misconfiguration | Security headers, remove defaults, least privilege |
| A06 | Vulnerable Components | `npm audit`, dependency scanning, version pinning |
| A07 | Auth Failures | MFA, rate limiting, session security |
| A08 | Integrity Failures | Code signing, CI/CD security, SRI |
| A09 | Logging Failures | Audit logs, structured logging, never log secrets |
| A10 | SSRF | URL allowlists, block private IPs, validate schemes |

## Input Validation

### Validation Strategy

| Strategy | Purpose | Example |
|----------|---------|---------|
| Type validation | Ensure correct data types | Integer for ID, string for name |
| Format validation | Regex for structured data | Email, phone, URL patterns |
| Whitelist validation | Only allow known-good values | Enum fields, allowed statuses |
| Length validation | Prevent overflow and DoS | Max 255 for email, max 100 for name |
| Parameterized queries | Prevent SQL injection | `WHERE id = ?` with params |

### Whitelist vs Blacklist

| Approach | Recommendation | Reason |
|----------|----------------|--------|
| Whitelist | **Recommended** | Only allows known-good values |
| Blacklist | **Avoid** | Easy to miss dangerous values |

**Rule**: Validate first, sanitize as needed. Never trust client input.

### SQL Injection Prevention

| Method | Example |
|--------|---------|
| Parameterized query | `WHERE id = ?` with params |
| ORM | `User.findById(id)` |
| Prepared statements | `db.prepare()` |

**Never**: String concatenation with user input.

### NoSQL Injection Prevention

- Validate types (ensure strings, not objects)
- Reject MongoDB operators (`$ne`, `$gt`)
- Sanitize query objects

## API Security

### CORS Configuration

```
Allowed Origins:   https://app.example.com (specific, not *)
Allowed Methods:   GET, POST, PUT, DELETE
Allowed Headers:   Authorization, Content-Type
Expose Headers:    X-RateLimit-Remaining
Max Age:           3600 (cache preflight for 1h)
Credentials:       true (if cookies needed)
```

**Rules**:
- Never use `Access-Control-Allow-Origin: *` with credentials
- Whitelist specific origins
- Restrict methods to what the API actually uses

### Rate Limiting

| Algorithm | Behavior | Best For |
|-----------|----------|----------|
| Fixed window | N requests per time window | Simple, most APIs |
| Sliding window | Smoothed fixed window | Avoiding burst at window edges |
| Token bucket | Allows controlled bursts | APIs with burst traffic |
| Leaky bucket | Constant output rate | Strict rate enforcement |

Standard headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`, `Retry-After`

### Security Headers

Every response should include:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Cache-Control: no-store
Content-Security-Policy: default-src 'none'
```

### API Input Validation

Validate all input at the API boundary:
- Validate type, format, length, and pattern
- Reject unknown fields (deny by default)
- Sanitize output (prevent XSS in error messages)
- Use allowlists over denylists
- Use OpenAPI schema validation

## Security Checklist

### OWASP Essentials
- [ ] Default deny for access control
- [ ] Parameterized queries for all database operations
- [ ] HTTPS enforced with TLS 1.3
- [ ] Strong password hashing (bcrypt 12+ / Argon2)
- [ ] Security headers configured
- [ ] No secrets in code or logs

### Input Validation
- [ ] All user input validated before use
- [ ] Type validation for all fields
- [ ] Whitelist validation for enums/options
- [ ] Length limits on strings and arrays
- [ ] Output encoding for HTML display
- [ ] File upload validation (type, size, name)

### API Security
- [ ] Rate limiting on sensitive endpoints
- [ ] CORS restricted to specific origins
- [ ] Schema validation at API boundary
- [ ] Authentication on all non-public endpoints
- [ ] Security headers on all responses

## When to Load References

- **For injection examples**: See `references/injection-prevention.md`
- **For security headers**: See `references/security-headers.md`
- **For detailed OWASP A01-A10**: See `references/owasp-details.md`
- **For SQL injection patterns**: See `references/sql-injection.md`
- **For XSS prevention**: See `references/xss-prevention.md`
- **For file upload security**: See `references/file-upload.md`
- **For rate limiting details**: See `references/rate-limiting.md`
- **For CORS security**: See `references/cors-security.md`
- **For API auth patterns**: See `references/api-auth-patterns.md`

---

## Related Skills

- **[identity-access](../identity-access/SKILL.md)** - Authentication, authorization, and compliance
- **[secrets-supply-chain](../secrets-supply-chain/SKILL.md)** - Secrets management and supply chain security
- **code/api-design** - API design patterns including rate limiting and SDK error handling from an implementation perspective
