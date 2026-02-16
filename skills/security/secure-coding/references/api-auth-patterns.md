---
name: API Authentication Patterns
description: API authentication strategies including API keys, JWT, OAuth2, and mTLS
category: security/api-security
type: reference
license: Apache-2.0
---

# API Authentication Patterns

## Pattern Comparison

| Pattern | Use Case | Security Level | Complexity |
|---------|----------|---------------|------------|
| API Key | Server-to-server | Medium | Low |
| JWT Bearer | User-facing APIs | High | Medium |
| OAuth2 | Third-party access | High | High |
| mTLS | Service mesh | Very High | High |
| HMAC Signature | Webhooks, S2S | High | Medium |

## API Key Authentication

Simple but limited. Best for server-to-server communication.

```python
from fastapi import Security, HTTPException
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")

async def verify_api_key(api_key: str = Security(api_key_header)):
    key_record = await db.api_keys.find_one({
        "key_hash": hash_key(api_key),
        "active": True,
        "expires_at": {"$gt": datetime.utcnow()}
    })
    if not key_record:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return key_record

@app.get("/api/data", dependencies=[Security(verify_api_key)])
async def get_data():
    return {"data": "protected"}
```

**Best practices**:
- Hash keys in storage (never store plaintext)
- Support key rotation (multiple active keys)
- Include expiration dates
- Log usage per key for auditing
- Scope keys to specific permissions

## JWT Authentication

**Comprehensive patterns**: See @skills/security-authentication/references/jwt-patterns.md for token generation, storage strategies, refresh rotation, and verification middleware.

**Quick validation example**:
```python
payload = jwt.decode(token, PUBLIC_KEY, algorithms=["RS256"],
                     audience="api.example.com", issuer="auth.example.com")
```

**Key API considerations**:
- Use RS256 (asymmetric) for distributed systems, HS256 for single-service
- Validate `aud` claim to prevent token reuse across APIs
- Include `jti` (JWT ID) for revocation support
- Short access tokens (15 min), longer refresh tokens (7 days)

## OAuth2 Flows

### Authorization Code Flow (recommended for web apps)

```
User → App → Auth Server (/authorize)
         ← redirect with ?code=...
App → Auth Server (/token) with code + client_secret
   ← access_token + refresh_token
App → API with access_token
```

### Client Credentials Flow (service-to-service)

```python
import httpx

async def get_service_token():
    """Obtain token for service-to-service calls."""
    response = await httpx.post(
        "https://auth.example.com/oauth/token",
        data={
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "scope": "read:orders"
        }
    )
    return response.json()["access_token"]
```

### PKCE (for public clients / SPAs)

```javascript
// Generate code verifier and challenge
function generatePKCE() {
  const verifier = base64URLEncode(crypto.getRandomValues(new Uint8Array(32)));
  const challenge = base64URLEncode(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))
  );
  return { verifier, challenge };
}

// Authorization request includes challenge
const authUrl = `https://auth.example.com/authorize?` +
  `response_type=code&` +
  `client_id=${CLIENT_ID}&` +
  `redirect_uri=${REDIRECT_URI}&` +
  `code_challenge=${challenge}&` +
  `code_challenge_method=S256&` +
  `scope=openid profile`;
```

## HMAC Signature (Webhooks)

```python
import hmac
import hashlib

def sign_webhook(payload: bytes, secret: str) -> str:
    """Sign webhook payload with HMAC-SHA256."""
    return hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()

def verify_webhook(payload: bytes, signature: str, secret: str) -> bool:
    """Verify webhook signature (timing-safe comparison)."""
    expected = sign_webhook(payload, secret)
    return hmac.compare_digest(expected, signature)

# Middleware
@app.post("/webhooks/payment")
async def payment_webhook(request: Request):
    body = await request.body()
    signature = request.headers.get("X-Signature-256")

    if not verify_webhook(body, signature, WEBHOOK_SECRET):
        raise HTTPException(401, "Invalid signature")

    process_webhook(json.loads(body))
```

## mTLS (Mutual TLS)

```yaml
# Istio mTLS configuration
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # Require mTLS for all services
```

## Security Checklist

- [ ] Use asymmetric keys (RS256) for JWT, not symmetric (HS256)
- [ ] Short access token lifetime (15 min max)
- [ ] Refresh token rotation on use
- [ ] Token revocation mechanism in place
- [ ] API keys hashed in storage
- [ ] HTTPS enforced for all token exchange
- [ ] Scope/permission validation on every request
- [ ] Timing-safe comparison for signatures

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| JWT `alg: none` attack | Auth bypass | Explicitly set allowed algorithms |
| Storing JWT in localStorage | XSS can steal tokens | Use httpOnly cookies |
| No token revocation | Can't invalidate compromised tokens | Maintain revocation list |
| Long-lived access tokens | Extended exposure window | 15 min max, use refresh |
| API key in URL params | Logged in server logs | Use headers only |
