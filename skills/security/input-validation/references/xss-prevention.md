---
title: XSS Prevention Reference
category: security
type: reference
version: "1.0.0"
---

# Cross-Site Scripting (XSS) Prevention

> Part of the security/input-validation knowledge skill

## Overview

Cross-Site Scripting (XSS) attacks inject malicious scripts into web pages viewed by other users. This reference covers the three XSS types and comprehensive prevention patterns including output encoding, CSP, and sanitization.

## 80/20 Quick Reference

**XSS types and primary defenses:**

| Type | Vector | Primary Defense |
|------|--------|-----------------|
| Reflected | URL parameters | Output encoding |
| Stored | Database content | Output encoding + sanitization |
| DOM-based | Client-side JS | Safe DOM APIs |

**Defense layers:**
1. **Output encoding** - Context-appropriate escaping (HTML, JS, URL, CSS)
2. **Content Security Policy** - Browser-enforced script restrictions
3. **Input sanitization** - Remove/neutralize dangerous content
4. **HTTPOnly cookies** - Prevent script access to session tokens

## Patterns

### Pattern 1: HTML Context Output Encoding

**When to Use**: Inserting user data into HTML body

**Implementation**:
```typescript
// HTML entity encoding
function escapeHtml(str: string): string {
  const map: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
    '/': '&#x2F;',
    '`': '&#x60;',
    '=': '&#x3D;'
  };
  return str.replace(/[&<>"'`=/]/g, (char) => map[char]);
}

// Usage in template
app.get('/search', (req, res) => {
  const query = escapeHtml(req.query.q as string || '');
  res.send(`
    <h1>Search Results</h1>
    <p>You searched for: ${query}</p>
  `);
});

// Using template engines with auto-escaping
// EJS (auto-escapes with <%= %>)
// <p>Hello <%= user.name %></p>

// Nunjucks (auto-escapes by default)
// <p>Hello {{ user.name }}</p>

// Handlebars (auto-escapes with {{ }})
// <p>Hello {{user.name}}</p>

// React (auto-escapes JSX)
// <p>Hello {user.name}</p>
```

**Anti-Pattern**: Raw HTML insertion
```typescript
// VULNERABLE - no escaping
res.send(`<p>Hello ${userName}</p>`);

// VULNERABLE - raw HTML in React
<div dangerouslySetInnerHTML={{ __html: userContent }} />

// VULNERABLE - template raw output
// EJS: <%- user.name %>
// Nunjucks: {{ user.name | safe }}
```

### Pattern 2: JavaScript Context Encoding

**When to Use**: Inserting user data into JavaScript code

**Implementation**:
```typescript
// JavaScript string encoding
function escapeJsString(str: string): string {
  return str
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/"/g, '\\"')
    .replace(/\n/g, '\\n')
    .replace(/\r/g, '\\r')
    .replace(/\t/g, '\\t')
    .replace(/\//g, '\\/')
    .replace(/</g, '\\u003C')  // Prevent </script> injection
    .replace(/>/g, '\\u003E')
    .replace(/&/g, '\\u0026');
}

// SECURE - JSON encoding for data
app.get('/page', (req, res) => {
  const userData = { name: req.user.name, settings: req.user.settings };

  // JSON.stringify handles escaping
  res.send(`
    <script>
      const userData = ${JSON.stringify(userData)};
      initApp(userData);
    </script>
  `);
});

// SECURE - data attributes (preferred)
app.get('/page', (req, res) => {
  const userData = { name: req.user.name };

  res.send(`
    <div id="app" data-user='${escapeHtml(JSON.stringify(userData))}'>
    </div>
    <script>
      const userData = JSON.parse(document.getElementById('app').dataset.user);
    </script>
  `);
});
```

**Anti-Pattern**: Direct interpolation in script
```typescript
// VULNERABLE - script injection
res.send(`
  <script>
    const name = "${userName}";  // Attack: "; alert('XSS'); //
  </script>
`);
```

### Pattern 3: URL Context Encoding

**When to Use**: Inserting user data into URLs

**Implementation**:
```typescript
// URL encoding
function encodeUrlComponent(str: string): string {
  return encodeURIComponent(str);
}

// Full URL validation and encoding
function createSafeUrl(base: string, params: Record<string, string>): string {
  const url = new URL(base);

  for (const [key, value] of Object.entries(params)) {
    url.searchParams.set(key, value);  // Auto-encodes
  }

  return url.toString();
}

// SECURE - URL parameter encoding
app.get('/redirect', (req, res) => {
  const returnUrl = req.query.return as string;

  // Validate URL is relative or from allowed domain
  if (!isAllowedRedirectUrl(returnUrl)) {
    return res.status(400).send('Invalid redirect URL');
  }

  res.redirect(returnUrl);
});

function isAllowedRedirectUrl(url: string): boolean {
  // Only allow relative URLs or specific domains
  if (url.startsWith('/') && !url.startsWith('//')) {
    return true;
  }

  try {
    const parsed = new URL(url);
    const allowedHosts = ['example.com', 'www.example.com'];
    return allowedHosts.includes(parsed.hostname);
  } catch {
    return false;
  }
}

// SECURE - href attribute
const safeUrl = createSafeUrl('/search', { q: userInput });
// <a href="${escapeHtml(safeUrl)}">Search</a>
```

**Anti-Pattern**: JavaScript URLs
```typescript
// VULNERABLE - javascript: protocol
const link = `<a href="${userUrl}">Click</a>`;
// Attack: userUrl = "javascript:alert('XSS')"

// SECURE - validate protocol
function sanitizeUrl(url: string): string {
  try {
    const parsed = new URL(url, window.location.origin);
    if (!['http:', 'https:', 'mailto:'].includes(parsed.protocol)) {
      return '#';
    }
    return url;
  } catch {
    return '#';
  }
}
```

### Pattern 4: Content Security Policy

**When to Use**: All web applications

**Implementation**:
```typescript
import helmet from 'helmet';
import crypto from 'crypto';

// Generate nonce per request
app.use((req, res, next) => {
  res.locals.cspNonce = crypto.randomBytes(16).toString('base64');
  next();
});

// CSP configuration
app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: [
      "'self'",
      (req, res) => `'nonce-${res.locals.cspNonce}'`
    ],
    styleSrc: ["'self'", "'unsafe-inline'"],
    imgSrc: ["'self'", "data:", "https:"],
    connectSrc: ["'self'", "https://api.example.com"],
    fontSrc: ["'self'"],
    objectSrc: ["'none'"],
    frameSrc: ["'none'"],
    baseUri: ["'self'"],
    formAction: ["'self'"]
  }
}));

// Use nonce in templates
// <script nonce="<%= cspNonce %>">
//   // Inline script allowed with nonce
// </script>
```

### Pattern 5: HTML Sanitization

**When to Use**: Allowing limited HTML (rich text editors, markdown)

**Implementation**:
```typescript
import DOMPurify from 'isomorphic-dompurify';
import sanitizeHtml from 'sanitize-html';

// DOMPurify - browser and server
function sanitizeContent(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: ['href', 'target'],
    ALLOW_DATA_ATTR: false,
    ADD_ATTR: ['target'],
    FORBID_TAGS: ['script', 'style', 'iframe', 'form', 'input'],
    FORBID_ATTR: ['onerror', 'onclick', 'onload']
  });
}

// sanitize-html - server-side
function sanitizeHtmlContent(dirty: string): string {
  return sanitizeHtml(dirty, {
    allowedTags: ['b', 'i', 'em', 'strong', 'a', 'p', 'br', 'ul', 'ol', 'li', 'h1', 'h2', 'h3'],
    allowedAttributes: {
      'a': ['href', 'target', 'rel']
    },
    allowedSchemes: ['http', 'https', 'mailto'],
    transformTags: {
      'a': (tagName, attribs) => ({
        tagName,
        attribs: {
          ...attribs,
          rel: 'noopener noreferrer',
          target: '_blank'
        }
      })
    }
  });
}

// Usage
app.post('/comments', async (req, res) => {
  const sanitizedContent = sanitizeContent(req.body.content);

  await Comment.create({
    userId: req.user.id,
    content: sanitizedContent  // Safe to store and display
  });

  res.json({ success: true });
});
```

### Pattern 6: DOM-Based XSS Prevention

**When to Use**: Client-side JavaScript applications

**Implementation**:
```typescript
// VULNERABLE - innerHTML
document.getElementById('output').innerHTML = userInput;

// SECURE - textContent (no HTML parsing)
document.getElementById('output').textContent = userInput;

// VULNERABLE - document.write
document.write('<p>' + userInput + '</p>');

// SECURE - DOM methods
const p = document.createElement('p');
p.textContent = userInput;
document.body.appendChild(p);

// VULNERABLE - eval and similar
eval(userInput);
new Function(userInput);
setTimeout(userInput, 1000);

// SECURE - avoid eval entirely
// Use JSON.parse for data, specific handlers for logic

// VULNERABLE - location manipulation
window.location = userInput;

// SECURE - validate URLs
function navigateSafely(url: string) {
  try {
    const parsed = new URL(url, window.location.origin);
    if (parsed.origin === window.location.origin) {
      window.location.href = url;
    }
  } catch {
    console.error('Invalid URL');
  }
}

// SECURE - React prevents XSS by default
function UserProfile({ user }) {
  return (
    <div>
      <h1>{user.name}</h1>  {/* Auto-escaped */}
      <p>{user.bio}</p>      {/* Auto-escaped */}
    </div>
  );
}

// VULNERABLE - bypassing React's protection
function UserProfile({ user }) {
  return (
    <div dangerouslySetInnerHTML={{ __html: user.bio }} />  // XSS risk!
  );
}
```

## Checklist

- [ ] All output encoded for correct context (HTML, JS, URL, CSS)
- [ ] Template engine auto-escaping enabled
- [ ] Content Security Policy configured
- [ ] CSP uses nonces or hashes, not unsafe-inline
- [ ] HTML sanitization for rich text content
- [ ] HTTPOnly flag on session cookies
- [ ] DOM manipulation uses safe APIs (textContent, not innerHTML)
- [ ] URL validation before redirects
- [ ] Regular security testing for XSS
- [ ] X-Content-Type-Options: nosniff header set

## References

- [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html)
- [OWASP DOM XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html)
- [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [DOMPurify](https://github.com/cure53/DOMPurify)
