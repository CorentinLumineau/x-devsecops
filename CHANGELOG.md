# Changelog

All notable changes to x-devsecops will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [0.2.1] - 2026-01-29

### Changed
- **DRY consolidation**: SQL injection patterns now reference authoritative source in input-validation skill
- **DRY consolidation**: JWT patterns now reference authoritative source in authentication skill

### Fixed
- Reduced duplication between OWASP injection-prevention and input-validation/sql-injection
- Reduced duplication between api-security/api-auth-patterns and authentication/jwt-patterns

---

## [0.2.0] - 2026-01-28

### Added
- 4 new knowledge skills
- validate-rules.sh script for rules directory validation
- Modular `.claude/rules/` directory structure
- 3-repo Swiss Watch design reference documentation

---

## [0.1.0] - 2026-01-26

### Added
- **26 DevSecOps knowledge skills** covering:
  - Security (OWASP, authentication, authorization, secrets, container security, supply chain, input validation, compliance)
  - Quality (testing, debugging, performance, quality gates)
  - Code (design patterns, code quality, error handling, API design, LLM optimization)
  - Delivery (CI/CD, feature flags, release management, infrastructure)
  - Operations (monitoring, incident response)
  - Meta (analysis, decision making)
  - Data (database design)
- Detailed reference documentation for all skills

---

[Unreleased]: https://github.com/CorentinLumineau/x-devsecops/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/CorentinLumineau/x-devsecops/releases/tag/v0.1.0
