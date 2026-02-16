---
name: CORS Security
description: Cross-Origin Resource Sharing security configuration and common mistakes
category: security/api-security
type: reference
license: Apache-2.0
---

# CORS Security

## How CORS Works

```
Browser (origin: app.example.com) → API (api.example.com)

1. Simple request (GET, POST with simple headers):
   Browser sends request with Origin header
   Server responds with Access-Control-Allow-Origin

2. Preflight request (PUT, DELETE, custom headers):
   Browser sends OPTIONS request first
   Server responds with allowed methods/headers
   Browser sends actual request if allowed
```

## Preflight Flow

```
Browser                              Server
  │                                    │
  │ OPTIONS /api/data                  │
  │ Origin: https://app.example.com    │
  │ Access-Control-Request-Method: PUT │
  │ Access-Control-Request-Headers:    │
  │   Authorization, Content-Type      │
  │ ──────────────────────────────────►│
  │                                    │
  │ 204 No Content                     │
  │ Access-Control-Allow-Origin:       │
  │   https://app.example.com          │
  │ Access-Control-Allow-Methods:      │
  │   GET, POST, PUT, DELETE           │
  │ Access-Control-Allow-Headers:      │
  │   Authorization, Content-Type      │
  │ Access-Control-Max-Age: 3600       │
  │◄──────────────────────────────────│
  │                                    │
  │ PUT /api/data (actual request)     │
  │ ──────────────────────────────────►│
```

## Secure Configuration

### Express.js

```javascript
const cors = require('cors');

const corsOptions = {
  origin: function (origin, callback) {
    const allowedOrigins = [
      'https://app.example.com',
      'https://admin.example.com'
    ];

    // Allow requests with no origin (mobile apps, curl)
    if (!origin) return callback(null, true);

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Authorization', 'Content-Type'],
  exposedHeaders: ['X-RateLimit-Remaining'],
  credentials: true,
  maxAge: 3600
};

app.use(cors(corsOptions));
```

### Python FastAPI

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://app.example.com",
        "https://admin.example.com",
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    expose_headers=["X-RateLimit-Remaining"],
    max_age=3600,
)
```

### Nginx

```nginx
server {
    location /api/ {
        # Specific origin, not wildcard
        set $cors_origin "";
        if ($http_origin ~* "^https://(app|admin)\.example\.com$") {
            set $cors_origin $http_origin;
        }

        add_header Access-Control-Allow-Origin $cors_origin always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE" always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type" always;
        add_header Access-Control-Allow-Credentials "true" always;
        add_header Access-Control-Max-Age 3600 always;

        # Handle preflight
        if ($request_method = OPTIONS) {
            return 204;
        }

        proxy_pass http://backend;
    }
}
```

## Security Rules

### Origin Validation

| Configuration | Security | Notes |
|--------------|----------|-------|
| `*` (wildcard) | Unsafe | Never with credentials |
| Specific origins | Safe | Whitelist approach |
| Regex origins | Risky | Can be bypassed if poorly written |
| `null` origin | Unsafe | Used by sandboxed iframes, file:// |
| Reflecting `Origin` header | Unsafe | Equivalent to wildcard |

### Dangerous Patterns

```javascript
// DANGEROUS: Reflects any origin (equivalent to wildcard)
app.use(cors({
  origin: true,
  credentials: true
}));

// DANGEROUS: Regex that matches too broadly
origin: /example\.com/  // Matches evil-example.com too!

// DANGEROUS: Allowing null origin
origin: [null, 'https://app.example.com']
// null origin can be forged via sandboxed iframes

// SAFE: Exact match list
origin: ['https://app.example.com', 'https://admin.example.com']
```

### Subdomain Patterns

```javascript
// Safe subdomain matching
function isAllowedOrigin(origin) {
  if (!origin) return false;

  try {
    const url = new URL(origin);
    // Exact match on domain, allow any subdomain
    return url.hostname === 'example.com'
        || url.hostname.endsWith('.example.com');
  } catch {
    return false;
  }
}
```

## CORS and Authentication

```
With credentials (cookies, Authorization header):
  - Access-Control-Allow-Origin MUST be specific (not *)
  - Access-Control-Allow-Credentials: true required
  - Set-Cookie must have SameSite=None; Secure

Without credentials:
  - Access-Control-Allow-Origin can be * (but still prefer specific)
  - Access-Control-Allow-Credentials omitted or false
```

## Preflight Caching

```
Access-Control-Max-Age: 3600  (1 hour)

Effect: Browser caches preflight response
  - Reduces OPTIONS requests
  - Improves performance
  - Set to 0 during development for easier debugging
  - Maximum varies by browser (Chrome: 2h, Firefox: 24h)
```

## Testing CORS

```bash
# Test preflight request
curl -X OPTIONS https://api.example.com/data \
  -H "Origin: https://app.example.com" \
  -H "Access-Control-Request-Method: PUT" \
  -H "Access-Control-Request-Headers: Authorization" \
  -v 2>&1 | grep -i "access-control"

# Test actual request
curl https://api.example.com/data \
  -H "Origin: https://evil.com" \
  -v 2>&1 | grep -i "access-control"
# Should NOT return Access-Control-Allow-Origin for evil.com
```

## Common Pitfalls

| Pitfall | Impact | Fix |
|---------|--------|-----|
| `origin: *` with credentials | Browsers block it | Use specific origins |
| Reflecting Origin header | All origins allowed | Use allowlist |
| No CORS on error responses | Leaks info via error messages | Add CORS to all responses |
| Missing `Vary: Origin` | Caching issues with CDN | Add Vary header |
| Overly broad regex | Subdomain bypass | Use exact match or strict regex |
