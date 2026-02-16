---
title: JWT Patterns Reference
category: security
type: reference
version: "1.0.0"
---

# JWT Token Patterns

> Part of the security/authentication knowledge skill

## Overview

JSON Web Tokens (JWT) provide stateless authentication for APIs and SPAs. This reference covers secure token generation, storage strategies, and refresh mechanisms to prevent common vulnerabilities.

## 80/20 Quick Reference

**Critical practices that prevent 80% of JWT vulnerabilities:**

| Practice | Why It Matters |
|----------|----------------|
| Use strong secrets (32+ chars) | Prevents brute-force attacks |
| Short access token expiry (15m) | Limits exposure window |
| Store refresh tokens server-side | Enables revocation |
| Never store JWTs in localStorage | XSS vulnerability |
| Validate algorithm in verification | Prevents algorithm confusion |

## Patterns

### Pattern 1: Secure Token Generation

**When to Use**: Any JWT-based authentication system

**Implementation**:
```typescript
import jwt from 'jsonwebtoken';
import crypto from 'crypto';

// Strong secret generation (run once, store securely)
const JWT_SECRET = crypto.randomBytes(32).toString('hex');

interface TokenPayload {
  userId: string;
  email: string;
  role: string;
}

function generateAccessToken(user: TokenPayload): string {
  return jwt.sign(
    {
      sub: user.userId,
      email: user.email,
      role: user.role,
      type: 'access'
    },
    process.env.JWT_SECRET!,
    {
      algorithm: 'HS256',
      expiresIn: '15m',
      issuer: 'your-app',
      audience: 'your-app-users'
    }
  );
}

function generateRefreshToken(user: TokenPayload): string {
  return jwt.sign(
    {
      sub: user.userId,
      type: 'refresh'
    },
    process.env.JWT_REFRESH_SECRET!,
    {
      algorithm: 'HS256',
      expiresIn: '7d',
      issuer: 'your-app'
    }
  );
}
```

**Anti-Pattern**: Using weak secrets or none algorithm
```typescript
// NEVER do this
jwt.sign(payload, 'weak'); // Too short
jwt.sign(payload, secret, { algorithm: 'none' }); // No signature
```

### Pattern 2: Token Storage Strategies

**When to Use**: Deciding where to store JWTs client-side

**Implementation**:
```typescript
// Server-side: HttpOnly cookie (recommended for web apps)
function setAuthCookies(res: Response, accessToken: string, refreshToken: string) {
  res.cookie('access_token', accessToken, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    maxAge: 15 * 60 * 1000 // 15 minutes
  });

  res.cookie('refresh_token', refreshToken, {
    httpOnly: true,
    secure: true,
    sameSite: 'strict',
    path: '/api/auth/refresh', // Only sent to refresh endpoint
    maxAge: 7 * 24 * 60 * 60 * 1000 // 7 days
  });
}

// Client-side: Memory storage for SPAs (when cookies not possible)
class TokenManager {
  private accessToken: string | null = null;

  setToken(token: string) {
    this.accessToken = token;
  }

  getToken(): string | null {
    return this.accessToken;
  }

  clearToken() {
    this.accessToken = null;
  }
}
```

**Anti-Pattern**: localStorage storage
```typescript
// NEVER do this - vulnerable to XSS
localStorage.setItem('jwt', token);
```

### Pattern 3: Refresh Token Rotation

**When to Use**: Long-lived sessions with security requirements

**Implementation**:
```typescript
interface RefreshToken {
  id: string;
  userId: string;
  tokenHash: string;
  expiresAt: Date;
  revokedAt?: Date;
  replacedByTokenId?: string;
}

class TokenService {
  async refreshTokens(refreshToken: string): Promise<TokenPair> {
    // Verify refresh token
    const payload = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!);

    // Find token in database
    const storedToken = await this.refreshTokenRepository.findByHash(
      crypto.createHash('sha256').update(refreshToken).digest('hex')
    );

    if (!storedToken || storedToken.revokedAt) {
      // Token reuse detected - revoke entire family
      await this.revokeTokenFamily(storedToken?.userId);
      throw new Error('Token reuse detected');
    }

    // Generate new token pair
    const user = await this.userRepository.findById(payload.sub);
    const newAccessToken = generateAccessToken(user);
    const newRefreshToken = generateRefreshToken(user);

    // Rotate: revoke old, store new
    await this.refreshTokenRepository.revoke(storedToken.id, newRefreshToken.id);
    await this.refreshTokenRepository.create({
      userId: user.id,
      tokenHash: crypto.createHash('sha256').update(newRefreshToken).digest('hex'),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    });

    return { accessToken: newAccessToken, refreshToken: newRefreshToken };
  }
}
```

**Anti-Pattern**: Reusing refresh tokens without rotation
```typescript
// NEVER do this - no rotation means compromised tokens last forever
return { accessToken: newAccessToken, refreshToken: originalRefreshToken };
```

### Pattern 4: Token Verification Middleware

**When to Use**: Protecting API endpoints

**Implementation**:
```typescript
function verifyToken(req: Request, res: Response, next: NextFunction) {
  // Try cookie first, then Authorization header
  const token = req.cookies.access_token ||
    req.headers.authorization?.replace('Bearer ', '');

  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET!, {
      algorithms: ['HS256'], // Explicitly specify allowed algorithms
      issuer: 'your-app',
      audience: 'your-app-users'
    });

    if (payload.type !== 'access') {
      return res.status(401).json({ error: 'Invalid token type' });
    }

    req.user = payload;
    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired', code: 'TOKEN_EXPIRED' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
}
```

**Anti-Pattern**: Not validating algorithm
```typescript
// VULNERABLE - allows algorithm confusion attacks
jwt.verify(token, secret); // No algorithm restriction
```

## Checklist

- [ ] JWT secret is 32+ characters from cryptographically secure source
- [ ] Access tokens expire in 15 minutes or less
- [ ] Refresh tokens stored server-side with hash
- [ ] Refresh token rotation implemented
- [ ] Algorithm explicitly specified in sign and verify
- [ ] Tokens stored in HttpOnly cookies (web) or memory (SPA)
- [ ] Token type field distinguishes access from refresh
- [ ] Issuer and audience validated
- [ ] Token revocation mechanism exists

## References

- [JWT Best Practices - RFC 8725](https://tools.ietf.org/html/rfc8725)
- [OWASP JWT Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [Auth0 JWT Handbook](https://auth0.com/resources/ebooks/jwt-handbook)
