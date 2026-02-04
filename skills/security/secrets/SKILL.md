---
name: secrets
description: Secrets management best practices. Environment variables, vaults, rotation.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Secrets Management

Secure handling of sensitive credentials and configuration.

## Secret Types

| Type | Examples | Storage |
|------|----------|---------|
| Authentication | API keys, OAuth secrets | Vault/env |
| Encryption | AES keys, JWT secrets | Vault |
| Infrastructure | DB passwords, SSH keys | Vault/env |
| Application | Session secrets | Env |

## Storage Hierarchy

| Environment | Approach |
|-------------|----------|
| Local dev | `.env` files (gitignored) |
| CI/CD | Pipeline secrets |
| Production | Secret manager (Vault, AWS Secrets Manager) |

## Never Do

| Anti-pattern | Risk |
|--------------|------|
| Hard-coded secrets | Exposed in source control |
| Secrets in logs | Visible to operators |
| Secrets in URLs | Visible in browser history, server logs |
| Secrets in error messages | Exposed to users |
| Shared secrets | No audit trail |

## Best Practices

| Practice | Implementation |
|----------|----------------|
| Use environment variables | `process.env.SECRET_KEY` |
| Gitignore .env files | Add `.env*` to `.gitignore` |
| Rotate regularly | 90 days or on compromise |
| Least privilege | Only grant what's needed |
| Audit access | Log who accessed secrets |

## Secret Detection

### Pre-commit checks
```
# Tools: git-secrets, detect-secrets, gitleaks
# Patterns to detect:
- API keys (32+ char strings)
- AWS keys (AKIA...)
- Private keys (-----BEGIN)
- Connection strings (://user:pass@)
```

## Environment Variables

```bash
# .env (gitignored)
DATABASE_URL=postgres://user:pass@localhost/db
JWT_SECRET=your-32-char-secret-here
API_KEY=external-service-key

# Access in code
const secret = process.env.JWT_SECRET
```

## Security Checklist

- [ ] No secrets in source code
- [ ] `.env` files in `.gitignore`
- [ ] Pre-commit hooks for secret detection
- [ ] Secrets encrypted at rest
- [ ] Regular rotation schedule
- [ ] Access audit logging
- [ ] Separate secrets per environment
- [ ] Least privilege access

## When to Load References

- **For vault setup**: See `references/vault-setup.md`
- **For rotation patterns**: See `references/rotation.md`
- **For CI/CD secrets**: See `references/cicd-secrets.md`

---

## Related Skills

- **[authentication](../authentication/SKILL.md)** - Credentials and tokens that need secure storage
- **[container-security](../container-security/SKILL.md)** - Secrets injection in container runtimes
- **[compliance](../compliance/SKILL.md)** - Regulatory requirements for key management
