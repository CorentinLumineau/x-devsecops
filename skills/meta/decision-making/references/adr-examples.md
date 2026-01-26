---
title: ADR Examples
category: meta
type: reference
version: 1.0.0
---

# ADR Examples

## Overview

Real-world Architecture Decision Records demonstrating effective documentation patterns for common technical decisions. These examples serve as templates for documenting database choices, API design patterns, authentication strategies, and infrastructure decisions.

## 80/20 Quick Reference

| Decision Type | Key Sections | Common Drivers |
|---------------|--------------|----------------|
| Database Selection | Performance, scalability, consistency | Query patterns, team expertise, cost |
| API Design | Contract stability, versioning | Consumer needs, evolution strategy |
| Authentication | Security requirements, UX | Compliance, integration needs |
| Infrastructure | Availability, cost, operations | Scale, team capacity, vendor lock-in |
| Framework Selection | Productivity, ecosystem | Team skills, long-term support |

## Database Selection ADR

### When to Use
Document decisions about primary datastores, caching layers, or specialized databases with clear performance and consistency requirements.

### Example

```markdown
# ADR-001: PostgreSQL as Primary Database

## Status
Accepted

## Date
2024-01-15

## Context
We need to select a primary database for our order management system.
The system will handle:
- 10,000 orders per day initially, scaling to 100,000
- Complex queries joining orders, customers, products, and inventory
- Strong consistency requirements for financial transactions
- Geographically distributed read replicas

Current team has experience with:
- PostgreSQL (5 developers, 3+ years each)
- MySQL (2 developers, 2+ years)
- MongoDB (1 developer, 1 year)

## Decision Drivers
- **DD1**: ACID compliance for financial transactions (must-have)
- **DD2**: Complex query support (must-have)
- **DD3**: Team expertise (important)
- **DD4**: Operational tooling maturity (important)
- **DD5**: Cloud provider support (nice-to-have)

## Considered Options

### Option 1: PostgreSQL
**Pros:**
- Full ACID compliance with serializable isolation
- Excellent JSON support for semi-structured data
- Strong team expertise reduces ramp-up time
- Mature replication and failover tooling
- All major cloud providers offer managed services

**Cons:**
- Write scaling requires manual sharding
- Connection pooling needed at scale

### Option 2: MySQL (Aurora)
**Pros:**
- Good cloud-native scaling with Aurora
- Lower operational overhead with managed service
- Good ACID compliance

**Cons:**
- Limited team expertise
- JSON support less mature than PostgreSQL
- Some MySQL-specific behaviors require learning curve

### Option 3: MongoDB
**Pros:**
- Horizontal scaling built-in
- Flexible schema for rapid iteration

**Cons:**
- Limited ACID support (improved in 4.0+ but not full)
- Complex queries require aggregation pipelines
- Minimal team expertise
- Financial compliance concerns

## Decision
We will use **PostgreSQL** as our primary database.

## Rationale
1. **Financial transactions require ACID** - PostgreSQL's serializable isolation
   meets our compliance requirements
2. **Team expertise** - 5 developers with deep PostgreSQL knowledge reduces
   risk and accelerates delivery
3. **Query complexity** - Native SQL with window functions, CTEs, and JOINs
   matches our reporting needs
4. **Operational maturity** - pgBouncer, pg_stat_statements, and logical
   replication are well-understood

## Consequences

### Positive
- Immediate productivity from day one
- Proven patterns for financial applications
- Rich ecosystem of monitoring tools

### Negative
- Must implement connection pooling early (pgBouncer)
- Write scaling will require application-level sharding at ~50K TPS
- Team must learn streaming replication for read replicas

### Neutral
- Will use AWS RDS PostgreSQL for managed operations
- Schema migrations require careful planning due to locking

## Compliance
- SOC 2 Type II: PostgreSQL's audit logging meets requirements
- PCI DSS: Encryption at rest and in transit supported natively

## Related Decisions
- ADR-002: Connection pooling strategy
- ADR-003: Read replica architecture
```

### Anti-Patterns
- Choosing technology without documenting trade-offs
- Omitting team expertise as a decision driver
- Not specifying concrete scale requirements

---

## API Versioning ADR

### When to Use
Document API evolution strategy when building public or internal APIs with multiple consumers.

### Example

```markdown
# ADR-002: URL-Based API Versioning

## Status
Accepted

## Date
2024-02-01

## Context
Our public API serves 50+ third-party integrations. We need a versioning
strategy that:
- Allows breaking changes without disrupting existing integrations
- Provides clear deprecation timeline
- Minimizes maintenance burden

API characteristics:
- RESTful design with JSON payloads
- ~200 endpoints across 15 domains
- Average consumer maintains integration for 3+ years
- 2 major releases planned per year

## Decision Drivers
- **DD1**: Consumer clarity on version compatibility
- **DD2**: Ease of routing in infrastructure
- **DD3**: Documentation clarity
- **DD4**: Backward compatibility guarantees

## Considered Options

### Option 1: URL Path Versioning
`GET /v1/orders/{id}`

**Pros:**
- Immediately visible in requests and logs
- Simple routing with standard infrastructure
- Clear cache separation by version
- Easy to document and understand

**Cons:**
- Can lead to URL pollution
- May tempt over-versioning

### Option 2: Header Versioning
`GET /orders/{id}` with `Accept: application/vnd.company.v1+json`

**Pros:**
- Clean URLs
- Follows HTTP content negotiation standards
- Single URL for all versions

**Cons:**
- Hidden from casual inspection
- Complex routing configuration
- Caching requires Vary header handling
- Harder to test in browser

### Option 3: Query Parameter Versioning
`GET /orders/{id}?version=1`

**Pros:**
- Visible in URLs
- Easy to switch versions

**Cons:**
- Can be accidentally omitted
- Mixes versioning with business parameters
- Cache key complexity

## Decision
We will use **URL path versioning** with the format `/v{major}/resource`.

## Versioning Policy
- **Major version bump**: Breaking changes (removed fields, changed types)
- **No version bump**: Additive changes (new fields, new endpoints)
- **Support window**: 18 months after deprecation announcement
- **Maximum concurrent versions**: 2 (current + previous)

## Migration Support
```yaml
# Response header for deprecated versions
X-API-Deprecation: sunset=2025-06-01
X-API-Upgrade-Path: /v2/orders

# Automatic redirect option (opt-in)
X-API-Auto-Upgrade: true
```

## Consequences

### Positive
- Clear version identification in all tooling
- Simple nginx/ingress routing rules
- Straightforward SDK generation

### Negative
- Must maintain parallel implementations during transition
- URL changes require consumer updates

### Operational
- Version-specific rate limits possible
- Per-version metrics dashboards required

## Implementation
```nginx
# nginx routing
location ~ ^/v(?<version>\d+)/ {
    proxy_pass http://api-v$version;
    proxy_set_header X-API-Version $version;
}
```

## Related Decisions
- ADR-005: API deprecation communication process
- ADR-006: SDK versioning alignment
```

### Anti-Patterns
- Versioning every minor change
- No defined support window for old versions
- Mixing versioning strategies across APIs

---

## Authentication Strategy ADR

### When to Use
Document authentication mechanism selection balancing security requirements, user experience, and integration complexity.

### Example

```markdown
# ADR-003: OAuth 2.0 with PKCE for Authentication

## Status
Accepted

## Date
2024-02-15

## Context
We're building a customer portal with:
- Web application (React SPA)
- Mobile applications (iOS, Android)
- CLI tool for developers
- B2B integrations requiring API access

Security requirements:
- No passwords stored in our systems
- MFA support required
- Session management with secure token refresh
- Compliance: SOC 2, GDPR

## Decision Drivers
- **DD1**: Security best practices (OWASP guidelines)
- **DD2**: Support for all client types (SPA, mobile, CLI, M2M)
- **DD3**: Industry standard for B2B integrations
- **DD4**: Leverage existing identity provider

## Considered Options

### Option 1: OAuth 2.0 + OIDC with PKCE
**Pros:**
- Industry standard, well-documented
- PKCE secures public clients (SPA, mobile)
- Delegate identity management to IdP
- Standard token refresh flow
- B2B partners familiar with OAuth

**Cons:**
- Complex initial setup
- Requires identity provider selection
- Token management complexity

### Option 2: Session-based with Cookies
**Pros:**
- Simple implementation
- Built-in browser support

**Cons:**
- Doesn't work for mobile/CLI
- CSRF vulnerabilities
- Scaling session storage
- Not suitable for B2B API access

### Option 3: Custom JWT Implementation
**Pros:**
- Full control over token structure
- Simpler than full OAuth

**Cons:**
- Must implement security features manually
- No standard for third-party integrations
- Reinventing the wheel

## Decision
We will implement **OAuth 2.0 with OpenID Connect** using:
- **Authorization Code + PKCE** for web and mobile apps
- **Client Credentials** for machine-to-machine (B2B)
- **Device Authorization** for CLI tools

## Identity Provider
Auth0 selected based on:
- Managed service reduces operational burden
- Built-in MFA, SSO, social connections
- Enterprise connections for B2B (SAML, OIDC)
- Compliance certifications included

## Token Strategy
```yaml
tokens:
  access_token:
    type: JWT
    lifetime: 15 minutes
    audience: api.company.com

  refresh_token:
    type: opaque
    lifetime: 7 days
    rotation: true  # New refresh token each use

  id_token:
    type: JWT
    lifetime: 1 hour
    claims: [sub, email, name, picture]
```

## Flow Selection by Client
| Client Type | Flow | Token Storage |
|-------------|------|---------------|
| Web SPA | Auth Code + PKCE | Memory only |
| Mobile | Auth Code + PKCE | Secure enclave |
| CLI | Device Auth | OS keychain |
| B2B Server | Client Credentials | HSM/Vault |

## Consequences

### Positive
- Centralized identity management
- Standards compliance simplifies audits
- SSO capability for enterprise customers
- No password storage liability

### Negative
- Auth0 vendor dependency
- Complex debugging for token issues
- Additional latency for token validation

### Security Controls
- Refresh token rotation prevents replay
- Short-lived access tokens limit exposure
- PKCE prevents authorization code interception

## Implementation Notes
```typescript
// Token validation middleware
const validateToken = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];

  try {
    const decoded = await auth0.verifyAccessToken(token, {
      audience: 'api.company.com',
      issuer: 'https://company.auth0.com/'
    });
    req.user = decoded;
    next();
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
};
```

## Related Decisions
- ADR-007: Session timeout and re-authentication
- ADR-008: B2B API key management
```

### Anti-Patterns
- Using implicit flow for SPAs (deprecated)
- Storing tokens in localStorage
- Not implementing token refresh

---

## Microservices Communication ADR

### When to Use
Document inter-service communication patterns when decomposing monoliths or designing distributed systems.

### Example

```markdown
# ADR-004: Event-Driven Communication with Kafka

## Status
Accepted

## Date
2024-03-01

## Context
Migrating from monolith to microservices architecture. Need to establish
communication patterns between:
- 12 planned services
- Mix of synchronous (user-facing) and asynchronous (processing) needs
- Event sourcing for audit trail
- Cross-service transactions

Current challenges:
- Tight coupling through shared database
- Cascading failures from synchronous calls
- No audit trail for state changes

## Decision
We will adopt an **event-driven architecture** using Apache Kafka with:
- **Synchronous**: REST/gRPC for query operations
- **Asynchronous**: Events via Kafka for commands and state changes

## Event Strategy
```yaml
event_patterns:
  domain_events:
    purpose: Notify state changes
    example: OrderPlaced, PaymentReceived
    retention: 7 days

  integration_events:
    purpose: Cross-domain communication
    example: InventoryReserved, ShippingScheduled
    retention: 30 days

  commands:
    purpose: Request action from another service
    example: ReserveInventory, ProcessPayment
    pattern: Request-reply with correlation ID
```

## Topic Naming Convention
```
{domain}.{entity}.{event-type}
# Examples:
orders.order.created
orders.order.status-changed
payments.payment.completed
inventory.stock.reserved
```

## Consequences

### Positive
- Loose coupling between services
- Built-in audit log via event store
- Replay capability for debugging
- Natural scaling through partitioning

### Negative
- Eventual consistency complexity
- Event schema evolution challenges
- Debugging distributed transactions
- Kafka operational overhead

## Schema Management
- Confluent Schema Registry for Avro schemas
- Backward compatible evolution only
- Schema validation at producer

## Related Decisions
- ADR-009: Saga pattern for distributed transactions
- ADR-010: Event schema versioning strategy
```

### Anti-Patterns
- Events with business logic (events should be facts)
- Synchronous patterns disguised as events
- No schema registry

---

## Cloud Provider ADR

### When to Use
Document cloud provider selection for greenfield projects or migrations with significant infrastructure implications.

### Example

```markdown
# ADR-005: AWS as Primary Cloud Provider

## Status
Accepted

## Date
2024-03-15

## Context
Selecting cloud provider for new SaaS platform. Requirements:
- Multi-region deployment (US, EU, APAC)
- Kubernetes workloads
- Managed databases
- ML/AI services for recommendations
- Budget: $50K-100K/month at scale

Team capabilities:
- 3 engineers with AWS certifications
- 1 engineer with GCP experience
- Existing CI/CD on GitHub Actions

## Decision
We will use **AWS** as primary cloud provider with multi-region deployment.

## Service Selection
| Need | AWS Service | Rationale |
|------|-------------|-----------|
| Kubernetes | EKS | Managed control plane, Fargate option |
| Database | RDS PostgreSQL | Familiar, multi-AZ, read replicas |
| Cache | ElastiCache Redis | Managed Redis cluster |
| Object Storage | S3 | Industry standard, cross-region replication |
| CDN | CloudFront | Integrated with S3, edge locations |
| ML | SageMaker | Managed training and inference |

## Multi-Cloud Considerations
- Terraform for infrastructure (provider-agnostic where possible)
- Kubernetes for workloads (portable)
- S3-compatible APIs used (MinIO fallback option)

## Consequences

### Positive
- Immediate team productivity
- Mature service ecosystem
- Strong enterprise compliance (FedRAMP, HIPAA)
- Extensive documentation and support

### Negative
- Vendor lock-in for AWS-specific services
- Complex pricing model
- Regional service availability varies

### Cost Controls
- Reserved instances for baseline
- Spot instances for batch workloads
- S3 intelligent tiering
- Monthly cost reviews

## Exit Strategy
If migration needed:
1. Kubernetes workloads portable to any cloud
2. PostgreSQL runs anywhere
3. S3 objects exportable to any storage
4. Terraform abstracts 80% of infrastructure

## Related Decisions
- ADR-011: Kubernetes cluster architecture
- ADR-012: Disaster recovery strategy
```

### Anti-Patterns
- No exit strategy consideration
- Ignoring team expertise in decision
- Not documenting cost projections

---

## Checklist

### Before Writing ADR
- [ ] Problem clearly identified
- [ ] Stakeholders consulted
- [ ] Options researched thoroughly
- [ ] Decision drivers prioritized
- [ ] Trade-offs understood

### ADR Content Quality
- [ ] Context explains why decision needed
- [ ] At least 3 options considered
- [ ] Clear rationale for chosen option
- [ ] Consequences documented (positive and negative)
- [ ] Related decisions linked

### After ADR Approval
- [ ] ADR added to repository
- [ ] Team notified of decision
- [ ] Implementation plan created
- [ ] Metrics defined for validation

---

## References

- ADR GitHub Organization: https://adr.github.io/
- MADR Template: https://github.com/adr/madr
- Documenting Architecture Decisions (Nygard): https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
- ADR Tools: https://github.com/npryce/adr-tools
