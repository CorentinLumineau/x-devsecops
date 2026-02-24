---
name: secrets-supply-chain
description: Use when managing secrets, securing the software supply chain, or hardening containers. Covers secrets rotation, dependency scanning, and container security.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Secrets & Supply Chain Security

Secrets management, software supply chain security, and container hardening practices.

<hook-trigger event="PreToolUse" tool="Bash" condition="Before dependency install or build commands">
  <action>Run supply chain validation: verify lock files are committed, scan dependencies for known vulnerabilities (npm audit/snyk), and check for credential patterns in staged files</action>
</hook-trigger>

## 80/20 Focus

Master these areas for 80% of infrastructure security:

| Area | Impact | Key Controls |
|------|--------|-------------|
| Secrets management | Prevents credential exposure | Vault, env vars, rotation, pre-commit hooks |
| Dependency scanning | Blocks vulnerable components | `npm audit`, Snyk, Dependabot |
| Container hardening | Reduces attack surface | Minimal base, non-root, multi-stage builds |

## Secrets Management

### Secret Types

| Type | Examples | Storage |
|------|----------|---------|
| Authentication | API keys, OAuth secrets | Vault/env |
| Encryption | AES keys, JWT secrets | Vault |
| Infrastructure | DB passwords, SSH keys | Vault/env |
| Application | Session secrets | Env |

### Storage Hierarchy

| Environment | Approach |
|-------------|----------|
| Local dev | `.env` files (gitignored) |
| CI/CD | Pipeline secrets (GitHub Actions, GitLab CI) |
| Production | Secret manager (Vault, AWS Secrets Manager) |

### Anti-Patterns

| Anti-pattern | Risk |
|--------------|------|
| Hard-coded secrets | Exposed in source control |
| Secrets in logs | Visible to operators |
| Secrets in URLs | Visible in browser history, server logs |
| Secrets in error messages | Exposed to users |
| Shared secrets | No audit trail |

### Secret Detection

Pre-commit tools: git-secrets, detect-secrets, gitleaks

Patterns to detect:
- API keys (32+ char strings)
- AWS keys (`AKIA...`)
- Private keys (`-----BEGIN`)
- Connection strings (`://user:pass@`)

### Credential Placeholders

```
API keys:     <API_KEY>, ${API_KEY}, your-api-key-here
Passwords:    <PASSWORD>, ${DB_PASSWORD}
Tokens:       <TOKEN>, ${AUTH_TOKEN}
Secrets:      <SECRET>, ${SECRET_KEY}
```

## Supply Chain Security

### Attack Vectors

| Vector | Example | Mitigation |
|--------|---------|------------|
| Dependency confusion | Malicious package with same name | Lock files, private registries |
| Typosquatting | `lodsh` instead of `lodash` | Verify package names |
| Compromised maintainer | Malicious update | Pin versions, audit updates |
| Build tampering | CI/CD compromise | Signed builds, SLSA |
| Insider threat | Malicious contributor | Code review, 2-person rule |

### Dependency Management

| Practice | Implementation |
|----------|----------------|
| Lock files | `package-lock.json`, `yarn.lock` |
| Version pinning | Exact versions, not ranges |
| Regular audits | `npm audit`, `snyk test` |
| Minimal dependencies | Evaluate necessity before adding |
| License compliance | Check for GPL, AGPL risks |

### Scanning Tools

| Tool | Purpose | Integration |
|------|---------|-------------|
| npm audit | Node.js vulnerabilities | CLI, CI |
| Snyk | Multi-language scanning | CI/CD, IDE |
| Dependabot | Auto-update PRs | GitHub |
| Trivy | Container + deps | CI/CD |
| OWASP Dependency-Check | Java, .NET | CI/CD |

### SLSA Framework

| Level | Requirements |
|-------|--------------|
| L1 | Documented build process |
| L2 | Tamper resistance, automated build |
| L3 | Hardened build platform |
| L4 | Two-person review, hermetic builds |

### SBOM (Software Bill of Materials)

Formats: SPDX, CycloneDX

```bash
# Generate SBOM
npx @cyclonedx/bom -o sbom.json
syft packages . -o cyclonedx-json

# Scan SBOM for vulnerabilities
grype sbom:./sbom.json
```

## Container Security

> See [references/container-security.md](references/container-security.md) for image security practices, Dockerfile patterns, runtime controls, and scanning tools.

## Security Checklist

### Secrets
- [ ] No secrets in source code
- [ ] `.env` files in `.gitignore`
- [ ] Pre-commit hooks for secret detection
- [ ] Secrets encrypted at rest
- [ ] Regular rotation schedule (90 days or on compromise)
- [ ] Access audit logging
- [ ] Separate secrets per environment

### Supply Chain
- [ ] Lock files committed and enforced
- [ ] Automated dependency scanning in CI
- [ ] Dependabot or Renovate enabled
- [ ] Critical/high vulnerabilities blocked in CI
- [ ] SBOM generated for releases
- [ ] Signed commits required
- [ ] Build artifacts signed

### Container Security
- [ ] Minimal base image (Alpine or distroless)
- [ ] Non-root user configured
- [ ] No secrets in image layers
- [ ] Dependencies pinned to specific versions
- [ ] Multi-stage build for smaller attack surface
- [ ] Vulnerability scanning in CI/CD
- [ ] Read-only filesystem where possible
- [ ] Resource limits configured

## When to Load References

- **For vault setup**: See `references/vault-setup.md`
- **For rotation patterns**: See `references/rotation.md`
- **For CI/CD secrets**: See `references/cicd-secrets.md`
- **For SLSA implementation**: See `references/slsa-levels.md`
- **For scanning setup**: See `references/dependency-scanning.md`
- **For SBOM generation**: See `references/sbom-guide.md`
- **For container security**: See `references/container-security.md`
- **For Kubernetes security**: See `references/k8s-security.md`
- **For container scanning**: See `references/container-scanning.md`
- **For runtime policies**: See `references/runtime-policies.md`

---

## Related Skills

- **[secure-coding](../secure-coding/SKILL.md)** - OWASP Top 10, input validation, and API security
- **[identity-access](../identity-access/SKILL.md)** - Authentication, authorization, and compliance
