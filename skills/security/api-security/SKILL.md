---
name: api-security
description: API security patterns for protecting web services and endpoints.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: [Read, Grep, Glob]
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# API Security

Security patterns for protecting APIs from abuse, unauthorized access, and injection attacks.

## Quick Reference (80/20)

Focus on these three areas (80% of API security):

| Area | Impact | Must-Have |
|------|--------|-----------|
| Authentication | Blocks unauthorized access | JWT/OAuth2 with short-lived tokens |
| Rate limiting | Prevents abuse and DDoS | Per-client limits with backoff |
| Input validation | Stops injection attacks | Schema validation at boundary |

## Authentication Patterns

| Pattern | Use Case | Token Lifetime |
|---------|----------|---------------|
| API Key | Server-to-server, low sensitivity | Long-lived, rotatable |
| JWT Bearer | User-facing APIs | 15 min access + refresh token |
| OAuth2 | Third-party access | Scoped, revocable |
| mTLS | Service mesh, high security | Certificate lifetime |

### JWT Best Practices

```json
{
  "alg": "RS256",
  "typ": "JWT"
}
{
  "sub": "user-123",
  "iss": "auth.example.com",
  "aud": "api.example.com",
  "exp": 1700000000,
  "iat": 1699999100,
  "scope": "read:orders write:orders",
  "jti": "unique-token-id"
}
```

**Rules**:
- Use RS256 (asymmetric), not HS256 (shared secret)
- Short expiry (15 min max for access tokens)
- Include `aud` (audience) to prevent token reuse
- Include `jti` for revocation support
- Validate all claims on every request
- Never store sensitive data in JWT payload

## Rate Limiting

### Strategy Selection

| Algorithm | Behavior | Best For |
|-----------|----------|----------|
| Fixed window | N requests per time window | Simple, most APIs |
| Sliding window | Smoothed fixed window | Avoiding burst at window edges |
| Token bucket | Allows controlled bursts | APIs with burst traffic |
| Leaky bucket | Constant output rate | Strict rate enforcement |

### Standard Headers

```
X-RateLimit-Limit: 100        # Max requests per window
X-RateLimit-Remaining: 45     # Requests remaining
X-RateLimit-Reset: 1700000060 # Window reset time (epoch)
Retry-After: 30               # Seconds to wait (on 429)
```

## CORS Configuration

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
- Keep preflight cache (`max-age`) reasonable

## Input Validation

Validate all input at the API boundary:

```yaml
# OpenAPI schema validation
parameters:
  - name: limit
    in: query
    schema:
      type: integer
      minimum: 1
      maximum: 100
      default: 20
requestBody:
  content:
    application/json:
      schema:
        type: object
        required: [email, name]
        properties:
          email:
            type: string
            format: email
            maxLength: 255
          name:
            type: string
            minLength: 1
            maxLength: 100
            pattern: "^[a-zA-Z\\s'-]+$"
```

**Rules**:
- Validate type, format, length, and pattern
- Reject unknown fields (deny by default)
- Sanitize output (prevent XSS in error messages)
- Use allowlists over denylists

## Security Headers

Every API response should include:

```
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Cache-Control: no-store
Content-Security-Policy: default-src 'none'
```

## When to Load References

- **For rate limiting details**: See `references/rate-limiting.md`
- **For CORS security**: See `references/cors-security.md`
- **For API auth patterns**: See `references/api-auth-patterns.md`

## Cross-References

- **OWASP vulnerabilities**: See `security/owasp` skill
- **Authentication patterns**: See `security/authentication` skill
- **Input validation**: See `security/input-validation` skill
- **API design**: See `code/api-design` skill
