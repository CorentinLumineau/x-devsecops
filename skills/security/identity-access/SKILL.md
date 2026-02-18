---
name: identity-access
description: Identity and access management covering authentication, authorization, and compliance.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Identity & Access Management

Authentication, authorization, and compliance patterns for secure identity and access control.

## 80/20 Focus

Master these areas for 80% of identity and access security:

| Area | Impact | Key Controls |
|------|--------|-------------|
| JWT/OAuth2 | Primary auth mechanism | Short-lived tokens, RS256, refresh rotation |
| RBAC | Most common authz model | Default deny, check ownership, least privilege |
| Audit logging | Compliance requirement | Log access decisions, never log secrets |

## Authentication

### Method Selection

| Method | Security | Use Case |
|--------|----------|----------|
| Session-based | Medium | Traditional web apps |
| JWT (Token-based) | Medium-High | SPAs, mobile apps, APIs |
| OAuth 2.0 | High | Third-party integration |
| MFA | Very High | High-security applications |
| Passwordless | High | Modern UX |

### JWT Best Practices

| Practice | Implementation |
|----------|----------------|
| Algorithm | RS256 (asymmetric), not HS256 |
| Expiration | 15 min for access tokens |
| Refresh tokens | Store in DB, rotate on use, revoke on logout |
| Claims | Include `iss`, `aud`, `jti` for validation |
| Secrets | 32+ characters, cryptographically random |
| Payload | Never store sensitive data in JWT payload |

### Password Hashing

| Algorithm | Status | Configuration |
|-----------|--------|---------------|
| Argon2 | Best | Default params |
| bcrypt | Recommended | 12+ rounds |
| scrypt | Good | N=2^14, r=8, p=1 |
| MD5/SHA1 | **Never use** | - |

### Session Security

```
Cookie Settings:
- secure: true       # HTTPS only
- httpOnly: true     # Prevent XSS access
- sameSite: 'strict' # CSRF protection
- maxAge: 24h        # Appropriate expiration
```

## Authorization

### Pattern Selection

| Use Case | Pattern | Complexity |
|----------|---------|------------|
| Simple app (2-3 user types) | RBAC | Low |
| Enterprise (many roles) | RBAC + Permissions | Medium |
| Complex business rules | ABAC | High |
| User-owned resources | Resource-based | Low |
| Multi-tenant SaaS | ABAC + Resource-based | High |

### RBAC (Role-Based Access Control)

Users -> Roles -> Permissions

```
User: john@example.com
  -> Roles: [admin, user]
  -> Permissions: [users.read, users.write, posts.delete]
```

Role hierarchy: `admin > moderator > user`

### ABAC (Attribute-Based Access Control)

User attributes + Resource attributes + Environment -> Decision

### Resource-Based Authorization

Check ownership before allowing access:
```
if (resource.ownerId !== currentUser.id) {
  return 403 Forbidden
}
```

### Authorization Best Practices

| Practice | Description |
|----------|-------------|
| Default deny | Require explicit grants |
| Separate auth layers | Authentication != Authorization |
| Defense in depth | Check at API, service, and DB layers |
| Audit failures | Log all access denials |
| Hide existence | Return 404 instead of 403 for unauthorized resources |

### HTTP Status Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 401 | Unauthorized | Not authenticated (missing/invalid token) |
| 403 | Forbidden | Authenticated but lacks permission |
| 404 | Not Found | Hide resource existence from unauthorized users |

## Compliance

> See [references/compliance-frameworks.md](references/compliance-frameworks.md) for SOC 2, GDPR, HIPAA, PCI DSS framework details and cross-framework controls.

## Security Checklist

### Authentication
- [ ] Hash passwords with bcrypt (12+) or Argon2
- [ ] Validate password strength (8+ chars, mixed case, numbers, symbols)
- [ ] Rate limit login attempts (5/15min)
- [ ] Generic error messages (prevent user enumeration)
- [ ] Regenerate session ID on login
- [ ] Invalidate sessions on logout
- [ ] Secure cookie flags (secure, httpOnly, sameSite)

### Authorization
- [ ] Default deny (explicit permission grants)
- [ ] Enforce at multiple layers (API, service, database)
- [ ] Never trust client-provided roles
- [ ] Validate authorization on every request
- [ ] Log authorization failures

### Compliance
- [ ] Data classification scheme in place
- [ ] Encryption for sensitive data (at rest and in transit)
- [ ] Comprehensive audit logging
- [ ] Data retention policies defined
- [ ] Privacy policy and consent flows implemented
- [ ] Regular security assessments scheduled

## When to Load References

- **For JWT implementation**: See `references/jwt-patterns.md`
- **For OAuth integration**: See `references/oauth-flows.md`
- **For MFA setup**: See `references/mfa-implementation.md`
- **For RBAC implementation**: See `references/rbac-patterns.md`
- **For ABAC policies**: See `references/abac-policies.md`
- **For database schema**: See `references/auth-schema.md`
- **For compliance frameworks**: See `references/compliance-frameworks.md`
- **For SOC 2 controls**: See `references/soc2-controls.md`
- **For GDPR implementation**: See `references/gdpr-implementation.md`
- **For audit preparation**: See `references/audit-checklist.md`

---

## Related Skills

- **[secure-coding](../secure-coding/SKILL.md)** - OWASP Top 10, input validation, and API security
- **[secrets-supply-chain](../secrets-supply-chain/SKILL.md)** - Secrets management and supply chain security
