---
name: authentication
description: Secure user identity verification patterns. JWT, OAuth, MFA, session-based auth.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Authentication

Secure user identity verification before granting access.

## Authentication Methods

| Method | Security | Use Case |
|--------|----------|----------|
| **Session-based** | Medium | Traditional web apps |
| **JWT (Token-based)** | Medium-High | SPAs, mobile apps, APIs |
| **OAuth 2.0** | High | Third-party integration |
| **MFA** | Very High | High-security applications |
| **Passwordless** | High | Modern UX |

## JWT Best Practices

| Practice | Implementation |
|----------|----------------|
| Strong secrets | 32+ characters, cryptographically random |
| Short expiration | 15m for sensitive ops, 7d for general |
| Refresh token rotation | Store in DB, revoke on logout |
| Include issuer/audience | Validate on every request |

## Session Security

```
Cookie Settings:
- secure: true       # HTTPS only
- httpOnly: true     # Prevent XSS
- sameSite: 'strict' # CSRF protection
- maxAge: 24h        # Appropriate expiration
```

## Password Hashing

| Algorithm | Status | Salt Rounds |
|-----------|--------|-------------|
| bcrypt | Recommended | 12+ |
| Argon2 | Best | Default params |
| scrypt | Good | N=2^14, r=8, p=1 |
| MD5/SHA1 | Never use | - |

## Security Checklist

### Registration
- [ ] Hash passwords with bcrypt (12+ rounds)
- [ ] Validate password strength (8+ chars, mixed case, numbers, symbols)
- [ ] Prevent email enumeration (generic responses)
- [ ] Rate limit registration attempts

### Login
- [ ] Constant-time password comparison
- [ ] Rate limit login attempts (5/15min)
- [ ] Log failed attempts for monitoring
- [ ] Generic error messages (prevent user enumeration)

### Password Reset
- [ ] Secure random reset tokens
- [ ] Short expiration (1 hour max)
- [ ] One-time use tokens
- [ ] Send to email only (never expose in URL)

### Session Management
- [ ] Regenerate session ID on login
- [ ] Invalidate sessions on logout
- [ ] Set appropriate cookie flags
- [ ] Implement session timeout

## When to Load References

- **For JWT implementation**: See `references/jwt-patterns.md`
- **For OAuth integration**: See `references/oauth-flows.md`
- **For MFA setup**: See `references/mfa-implementation.md`

---

## Related Skills

- **[authorization](../authorization/SKILL.md)** - Permission models after identity is verified
- **[owasp](../owasp/SKILL.md)** - A07:2021 covers authentication failures
- **[secrets](../secrets/SKILL.md)** - Credential storage and rotation for auth tokens
