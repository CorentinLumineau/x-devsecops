---
title: Injection Prevention Reference
category: security
type: reference
version: "1.0.0"
---

# Injection Prevention Patterns

> Part of the security/owasp knowledge skill

## Overview

Injection attacks occur when untrusted data is sent to an interpreter as part of a command or query. This reference covers prevention patterns for SQL, NoSQL, OS command, LDAP, and expression language injection.

## 80/20 Quick Reference

**Injection prevention priorities:**

| Attack Type | Primary Defense | Secondary Defense |
|-------------|-----------------|-------------------|
| SQL Injection | Parameterized queries | ORM/Query builders |
| NoSQL Injection | Type validation | Schema validation |
| Command Injection | Avoid shell; use spawn | Whitelist validation |
| LDAP Injection | Escape special chars | Input validation |
| XPath Injection | Parameterized queries | Input validation |

**Golden Rule**: Never concatenate user input into queries or commands.

## Patterns

### Pattern 1: SQL Injection Prevention

**Primary Defense**: Parameterized queries (never string concatenation)

```typescript
// SECURE - parameterized query
const [rows] = await db.execute('SELECT * FROM users WHERE id = ?', [userId]);

// SECURE - ORM (inherently safe)
return prisma.user.findUnique({ where: { id: userId } });
```

**Comprehensive patterns**: See @skills/security-secure-coding/references/sql-injection.md for:
- ORM query builders (Prisma, TypeORM, Sequelize, Knex)
- Dynamic table/column whitelisting
- IN clause and LIKE clause handling
- Stored procedures
- Multi-language examples (TypeScript, Python, Go, Java)

### Pattern 2: NoSQL Injection Prevention

**When to Use**: MongoDB, CouchDB, and other NoSQL databases

**Implementation**:
```typescript
// MongoDB injection prevention

// WRONG - vulnerable to operator injection
app.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const user = await db.collection('users').findOne({
    username,
    password  // Attack: {"$ne": null} bypasses authentication
  });
});

// CORRECT - type validation
import { z } from 'zod';

const loginSchema = z.object({
  username: z.string().min(1).max(100),
  password: z.string().min(1).max(100)
});

app.post('/login', async (req, res) => {
  // Validate types first
  const result = loginSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(400).json({ error: 'Invalid input' });
  }

  const { username, password } = result.data;

  // Find user and verify password separately
  const user = await db.collection('users').findOne({ username });
  if (!user || !await bcrypt.compare(password, user.passwordHash)) {
    return res.status(401).json({ error: 'Invalid credentials' });
  }

  // Success
});

// CORRECT - operator sanitization
function sanitizeMongoQuery(query: any): any {
  if (typeof query !== 'object' || query === null) {
    return query;
  }

  if (Array.isArray(query)) {
    return query.map(sanitizeMongoQuery);
  }

  const sanitized: Record<string, any> = {};
  for (const [key, value] of Object.entries(query)) {
    // Remove MongoDB operators from user input
    if (key.startsWith('$')) {
      continue;
    }
    sanitized[key] = sanitizeMongoQuery(value);
  }
  return sanitized;
}

// Usage
app.post('/search', async (req, res) => {
  const sanitizedQuery = sanitizeMongoQuery(req.body.filters);
  const results = await db.collection('items').find(sanitizedQuery).toArray();
  res.json(results);
});
```

### Pattern 3: Command Injection Prevention

**When to Use**: When executing system commands

**Implementation**:
```typescript
import { spawn, execFile } from 'child_process';

// WRONG - shell injection
import { exec } from 'child_process';

function pingVulnerable(host: string) {
  exec(`ping -c 4 ${host}`, (error, stdout) => {
    console.log(stdout);
  });
  // Attack: host = "google.com; rm -rf /"
}

// CORRECT - use spawn with array arguments (no shell)
function pingSafe(host: string): Promise<string> {
  return new Promise((resolve, reject) => {
    // Validate input first
    if (!/^[a-zA-Z0-9.-]+$/.test(host)) {
      reject(new Error('Invalid hostname'));
      return;
    }

    // spawn does not use shell, arguments are separate
    const ping = spawn('ping', ['-c', '4', host]);

    let output = '';
    ping.stdout.on('data', (data) => {
      output += data;
    });

    ping.on('close', (code) => {
      if (code === 0) {
        resolve(output);
      } else {
        reject(new Error(`ping exited with code ${code}`));
      }
    });
  });
}

// CORRECT - execFile with explicit arguments
function convertImage(inputPath: string, outputPath: string) {
  // Validate paths
  if (!inputPath.match(/^[a-zA-Z0-9_\-./]+$/)) {
    throw new Error('Invalid input path');
  }

  // execFile does not invoke shell
  execFile('convert', [inputPath, '-resize', '100x100', outputPath], (error) => {
    if (error) throw error;
  });
}

// BEST - avoid shell entirely using native libraries
import sharp from 'sharp';

async function convertImageNative(inputPath: string, outputPath: string) {
  await sharp(inputPath)
    .resize(100, 100)
    .toFile(outputPath);
}
```

**Anti-Pattern**: Using shell: true option
```typescript
// VULNERABLE - shell: true enables injection
spawn('ping', ['-c', '4', host], { shell: true });
```

### Pattern 4: LDAP Injection Prevention

**When to Use**: LDAP directory authentication/queries

**Implementation**:
```typescript
// LDAP special characters that need escaping
const LDAP_ESCAPE_MAP: Record<string, string> = {
  '*': '\\2a',
  '(': '\\28',
  ')': '\\29',
  '\\': '\\5c',
  '\0': '\\00',
  '/': '\\2f'
};

function escapeLdapFilter(input: string): string {
  return input.replace(/[*()\\\/\0]/g, (char) => LDAP_ESCAPE_MAP[char] || char);
}

function escapeLdapDn(input: string): string {
  // DN has different escaping rules
  return input.replace(/[,\\#+<>;"=]/g, (char) => '\\' + char);
}

// WRONG - vulnerable
function findUserVulnerable(username: string) {
  const filter = `(&(objectClass=user)(cn=${username}))`;
  // Attack: username = "*)(uid=*))(|(uid=*"
  return ldap.search(filter);
}

// CORRECT - escaped
async function findUser(username: string) {
  // Validate format first
  if (!/^[a-zA-Z0-9._-]+$/.test(username)) {
    throw new Error('Invalid username format');
  }

  const escapedUsername = escapeLdapFilter(username);
  const filter = `(&(objectClass=user)(cn=${escapedUsername}))`;
  return ldap.search(filter);
}

// CORRECT - parameterized (if supported by library)
import ldapjs from 'ldapjs';

async function findUserParameterized(username: string) {
  const filter = new ldapjs.filters.AndFilter({
    filters: [
      new ldapjs.filters.EqualityFilter({
        attribute: 'objectClass',
        value: 'user'
      }),
      new ldapjs.filters.EqualityFilter({
        attribute: 'cn',
        value: username  // Library handles escaping
      })
    ]
  });

  return client.search(baseDn, { filter });
}
```

### Pattern 5: Expression Language Injection Prevention

**When to Use**: Template engines, rule engines

**Implementation**:
```typescript
// Server-Side Template Injection (SSTI) prevention

// WRONG - user input in template
import nunjucks from 'nunjucks';

app.get('/greet', (req, res) => {
  const template = `Hello ${req.query.name}!`;  // Injection risk
  const output = nunjucks.renderString(template, {});
  // Attack: name = "{{constructor.constructor('return this')()}}"
  res.send(output);
});

// CORRECT - use context variables
app.get('/greet', (req, res) => {
  const template = 'Hello {{ name }}!';  // Fixed template
  const output = nunjucks.renderString(template, {
    name: req.query.name  // Passed as data, not code
  });
  res.send(output);
});

// CORRECT - sandboxed environment
const env = nunjucks.configure({
  autoescape: true,
  throwOnUndefined: true
});

// CORRECT - disable dangerous features
env.addGlobal('constructor', undefined);
env.addGlobal('__proto__', undefined);
env.addGlobal('prototype', undefined);

// Expression language (SpEL) in Java - use safe evaluation
// Don't allow user input in expression context
// Use property placeholders instead of expression evaluation
```

## Checklist

- [ ] All SQL queries use parameterized statements
- [ ] ORM/Query builder used where possible
- [ ] NoSQL queries validate input types
- [ ] MongoDB operators stripped from user input
- [ ] Shell commands use spawn/execFile, not exec
- [ ] Command arguments are array, not string concatenation
- [ ] LDAP filters escape special characters
- [ ] Template engines use data context, not string interpolation
- [ ] Input validation as defense in depth
- [ ] Regular code review for injection patterns

## References

- [OWASP Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Injection_Prevention_Cheat_Sheet.html)
- [OWASP SQL Injection](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- [CWE-78: OS Command Injection](https://cwe.mitre.org/data/definitions/78.html)
