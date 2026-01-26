---
name: supply-chain
description: |
  Software supply chain security. Dependency scanning, SBOM, build security.
  Activate when managing dependencies, configuring CI/CD, or reviewing third-party code.
  Triggers: supply chain, dependency, npm audit, sbom, slsa, dependabot, snyk.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Supply Chain Security

Secure the software supply chain from source to deployment.

## Attack Vectors

| Vector | Example | Mitigation |
|--------|---------|------------|
| Dependency confusion | Malicious package with same name | Lock files, private registries |
| Typosquatting | `lodsh` instead of `lodash` | Verify package names |
| Compromised maintainer | Malicious update | Pin versions, audit updates |
| Build tampering | CI/CD compromise | Signed builds, SLSA |
| Insider threat | Malicious contributor | Code review, 2-person rule |

## Dependency Management

| Practice | Implementation |
|----------|----------------|
| Lock files | `package-lock.json`, `yarn.lock` |
| Version pinning | Exact versions, not ranges |
| Regular audits | `npm audit`, `snyk test` |
| Minimal dependencies | Evaluate necessity |
| License compliance | Check for GPL, AGPL risks |

## Scanning Tools

| Tool | Purpose | Integration |
|------|---------|-------------|
| npm audit | Node.js vulnerabilities | CLI, CI |
| Snyk | Multi-language scanning | CI/CD, IDE |
| Dependabot | Auto-update PRs | GitHub |
| Trivy | Container + deps | CI/CD |
| OWASP Dependency-Check | Java, .NET | CI/CD |

## SLSA Framework

| Level | Requirements |
|-------|--------------|
| L1 | Documented build process |
| L2 | Tamper resistance, automated build |
| L3 | Hardened build platform |
| L4 | Two-person review, hermetic builds |

## SBOM (Software Bill of Materials)

**Formats**: SPDX, CycloneDX

```bash
# Generate SBOM
npx @cyclonedx/bom -o sbom.json
syft packages . -o cyclonedx-json

# Scan SBOM for vulnerabilities
grype sbom:./sbom.json
```

## CI/CD Security

| Control | Purpose |
|---------|---------|
| Signed commits | Verify author identity |
| Branch protection | Require reviews |
| Secret scanning | Prevent credential leaks |
| Build reproducibility | Verify integrity |
| Artifact signing | Verify authenticity |

## Security Checklist

- [ ] Lock files committed and enforced
- [ ] Automated dependency scanning in CI
- [ ] Dependabot or Renovate enabled
- [ ] Critical/high vulnerabilities blocked
- [ ] SBOM generated for releases
- [ ] Signed commits required
- [ ] Branch protection rules enabled
- [ ] Build artifacts signed
- [ ] Regular dependency updates

## When to Load References

- **For SLSA implementation**: See `references/slsa-levels.md`
- **For scanning setup**: See `references/dependency-scanning.md`
- **For SBOM generation**: See `references/sbom-guide.md`
