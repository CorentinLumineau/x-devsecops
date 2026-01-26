---
title: OAuth 2.0 Flows Reference
category: security
type: reference
version: "1.0.0"
---

# OAuth 2.0 Authorization Flows

> Part of the security/authentication knowledge skill

## Overview

OAuth 2.0 provides delegated authorization for third-party applications. This reference covers the four main grant types, their security characteristics, and implementation patterns for each use case.

## 80/20 Quick Reference

**Flow selection based on application type:**

| Application Type | Recommended Flow | PKCE Required |
|-----------------|------------------|---------------|
| Web app with backend | Authorization Code | Optional |
| SPA (no backend) | Authorization Code + PKCE | Required |
| Mobile app | Authorization Code + PKCE | Required |
| Server-to-server | Client Credentials | N/A |
| CLI/Device | Device Code | N/A |

**Never use Implicit Flow** - deprecated due to security vulnerabilities.

## Patterns

### Pattern 1: Authorization Code Flow (Web Apps)

**When to Use**: Traditional web applications with a backend server

**Implementation**:
```typescript
import { OAuth2Client } from 'google-auth-library';
import crypto from 'crypto';

const oauth2Client = new OAuth2Client(
  process.env.GOOGLE_CLIENT_ID,
  process.env.GOOGLE_CLIENT_SECRET,
  process.env.GOOGLE_REDIRECT_URI
);

// Step 1: Generate authorization URL
app.get('/auth/google', (req, res) => {
  // Generate state parameter to prevent CSRF
  const state = crypto.randomBytes(32).toString('hex');
  req.session.oauthState = state;

  const authUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline', // Request refresh token
    scope: ['profile', 'email'],
    state: state,
    prompt: 'consent' // Force consent screen for refresh token
  });

  res.redirect(authUrl);
});

// Step 2: Handle callback
app.get('/auth/google/callback', async (req, res) => {
  const { code, state } = req.query;

  // Verify state parameter
  if (state !== req.session.oauthState) {
    return res.status(403).json({ error: 'Invalid state parameter' });
  }
  delete req.session.oauthState;

  try {
    // Exchange code for tokens
    const { tokens } = await oauth2Client.getToken(code as string);

    // Verify ID token
    const ticket = await oauth2Client.verifyIdToken({
      idToken: tokens.id_token!,
      audience: process.env.GOOGLE_CLIENT_ID
    });

    const payload = ticket.getPayload();

    // Create or update user
    const user = await findOrCreateUser({
      email: payload.email,
      name: payload.name,
      picture: payload.picture,
      provider: 'google',
      providerId: payload.sub
    });

    // Store refresh token securely
    if (tokens.refresh_token) {
      await storeRefreshToken(user.id, tokens.refresh_token);
    }

    // Create session
    req.session.userId = user.id;
    res.redirect('/dashboard');
  } catch (error) {
    res.status(500).json({ error: 'Authentication failed' });
  }
});
```

**Anti-Pattern**: Not validating state parameter
```typescript
// VULNERABLE to CSRF attacks
app.get('/callback', async (req, res) => {
  const { code } = req.query;
  // Missing state validation!
  const tokens = await oauth2Client.getToken(code);
});
```

### Pattern 2: Authorization Code Flow with PKCE (SPAs/Mobile)

**When to Use**: Public clients that cannot securely store secrets

**Implementation**:
```typescript
// Client-side PKCE generation
function generatePKCE(): { codeVerifier: string; codeChallenge: string } {
  // Generate code verifier (43-128 characters)
  const codeVerifier = crypto.randomBytes(32)
    .toString('base64url')
    .slice(0, 128);

  // Generate code challenge (SHA256 hash of verifier)
  const codeChallenge = crypto
    .createHash('sha256')
    .update(codeVerifier)
    .digest('base64url');

  return { codeVerifier, codeChallenge };
}

// Step 1: Initiate authorization
async function startAuth() {
  const { codeVerifier, codeChallenge } = generatePKCE();

  // Store verifier securely (session storage for web, secure storage for mobile)
  sessionStorage.setItem('pkce_verifier', codeVerifier);

  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: REDIRECT_URI,
    response_type: 'code',
    scope: 'openid profile email',
    state: crypto.randomBytes(16).toString('hex'),
    code_challenge: codeChallenge,
    code_challenge_method: 'S256'
  });

  window.location.href = `${AUTH_SERVER}/authorize?${params}`;
}

// Step 2: Exchange code with verifier
async function handleCallback(code: string) {
  const codeVerifier = sessionStorage.getItem('pkce_verifier');
  sessionStorage.removeItem('pkce_verifier');

  const response = await fetch(`${AUTH_SERVER}/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: CLIENT_ID,
      code: code,
      redirect_uri: REDIRECT_URI,
      code_verifier: codeVerifier
    })
  });

  return response.json();
}
```

**Anti-Pattern**: Using plain code challenge
```typescript
// WEAK - use S256 instead
code_challenge_method: 'plain' // Doesn't protect against interception
```

### Pattern 3: Client Credentials Flow (Server-to-Server)

**When to Use**: Service-to-service authentication without user context

**Implementation**:
```typescript
class ServiceAuthClient {
  private accessToken: string | null = null;
  private tokenExpiry: Date | null = null;

  async getAccessToken(): Promise<string> {
    // Return cached token if valid
    if (this.accessToken && this.tokenExpiry && this.tokenExpiry > new Date()) {
      return this.accessToken;
    }

    // Request new token
    const response = await fetch(`${AUTH_SERVER}/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': `Basic ${Buffer.from(
          `${process.env.CLIENT_ID}:${process.env.CLIENT_SECRET}`
        ).toString('base64')}`
      },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        scope: 'api.read api.write'
      })
    });

    if (!response.ok) {
      throw new Error('Failed to obtain access token');
    }

    const data = await response.json();

    this.accessToken = data.access_token;
    // Refresh slightly before expiry
    this.tokenExpiry = new Date(Date.now() + (data.expires_in - 60) * 1000);

    return this.accessToken;
  }

  async callApi(endpoint: string) {
    const token = await this.getAccessToken();

    return fetch(endpoint, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });
  }
}
```

**Anti-Pattern**: Hardcoding credentials
```typescript
// NEVER do this
const CLIENT_SECRET = 'hardcoded-secret-in-code';
```

### Pattern 4: Device Code Flow (CLI/IoT)

**When to Use**: Input-constrained devices (TVs, CLIs, IoT)

**Implementation**:
```typescript
async function deviceCodeFlow() {
  // Step 1: Request device code
  const deviceResponse = await fetch(`${AUTH_SERVER}/device/code`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: CLIENT_ID,
      scope: 'openid profile'
    })
  });

  const { device_code, user_code, verification_uri, interval, expires_in } =
    await deviceResponse.json();

  // Step 2: Display to user
  console.log(`Visit: ${verification_uri}`);
  console.log(`Enter code: ${user_code}`);

  // Step 3: Poll for token
  const deadline = Date.now() + expires_in * 1000;

  while (Date.now() < deadline) {
    await sleep(interval * 1000);

    try {
      const tokenResponse = await fetch(`${AUTH_SERVER}/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
          client_id: CLIENT_ID,
          device_code: device_code
        })
      });

      if (tokenResponse.ok) {
        return tokenResponse.json();
      }

      const error = await tokenResponse.json();
      if (error.error === 'authorization_pending') {
        continue; // Keep polling
      }
      if (error.error === 'slow_down') {
        await sleep(5000); // Back off
        continue;
      }
      throw new Error(error.error_description);
    } catch (e) {
      // Network error, retry
    }
  }

  throw new Error('Authorization timeout');
}
```

## Checklist

- [ ] State parameter used and validated for CSRF protection
- [ ] PKCE implemented for public clients (SPAs, mobile)
- [ ] Redirect URIs strictly validated (exact match)
- [ ] Client secrets stored securely (not in code)
- [ ] Tokens stored securely (HttpOnly cookies or secure storage)
- [ ] Refresh tokens encrypted at rest
- [ ] Token scope limited to minimum required
- [ ] ID tokens validated (signature, issuer, audience, expiry)
- [ ] Error responses do not leak sensitive information

## References

- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [OAuth 2.0 for Native Apps RFC 8252](https://tools.ietf.org/html/rfc8252)
- [PKCE RFC 7636](https://tools.ietf.org/html/rfc7636)
- [OAuth 2.0 Security Best Practices](https://tools.ietf.org/html/draft-ietf-oauth-security-topics)
