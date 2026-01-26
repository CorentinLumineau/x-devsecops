---
title: ADR Template Reference
category: meta
type: reference
version: "1.0.0"
---

# ADR Template

> Part of the meta/analysis knowledge skill

## Overview

Architecture Decision Records (ADRs) document significant architectural decisions. This reference provides templates and patterns for effective ADRs.

## Quick Reference (80/20)

| Section | Purpose |
|---------|---------|
| Title | Short descriptive name |
| Status | Proposed/Accepted/Deprecated |
| Context | Why decision needed |
| Decision | What was decided |
| Consequences | Trade-offs and impacts |

## Patterns

### Pattern 1: Standard ADR Template

**When to Use**: Most architectural decisions

**Example**:
```markdown
# ADR-001: Use PostgreSQL as Primary Database

## Status

Accepted

## Date

2024-01-15

## Decision Makers

- @tech-lead
- @architect
- @backend-lead

## Context

We need to select a primary database for our new e-commerce platform. The system requirements include:

- Handle 10,000+ concurrent users
- Support complex queries for reporting
- ACID compliance for transactions
- JSON storage for product attributes
- Geographic distribution support

### Current Situation

We currently have no database infrastructure. This is a greenfield project.

### Constraints

- Team expertise primarily in relational databases
- Budget allows for managed database services
- Must support both OLTP and basic OLAP workloads

### Options Considered

1. **PostgreSQL** (managed via AWS RDS)
2. **MySQL** (managed via AWS RDS)
3. **MongoDB** (managed via Atlas)

## Decision

We will use **PostgreSQL** as our primary database, deployed on AWS RDS with Multi-AZ for high availability.

### Rationale

1. **JSON Support**: PostgreSQL's JSONB provides flexible schema for product attributes without sacrificing query performance
2. **Advanced Features**: Full-text search, window functions, and CTEs support complex reporting needs
3. **Reliability**: ACID compliance and mature replication for transaction integrity
4. **Team Expertise**: Team has strong PostgreSQL experience
5. **Ecosystem**: Excellent tooling, ORM support, and community resources

## Consequences

### Positive

- Strong consistency guarantees for financial transactions
- Flexible schema for varying product types via JSONB
- Advanced query capabilities reduce need for separate analytics database
- Large talent pool for hiring and support
- Well-documented migration paths and upgrade procedures

### Negative

- Horizontal scaling more complex than NoSQL alternatives
- Read replicas add operational complexity
- JSONB queries can be slower than native document databases
- May need to add caching layer for high-read scenarios

### Neutral

- Standard SQL learning curve for new team members
- Need to implement connection pooling (PgBouncer)
- Regular maintenance windows for updates

## Compliance

- [x] Security review completed
- [x] Performance requirements validated
- [x] Cost analysis approved

## Related Decisions

- ADR-002: Database Schema Design
- ADR-003: Caching Strategy

## References

- [PostgreSQL vs MySQL Comparison](internal-wiki/db-comparison)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2024-01-15 | Initial decision | @tech-lead |
| 2024-01-20 | Added compliance section | @architect |
```

**Anti-Pattern**: ADRs without context or consequences.

### Pattern 2: Lightweight ADR (Y-Statement)

**When to Use**: Quick decisions or smaller scope

**Example**:
```markdown
# ADR-015: Use Jest for Unit Testing

**Status**: Accepted
**Date**: 2024-01-15
**Deciders**: @frontend-lead, @backend-lead

## Decision

In the context of **selecting a testing framework**,
facing the need for **consistent testing across frontend and backend**,
we decided to use **Jest**,
to achieve **unified testing experience and reduced tooling complexity**,
accepting that **some backend-specific features may require additional configuration**.

## Context

- Need testing framework for Node.js backend and React frontend
- Team prefers single tool over multiple specialized tools
- CI/CD pipeline should run all tests uniformly

## Consequences

- Unified test syntax across codebase
- Single dependency for testing
- May need `ts-jest` for TypeScript support
- Some Express-specific testing patterns differ from React Testing Library
```

**Anti-Pattern**: Missing trade-offs in lightweight format.

### Pattern 3: ADR with Options Analysis

**When to Use**: Decisions requiring detailed comparison

**Example**:
```markdown
# ADR-008: Select API Gateway Solution

## Status

Proposed

## Context

We need an API gateway to handle:
- Request routing to microservices
- Authentication/Authorization
- Rate limiting
- Request/Response transformation
- Monitoring and logging

Traffic expectations: 50,000 requests/minute peak

## Options Analysis

### Option 1: Kong Gateway

| Criterion | Score (1-5) | Notes |
|-----------|-------------|-------|
| Performance | 5 | Proven at high scale |
| Features | 5 | Comprehensive plugin ecosystem |
| Operational Complexity | 3 | Requires PostgreSQL/Cassandra |
| Cost | 3 | Enterprise features require license |
| Team Familiarity | 2 | New to team |
| **Total** | **18** | |

**Pros**:
- Battle-tested at scale
- Extensive plugin ecosystem
- Both OSS and Enterprise options
- Active community

**Cons**:
- Database dependency adds complexity
- Enterprise features (RBAC, etc.) require paid license
- Learning curve for Lua plugins

### Option 2: AWS API Gateway

| Criterion | Score (1-5) | Notes |
|-----------|-------------|-------|
| Performance | 4 | Good, but cold starts |
| Features | 4 | Native AWS integrations |
| Operational Complexity | 5 | Fully managed |
| Cost | 3 | Can get expensive at scale |
| Team Familiarity | 4 | Team knows AWS |
| **Total** | **20** | |

**Pros**:
- Zero operational overhead
- Native integration with AWS services
- Pay-per-request pricing model
- Built-in DDoS protection

**Cons**:
- Vendor lock-in
- Limited customization
- 29-second timeout limit
- Cold starts for Lambda integrations

### Option 3: Envoy + Custom Control Plane

| Criterion | Score (1-5) | Notes |
|-----------|-------------|-------|
| Performance | 5 | Excellent |
| Features | 4 | Requires custom development |
| Operational Complexity | 2 | Significant ops burden |
| Cost | 5 | Open source |
| Team Familiarity | 1 | No experience |
| **Total** | **17** | |

**Pros**:
- Maximum flexibility
- No licensing costs
- High performance
- Istio compatibility

**Cons**:
- Requires significant custom development
- No out-of-box dashboard
- Team needs training

## Decision

**Recommended**: AWS API Gateway

### Rationale

1. **Operational Simplicity**: As a startup, we should minimize ops overhead
2. **Team Familiarity**: Existing AWS expertise reduces ramp-up time
3. **Cost Model**: Pay-per-request aligns with our variable traffic
4. **Time to Market**: Fastest to implement and iterate

### Migration Path

If we outgrow AWS API Gateway, Kong provides a clear migration path without significant architectural changes.

## Consequences

### Positive
- Immediate availability
- No infrastructure to manage
- Native CloudWatch integration

### Negative
- AWS lock-in
- Must work within 29s timeout
- Limited custom logic without Lambda

### Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Cost overruns | Medium | Medium | Implement caching, set budgets |
| Feature limitations | Low | Medium | Use Lambda for complex logic |
| Performance issues | Low | High | Load test before launch |
```

**Anti-Pattern**: Options without scoring criteria.

### Pattern 4: MADR Format

**When to Use**: Standardized team format

**Example**:
```markdown
---
status: accepted
date: 2024-01-15
deciders: tech-lead, backend-lead, devops-lead
consulted: security-team, dba
informed: engineering-team
---

# Use Event Sourcing for Order Management

## Context and Problem Statement

How should we persist order state in a way that provides complete audit history, supports temporal queries, and enables event-driven integrations?

## Decision Drivers

* Complete audit trail required for compliance
* Need to integrate with downstream systems via events
* Support for "as-of" queries for dispute resolution
* High write throughput expected (1000+ orders/minute)

## Considered Options

* Traditional CRUD with Audit Log
* Event Sourcing with CQRS
* Change Data Capture (CDC)

## Decision Outcome

Chosen option: "Event Sourcing with CQRS", because it provides built-in audit trail, natural event integration, and temporal query support without additional components.

### Consequences

* Good, because complete history stored by default
* Good, because events can be replayed for debugging
* Good, because natural fit for event-driven architecture
* Bad, because increased complexity for simple queries
* Bad, because eventual consistency requires careful handling
* Bad, because steeper learning curve for team

### Confirmation

We will validate this decision through:
1. Proof of concept with order lifecycle
2. Performance testing at 2x expected load
3. Team training completion

## Pros and Cons of the Options

### Traditional CRUD with Audit Log

* Good, because simple and familiar
* Good, because immediate consistency
* Bad, because separate audit implementation needed
* Bad, because no built-in temporal queries
* Bad, because events must be separately generated

### Event Sourcing with CQRS

* Good, because events are first-class citizens
* Good, because temporal queries built-in
* Good, because audit trail automatic
* Neutral, because more infrastructure (event store, projections)
* Bad, because eventual consistency complexity
* Bad, because learning curve

### Change Data Capture (CDC)

* Good, because works with existing CRUD patterns
* Good, because events generated from DB changes
* Neutral, because requires CDC tooling (Debezium)
* Bad, because events are derived, not primary
* Bad, because schema changes can break consumers
* Bad, because no built-in temporal queries

## More Information

- [Event Sourcing Pattern](https://martinfowler.com/eaaDev/EventSourcing.html)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
- Internal RFC: Event-Driven Architecture Strategy
```

**Anti-Pattern**: Missing "decision drivers" section.

### Pattern 5: ADR Repository Organization

**When to Use**: Managing multiple ADRs

**Example**:
```
docs/
├── architecture/
│   ├── decisions/
│   │   ├── README.md              # Index and process
│   │   ├── template.md            # ADR template
│   │   ├── 0001-record-architecture-decisions.md
│   │   ├── 0002-use-postgresql.md
│   │   ├── 0003-adopt-microservices.md
│   │   ├── 0004-use-kubernetes.md
│   │   └── ...
│   └── diagrams/
│       └── ...
└── ...
```

```markdown
<!-- docs/architecture/decisions/README.md -->
# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the project.

## What is an ADR?

An ADR is a document that captures an important architectural decision made along with its context and consequences.

## ADR Status

| ID | Title | Status | Date |
|----|-------|--------|------|
| [ADR-0001](0001-record-architecture-decisions.md) | Record Architecture Decisions | Accepted | 2024-01-01 |
| [ADR-0002](0002-use-postgresql.md) | Use PostgreSQL | Accepted | 2024-01-05 |
| [ADR-0003](0003-adopt-microservices.md) | Adopt Microservices | Accepted | 2024-01-10 |
| [ADR-0004](0004-use-kubernetes.md) | Use Kubernetes | Proposed | 2024-01-15 |
| [ADR-0005](0005-authentication-strategy.md) | Authentication Strategy | Superseded | 2024-01-08 |

## Process

1. **Propose**: Create new ADR using template
2. **Review**: Submit PR for team review
3. **Decide**: Reach consensus or escalate
4. **Accept**: Merge and implement
5. **Update**: Mark as superseded if replaced

## Creating a New ADR

```bash
# Use the adr-tools CLI
adr new "Use Redis for Caching"

# Or manually
cp template.md 0006-use-redis-for-caching.md
```

## Statuses

- **Proposed**: Under discussion
- **Accepted**: Approved and implemented
- **Deprecated**: No longer recommended
- **Superseded**: Replaced by another ADR

## Links

- [ADR GitHub Organization](https://adr.github.io/)
- [Internal Architecture Guidelines](../guidelines.md)
```

```typescript
// adr-cli.ts - Custom ADR tooling
import * as fs from 'fs';
import * as path from 'path';

interface ADRMetadata {
  id: number;
  title: string;
  status: 'proposed' | 'accepted' | 'deprecated' | 'superseded';
  date: string;
  file: string;
}

class ADRManager {
  private adrDir: string;

  constructor(adrDir: string = 'docs/architecture/decisions') {
    this.adrDir = adrDir;
  }

  async create(title: string): Promise<string> {
    const nextId = await this.getNextId();
    const filename = this.generateFilename(nextId, title);
    const content = this.generateContent(nextId, title);

    const filePath = path.join(this.adrDir, filename);
    await fs.promises.writeFile(filePath, content);

    console.log(`Created: ${filePath}`);
    return filePath;
  }

  async list(): Promise<ADRMetadata[]> {
    const files = await fs.promises.readdir(this.adrDir);
    const adrs: ADRMetadata[] = [];

    for (const file of files) {
      if (file.match(/^\d{4}-.*\.md$/)) {
        const content = await fs.promises.readFile(
          path.join(this.adrDir, file),
          'utf-8'
        );
        const metadata = this.parseMetadata(file, content);
        if (metadata) {
          adrs.push(metadata);
        }
      }
    }

    return adrs.sort((a, b) => a.id - b.id);
  }

  async updateStatus(id: number, status: ADRMetadata['status']): Promise<void> {
    const adrs = await this.list();
    const adr = adrs.find(a => a.id === id);

    if (!adr) {
      throw new Error(`ADR ${id} not found`);
    }

    const filePath = path.join(this.adrDir, adr.file);
    let content = await fs.promises.readFile(filePath, 'utf-8');

    content = content.replace(
      /## Status\n\n\w+/,
      `## Status\n\n${this.capitalizeFirst(status)}`
    );

    await fs.promises.writeFile(filePath, content);
    console.log(`Updated ${adr.file} status to ${status}`);
  }

  async supersede(oldId: number, newId: number): Promise<void> {
    await this.updateStatus(oldId, 'superseded');

    const adrs = await this.list();
    const oldAdr = adrs.find(a => a.id === oldId);
    const newAdr = adrs.find(a => a.id === newId);

    if (oldAdr && newAdr) {
      const oldPath = path.join(this.adrDir, oldAdr.file);
      let content = await fs.promises.readFile(oldPath, 'utf-8');

      content = content.replace(
        /## Status\n\nSuperseded/,
        `## Status\n\nSuperseded by [ADR-${String(newId).padStart(4, '0')}](${newAdr.file})`
      );

      await fs.promises.writeFile(oldPath, content);
    }
  }

  async generateIndex(): Promise<void> {
    const adrs = await this.list();

    const table = adrs.map(adr =>
      `| [ADR-${String(adr.id).padStart(4, '0')}](${adr.file}) | ${adr.title} | ${this.capitalizeFirst(adr.status)} | ${adr.date} |`
    ).join('\n');

    const index = `# Architecture Decision Records

## Index

| ID | Title | Status | Date |
|----|-------|--------|------|
${table}

## Statistics

- Total ADRs: ${adrs.length}
- Accepted: ${adrs.filter(a => a.status === 'accepted').length}
- Proposed: ${adrs.filter(a => a.status === 'proposed').length}
- Deprecated: ${adrs.filter(a => a.status === 'deprecated').length}
- Superseded: ${adrs.filter(a => a.status === 'superseded').length}

Last updated: ${new Date().toISOString().split('T')[0]}
`;

    await fs.promises.writeFile(
      path.join(this.adrDir, 'README.md'),
      index
    );
    console.log('Updated README.md');
  }

  private async getNextId(): Promise<number> {
    const adrs = await this.list();
    if (adrs.length === 0) return 1;
    return Math.max(...adrs.map(a => a.id)) + 1;
  }

  private generateFilename(id: number, title: string): string {
    const slug = title
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
    return `${String(id).padStart(4, '0')}-${slug}.md`;
  }

  private generateContent(id: number, title: string): string {
    return `# ADR-${String(id).padStart(4, '0')}: ${title}

## Status

Proposed

## Date

${new Date().toISOString().split('T')[0]}

## Decision Makers

- @author

## Context

[Describe the context and problem statement]

## Decision

[Describe the decision and rationale]

## Consequences

### Positive

- [List positive consequences]

### Negative

- [List negative consequences]

## References

- [Add relevant links]
`;
  }

  private parseMetadata(filename: string, content: string): ADRMetadata | null {
    const idMatch = filename.match(/^(\d{4})/);
    const titleMatch = content.match(/^# ADR-\d+: (.+)$/m);
    const statusMatch = content.match(/## Status\n\n(\w+)/);
    const dateMatch = content.match(/## Date\n\n(\d{4}-\d{2}-\d{2})/);

    if (!idMatch || !titleMatch) return null;

    return {
      id: parseInt(idMatch[1], 10),
      title: titleMatch[1],
      status: (statusMatch?.[1]?.toLowerCase() as ADRMetadata['status']) ?? 'proposed',
      date: dateMatch?.[1] ?? 'Unknown',
      file: filename
    };
  }

  private capitalizeFirst(str: string): string {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }
}

// CLI usage
const manager = new ADRManager();

const command = process.argv[2];
const args = process.argv.slice(3);

switch (command) {
  case 'new':
    manager.create(args.join(' '));
    break;
  case 'list':
    manager.list().then(console.table);
    break;
  case 'status':
    manager.updateStatus(parseInt(args[0]), args[1] as any);
    break;
  case 'supersede':
    manager.supersede(parseInt(args[0]), parseInt(args[1]));
    break;
  case 'index':
    manager.generateIndex();
    break;
  default:
    console.log('Usage: adr [new|list|status|supersede|index]');
}
```

**Anti-Pattern**: ADRs without index or navigation.

## Checklist

- [ ] Clear problem statement in context
- [ ] Options considered documented
- [ ] Decision rationale explained
- [ ] Positive consequences listed
- [ ] Negative consequences listed
- [ ] Status clearly marked
- [ ] Date recorded
- [ ] Decision makers identified
- [ ] Related ADRs linked
- [ ] ADR indexed and discoverable

## References

- [ADR GitHub Organization](https://adr.github.io/)
- [Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [MADR Template](https://adr.github.io/madr/)
- [ADR Tools](https://github.com/npryce/adr-tools)
