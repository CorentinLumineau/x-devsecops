# x-devsecops Security Content Rules

## Security Content Rules

When writing security-related skills:

| Rule | Example |
|------|---------|
| **NEVER include real credentials** | Use `<API_KEY>`, `${SECRET}`, `your-token-here` |
| **Show PREVENTION, not exploitation** | Focus on defense, detection, mitigation |
| **Link authoritative sources** | OWASP, NIST, CWE references |
| **Use placeholder values** | `example.com`, `user@example.org` |
| **Mark sensitive sections** | `<!-- SECURITY: ... -->` comments |

---

## Credential Placeholder Standards

```
API keys:     <API_KEY>, ${API_KEY}, your-api-key-here
Passwords:    <PASSWORD>, ${DB_PASSWORD}, ********
Tokens:       <TOKEN>, ${AUTH_TOKEN}, your-token-here
Secrets:      <SECRET>, ${SECRET_KEY}, your-secret-here
```

---

## Cross-Reference Rules

### Allowed References
- **CAN reference**: External authoritative sources (OWASP, NIST, RFCs)
- **CAN reference**: Official documentation (language docs, framework docs)
- **CAN reference**: Other skills within x-devsecops

### Forbidden Dependencies
- **CANNOT depend on**: ccsetup (commands, agents, hooks)
- **CANNOT depend on**: x-workflows (workflow skills)
- **CANNOT have**: Circular dependencies between categories

### Reference Syntax
```markdown
<!-- Cross-category reference -->
See @skills/security/owasp for security context

<!-- External reference -->
Reference: [OWASP Top 10](https://owasp.org/Top10/)
```
