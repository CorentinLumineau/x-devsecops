---
name: input-validation
description: Input validation and sanitization patterns to prevent injection attacks.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Input Validation

**Never trust user input** - All external data must be validated.

## 80/20 Focus

These strategies prevent 80% of injection vulnerabilities:

| Strategy | Purpose |
|----------|---------|
| Type validation | Ensure correct data types |
| Format validation | Regex for structured data |
| Whitelist validation | Only allow known-good values |
| Length validation | Prevent overflow and DoS |
| Parameterized queries | Prevent SQL injection |

## Validation vs Sanitization

| Approach | Definition | Action |
|----------|------------|--------|
| Validation | Check if input meets requirements | Accept or reject |
| Sanitization | Clean input to make it safe | Transform |

**Best Practice**: Validate first, sanitize as needed.

## Whitelist vs Blacklist

| Approach | Recommendation | Reason |
|----------|----------------|--------|
| Whitelist | Recommended | Only allows known-good values |
| Blacklist | Avoid | Easy to miss dangerous values |

## Common Validations

### Email
```regex
^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$
```

### Phone (E.164)
```regex
^\+[1-9]\d{1,14}$
```

### Username
```regex
^[a-zA-Z0-9_]{3,20}$
```

### URL (with SSRF prevention)
- Only allow http/https protocols
- Block localhost and private IPs
- Validate domain format

## SQL Injection Prevention

| Method | Example |
|--------|---------|
| Parameterized query | `WHERE id = ?` with params |
| ORM | `User.findById(id)` |
| Prepared statements | `db.prepare()` |

**Never**: String concatenation with user input

## NoSQL Injection Prevention

- Validate types (ensure strings, not objects)
- Reject MongoDB operators (`$ne`, `$gt`)
- Sanitize query objects

## Security Checklist

- [ ] All user input validated before use
- [ ] Type validation for all fields
- [ ] Whitelist validation for enums/options
- [ ] Length limits on strings and arrays
- [ ] Parameterized queries for database operations
- [ ] Output encoding for HTML display
- [ ] File upload validation (type, size, name)

## When to Load References

- **For SQL injection patterns**: See `references/sql-injection.md`
- **For XSS prevention**: See `references/xss-prevention.md`
- **For file upload security**: See `references/file-upload.md`

---

## Related Skills

- **[owasp](../owasp/SKILL.md)** - A03:2021 Injection relies on input validation
- **[authentication](../authentication/SKILL.md)** - Validate auth inputs to prevent credential attacks
- **[authorization](../authorization/SKILL.md)** - Input tampering can bypass authorization
