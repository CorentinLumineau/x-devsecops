---
title: Security Headers Reference
category: security
type: reference
version: "1.0.0"
---

# HTTP Security Headers

> Part of the security/owasp knowledge skill

## Overview

HTTP security headers provide browser-side protections against XSS, clickjacking, MIME sniffing, and other attacks. This reference covers essential headers, their configuration, and implementation patterns.

## 80/20 Quick Reference

**Essential security headers ranked by impact:**

| Header | Protects Against | Priority |
|--------|------------------|----------|
| Content-Security-Policy | XSS, data injection | Critical |
| Strict-Transport-Security | MITM, protocol downgrade | Critical |
| X-Frame-Options | Clickjacking | High |
| X-Content-Type-Options | MIME sniffing | High |
| Referrer-Policy | Information leakage | Medium |
| Permissions-Policy | Feature abuse | Medium |

## Patterns

### Pattern 1: Content Security Policy (CSP)

**When to Use**: All web applications

**Implementation**:
```typescript
// Express.js with Helmet
import helmet from 'helmet';

app.use(helmet.contentSecurityPolicy({
  directives: {
    // Default fallback for unspecified directives
    defaultSrc: ["'self'"],

    // Scripts - strict for XSS prevention
    scriptSrc: [
      "'self'",
      // Use nonce for inline scripts (preferred over unsafe-inline)
      (req, res) => `'nonce-${res.locals.cspNonce}'`
    ],

    // Styles
    styleSrc: ["'self'", "'unsafe-inline'"],  // unsafe-inline often needed for CSS-in-JS

    // Images
    imgSrc: ["'self'", "data:", "https:"],

    // Fonts
    fontSrc: ["'self'", "https://fonts.gstatic.com"],

    // API calls
    connectSrc: ["'self'", "https://api.example.com"],

    // Media
    mediaSrc: ["'self'"],

    // Embeds
    objectSrc: ["'none'"],  // Disable plugins

    // Frames
    frameSrc: ["'none'"],  // Disable iframes
    frameAncestors: ["'none'"],  // Prevent being framed

    // Form actions
    formAction: ["'self'"],

    // Base URI
    baseUri: ["'self'"],

    // Upgrade insecure requests
    upgradeInsecureRequests: []
  }
}));

// Generate nonce for each request
app.use((req, res, next) => {
  res.locals.cspNonce = crypto.randomBytes(16).toString('base64');
  next();
});

// Use nonce in templates
// <script nonce="<%= cspNonce %>">...</script>
```

**Report-Only Mode for Testing**:
```typescript
// Test CSP without breaking functionality
app.use(helmet.contentSecurityPolicy({
  directives: {
    // ... directives
    reportUri: '/csp-report'
  },
  reportOnly: true  // Only report violations, don't block
}));

// Collect CSP reports
app.post('/csp-report', express.json({ type: 'application/csp-report' }), (req, res) => {
  console.log('CSP Violation:', req.body);
  res.status(204).send();
});
```

**Anti-Pattern**: Using 'unsafe-inline' for scripts
```typescript
// WEAK - allows XSS
scriptSrc: ["'self'", "'unsafe-inline'"]

// BETTER - use nonces or hashes
scriptSrc: ["'self'", "'nonce-abc123'"]
scriptSrc: ["'self'", "'sha256-...'"]
```

### Pattern 2: HTTP Strict Transport Security (HSTS)

**When to Use**: All HTTPS sites

**Implementation**:
```typescript
// Basic HSTS
app.use(helmet.hsts({
  maxAge: 31536000,  // 1 year in seconds
  includeSubDomains: true,
  preload: true  // Submit to browser preload list
}));

// Manual header setting
app.use((req, res, next) => {
  res.setHeader(
    'Strict-Transport-Security',
    'max-age=31536000; includeSubDomains; preload'
  );
  next();
});

// Redirect HTTP to HTTPS
app.use((req, res, next) => {
  if (!req.secure && process.env.NODE_ENV === 'production') {
    return res.redirect(301, `https://${req.headers.host}${req.url}`);
  }
  next();
});
```

**HSTS Preload Requirements**:
1. Valid HTTPS certificate
2. Redirect HTTP to HTTPS on same host
3. HSTS header with max-age >= 1 year
4. includeSubDomains directive
5. preload directive

**Anti-Pattern**: Short max-age
```typescript
// WEAK - attacker has window to downgrade
maxAge: 86400  // Only 1 day

// CORRECT - at least 1 year
maxAge: 31536000
```

### Pattern 3: Frame Protection Headers

**When to Use**: Prevent clickjacking attacks

**Implementation**:
```typescript
// X-Frame-Options (legacy but widely supported)
app.use(helmet.frameguard({ action: 'deny' }));
// or
app.use(helmet.frameguard({ action: 'sameorigin' }));

// CSP frame-ancestors (modern, more flexible)
app.use(helmet.contentSecurityPolicy({
  directives: {
    frameAncestors: ["'none'"]  // Deny all framing
    // or
    frameAncestors: ["'self'", "https://trusted.com"]
  }
}));

// Manual combined approach
app.use((req, res, next) => {
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Content-Security-Policy', "frame-ancestors 'none'");
  next();
});
```

**Selective Framing for Embeds**:
```typescript
// Allow specific pages to be framed
app.get('/embed/:id', (req, res, next) => {
  // This page can be embedded
  res.removeHeader('X-Frame-Options');
  res.setHeader('Content-Security-Policy', "frame-ancestors https://partner.com");
  next();
}, embedController);
```

### Pattern 4: Additional Security Headers

**When to Use**: Defense in depth

**Implementation**:
```typescript
import helmet from 'helmet';

// Complete Helmet configuration
app.use(helmet({
  // Prevent MIME type sniffing
  contentTypeOptions: true,  // X-Content-Type-Options: nosniff

  // DNS prefetch control
  dnsPrefetchControl: { allow: false },

  // Download options for IE
  ieNoOpen: true,  // X-Download-Options: noopen

  // Hide X-Powered-By
  hidePoweredBy: true,

  // Referrer policy
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' },

  // Cross-Origin policies
  crossOriginEmbedderPolicy: true,  // COEP
  crossOriginOpenerPolicy: { policy: 'same-origin' },  // COOP
  crossOriginResourcePolicy: { policy: 'same-origin' },  // CORP

  // Origin Agent Cluster
  originAgentCluster: true
}));

// Permissions Policy (formerly Feature Policy)
app.use((req, res, next) => {
  res.setHeader('Permissions-Policy',
    'geolocation=(), ' +
    'microphone=(), ' +
    'camera=(), ' +
    'payment=(), ' +
    'usb=(), ' +
    'magnetometer=(), ' +
    'gyroscope=(), ' +
    'accelerometer=()'
  );
  next();
});

// Cache control for sensitive pages
app.get('/account/*', (req, res, next) => {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  next();
});
```

### Pattern 5: API Security Headers

**When to Use**: REST/GraphQL APIs

**Implementation**:
```typescript
// API-specific headers
app.use('/api', (req, res, next) => {
  // Prevent caching of API responses with sensitive data
  res.setHeader('Cache-Control', 'no-store');

  // CORS headers (be specific, not *)
  res.setHeader('Access-Control-Allow-Origin', 'https://yourapp.com');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');

  // Prevent content type sniffing
  res.setHeader('X-Content-Type-Options', 'nosniff');

  // API responses should not be framed
  res.setHeader('X-Frame-Options', 'DENY');

  next();
});

// JSON-specific security
app.use('/api', (req, res, next) => {
  // Ensure JSON content type
  res.setHeader('Content-Type', 'application/json; charset=utf-8');

  // Prevent JSON hijacking (legacy protection)
  res.setHeader('X-Content-Type-Options', 'nosniff');

  next();
});
```

### Pattern 6: Header Validation Middleware

**When to Use**: Verify security headers are properly set

**Implementation**:
```typescript
// Middleware to verify security headers in non-production
function validateSecurityHeaders(req: Request, res: Response, next: NextFunction) {
  if (process.env.NODE_ENV === 'production') {
    return next();
  }

  res.on('finish', () => {
    const warnings: string[] = [];

    if (!res.getHeader('Strict-Transport-Security')) {
      warnings.push('Missing HSTS header');
    }

    if (!res.getHeader('Content-Security-Policy')) {
      warnings.push('Missing CSP header');
    }

    const xfo = res.getHeader('X-Frame-Options');
    if (!xfo || (xfo !== 'DENY' && xfo !== 'SAMEORIGIN')) {
      warnings.push('Missing or weak X-Frame-Options');
    }

    if (!res.getHeader('X-Content-Type-Options')) {
      warnings.push('Missing X-Content-Type-Options');
    }

    if (warnings.length > 0) {
      console.warn(`Security header warnings for ${req.path}:`, warnings);
    }
  });

  next();
}
```

## Checklist

- [ ] CSP configured with nonces, no unsafe-inline for scripts
- [ ] HSTS enabled with max-age >= 1 year
- [ ] includeSubDomains and preload on HSTS
- [ ] X-Frame-Options set to DENY or SAMEORIGIN
- [ ] X-Content-Type-Options: nosniff
- [ ] Referrer-Policy configured appropriately
- [ ] Permissions-Policy disables unnecessary features
- [ ] Cache-Control: no-store on sensitive pages
- [ ] CORS headers are specific, not wildcard
- [ ] Security headers tested with observatory.mozilla.org

## References

- [MDN HTTP Headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers)
- [OWASP Secure Headers](https://owasp.org/www-project-secure-headers/)
- [Mozilla Observatory](https://observatory.mozilla.org/)
- [Security Headers Scanner](https://securityheaders.com/)
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)
