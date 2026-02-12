---
name: owasp
description: OWASP Top 10 2021 security vulnerabilities prevention and detection.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# OWASP Top 10 (2021)

Most critical web application security risks.

## 80/20 Focus

Master these three (80% of vulnerabilities):

| Rank | Vulnerability | Prevalence |
|------|---------------|------------|
| A01 | Broken Access Control | 34% |
| A03 | Injection | 94% tested |
| A02 | Cryptographic Failures | 2nd most common |

## A01: Broken Access Control

**Risk**: Users access unauthorized resources.

**Prevention**:
- Deny by default
- Check ownership on every request
- Validate authorization at multiple layers
- Rate limit API calls
- Log access control failures

**Detection**: Multiple 403s, sequential ID access attempts

## A02: Cryptographic Failures

**Risk**: Sensitive data exposed via weak/missing crypto.

**Prevention**:
- Always use HTTPS (TLS 1.3)
- Hash passwords with bcrypt/Argon2
- Use AES-256-GCM for encryption
- Never hard-code secrets
- Classify data sensitivity

**Detection**: Sensitive data in logs, weak ciphers, HTTP traffic

## A03: Injection

**Risk**: Untrusted data executed as commands.

**Types**: SQL, NoSQL, OS command, LDAP

**Prevention**:
- Use parameterized queries (always)
- Validate input types
- Whitelist allowed values
- Escape output

**Detection**: SQL keywords in input, `$ne`/`$gt` operators, command separators

## Quick Reference

| Vulnerability | Key Prevention |
|---------------|----------------|
| A01 Access Control | Default deny, check ownership |
| A02 Crypto Failures | HTTPS, strong hashing, AES-256 |
| A03 Injection | Parameterized queries, validation |
| A04 Insecure Design | Threat modeling, rate limiting |
| A05 Misconfiguration | Security headers, no defaults |
| A06 Outdated Components | `npm audit`, dependency scanning |
| A07 Auth Failures | MFA, rate limiting, session security |
| A08 Integrity Failures | Code signing, CI/CD security |
| A09 Logging Failures | Audit logs, never log secrets |
| A10 SSRF | URL validation, allowlists |

## Security Checklist

- [ ] Default deny for access control
- [ ] Parameterized queries for all database operations
- [ ] HTTPS enforced with TLS 1.3
- [ ] Strong password hashing (bcrypt 12+)
- [ ] Security headers configured (helmet.js)
- [ ] Rate limiting on sensitive endpoints
- [ ] Input validation on all user data
- [ ] No secrets in code or logs

## When to Load References

- **For injection examples**: See `references/injection-prevention.md`
- **For security headers**: See `references/security-headers.md`
- **For detailed A01-A10**: See `references/owasp-details.md`

---

## Related Skills

- **[input-validation](../input-validation/SKILL.md)** - Primary defense against injection attacks (A03)
- **[authentication](../authentication/SKILL.md)** - Identification and authentication failures (A07)
- **[supply-chain](../supply-chain/SKILL.md)** - Vulnerable and outdated components (A06)
