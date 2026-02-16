---
title: RFC Process
category: meta
type: reference
version: 1.0.0
---

# RFC Process

## Overview

Request for Comments (RFC) process for proposing and reviewing significant technical changes. RFCs facilitate asynchronous collaboration, capture institutional knowledge, and ensure thorough consideration of cross-cutting concerns before implementation.

## 80/20 Quick Reference

| Aspect | Essential Element | Purpose |
|--------|-------------------|---------|
| Threshold | >2 weeks work OR cross-team impact | Filter for significant changes |
| Timeline | 1 week draft, 2 weeks review, 1 week final | Balanced feedback cycle |
| Sections | Problem, Proposal, Alternatives, Risks | Complete picture |
| Approval | 2+ reviewers, no blocking concerns | Consensus building |
| States | Draft, Review, Approved, Implemented, Superseded | Clear lifecycle |

## RFC Template

### When to Use
Standard template for proposing significant technical changes that require team input and formal approval.

### Example

```markdown
# RFC-0042: Introduce GraphQL for Mobile API

**Author:** Jane Developer
**Status:** Draft
**Created:** 2024-03-01
**Last Updated:** 2024-03-05

## Summary

One paragraph description of the proposal.

Introduce GraphQL as the API layer for mobile applications to reduce
over-fetching, enable client-driven queries, and improve mobile app
performance on low-bandwidth connections.

## Motivation

Why are we doing this? What problem does it solve?

### Current Problems
1. Mobile apps fetch 3-5 REST endpoints per screen, causing:
   - Increased latency (sequential requests)
   - Over-fetching (unused fields transferred)
   - Under-fetching (multiple round trips)

2. API versioning friction:
   - Breaking changes require mobile app updates
   - App store review delays propagate to backend releases

3. Documentation drift:
   - OpenAPI specs out of sync with implementation
   - Mobile team discovers API changes in production

### Success Metrics
- Reduce average API calls per screen from 4 to 1
- Decrease mobile data transfer by 40%
- Eliminate API-related mobile app crashes

## Detailed Design

Technical details of the implementation.

### Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Mobile App  │────▶│   GraphQL    │────▶│   Services   │
│              │◀────│   Gateway    │◀────│  (existing)  │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                     ┌──────┴──────┐
                     │   Schema    │
                     │  Registry   │
                     └─────────────┘
```

### Schema Design
```graphql
type Query {
  user(id: ID!): User
  orders(first: Int, after: String): OrderConnection
}

type User {
  id: ID!
  email: String!
  profile: Profile
  orders(status: OrderStatus): [Order!]!
}

type Order {
  id: ID!
  status: OrderStatus!
  items: [OrderItem!]!
  total: Money!
  createdAt: DateTime!
}

# Connections for pagination
type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
}
```

### Technology Selection
- **Apollo Server**: Mature, well-documented, team familiarity
- **DataLoader**: N+1 query prevention
- **Persisted Queries**: Security and caching benefits
- **Federation**: Future multi-service schema composition

### Implementation Phases
1. **Phase 1 (4 weeks)**: Core schema for user and order domains
2. **Phase 2 (3 weeks)**: Mobile integration and testing
3. **Phase 3 (2 weeks)**: Performance optimization and monitoring
4. **Phase 4 (ongoing)**: Expand to remaining domains

## Alternatives Considered

### Alternative 1: BFF Pattern (Backend for Frontend)
Create dedicated REST APIs optimized for mobile screens.

**Pros:**
- Team already knows REST
- No new technology introduction
- Simpler implementation

**Cons:**
- Duplicates logic between BFF and existing APIs
- Still requires multiple endpoints per screen
- Version management remains challenging

**Why Rejected:** Does not solve fundamental over-fetching problem.

### Alternative 2: gRPC with Mobile Clients
Use gRPC for efficient binary protocol.

**Pros:**
- Excellent performance
- Strong typing with protobuf
- Streaming support

**Cons:**
- Limited browser support
- Steeper learning curve
- Less tooling for mobile debugging

**Why Rejected:** Web client support requirements make gRPC unsuitable.

### Alternative 3: JSON:API Specification
Adopt JSON:API standard for REST responses with sparse fieldsets.

**Pros:**
- Built on REST (familiar)
- Sparse fieldsets reduce over-fetching
- Standardized pagination

**Cons:**
- Still multiple round trips for related resources
- Limited adoption in ecosystem
- Complex include syntax for nested resources

**Why Rejected:** Doesn't provide same query flexibility as GraphQL.

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| N+1 query performance | High | High | DataLoader mandatory, query complexity analysis |
| Schema sprawl | Medium | Medium | Schema review in PR process, linting |
| Security (over-querying) | Medium | High | Query depth limits, persisted queries only |
| Team learning curve | Medium | Low | Training budget, pair programming |
| Backward compatibility | Low | High | Schema evolution guidelines, deprecation policy |

### Security Considerations
- Depth limiting (max 5 levels)
- Cost analysis per query
- Rate limiting per user
- Persisted queries in production (no arbitrary queries)
- Introspection disabled in production

## Dependencies

### Teams Affected
- **Mobile Team**: Primary consumer, integration work
- **Platform Team**: Gateway deployment and operations
- **Backend Teams**: Resolver implementation for their domains

### External Dependencies
- Apollo Server packages
- Schema registry tooling
- Monitoring integration (Apollo Studio or similar)

## Timeline

```
Week 1-2:   RFC review and approval
Week 3-6:   Phase 1 - Core schema implementation
Week 7-9:   Phase 2 - Mobile integration
Week 10-11: Phase 3 - Performance optimization
Week 12:    Production rollout (beta)
Week 14:    General availability
```

## Open Questions

1. Should we use Apollo Studio (SaaS) or self-hosted alternatives?
2. Federation now or single schema initially?
3. How to handle file uploads?

## References

- GraphQL Specification: https://spec.graphql.org/
- Apollo Server Documentation: https://www.apollographql.com/docs/apollo-server/
- DataLoader: https://github.com/graphql/dataloader
- Related ADR: ADR-015 API Strategy

---

## Changelog

| Date | Author | Change |
|------|--------|--------|
| 2024-03-01 | Jane Developer | Initial draft |
| 2024-03-05 | Jane Developer | Added security section |
```

### Anti-Patterns
- Starting implementation before RFC approval
- Omitting alternatives section
- Not specifying success metrics

---

## RFC Lifecycle Management

### When to Use
Implement systematic RFC state management with tooling for tracking proposals through their lifecycle.

### Example

```typescript
// RFC State Machine
type RFCState =
  | 'draft'
  | 'review'
  | 'final_comment'
  | 'approved'
  | 'rejected'
  | 'withdrawn'
  | 'implemented'
  | 'superseded';

interface RFC {
  id: string;
  title: string;
  author: string;
  state: RFCState;
  created: Date;
  updated: Date;
  reviewDeadline?: Date;
  approvers: string[];
  blockers: string[];
  implementationPR?: string;
  supersededBy?: string;
}

interface StateTransition {
  from: RFCState;
  to: RFCState;
  conditions: (rfc: RFC) => boolean;
  actions: (rfc: RFC) => Promise<void>;
}

const transitions: StateTransition[] = [
  {
    from: 'draft',
    to: 'review',
    conditions: (rfc) => {
      // Must have all required sections
      return hasRequiredSections(rfc);
    },
    actions: async (rfc) => {
      // Set review deadline (2 weeks)
      rfc.reviewDeadline = addDays(new Date(), 14);
      // Notify stakeholders
      await notifyStakeholders(rfc, 'RFC moved to review');
      // Create Slack thread
      await createDiscussionThread(rfc);
    }
  },
  {
    from: 'review',
    to: 'final_comment',
    conditions: (rfc) => {
      // Review period ended
      return new Date() >= rfc.reviewDeadline!;
    },
    actions: async (rfc) => {
      // 1 week final comment period
      rfc.reviewDeadline = addDays(new Date(), 7);
      await notifyStakeholders(rfc, 'RFC entering final comment period');
    }
  },
  {
    from: 'final_comment',
    to: 'approved',
    conditions: (rfc) => {
      // At least 2 approvers, no blockers
      return rfc.approvers.length >= 2 && rfc.blockers.length === 0;
    },
    actions: async (rfc) => {
      await notifyStakeholders(rfc, 'RFC approved!');
      await createImplementationIssues(rfc);
    }
  },
  {
    from: 'final_comment',
    to: 'rejected',
    conditions: (rfc) => {
      // Unresolved blockers after final comment
      return rfc.blockers.length > 0;
    },
    actions: async (rfc) => {
      await notifyStakeholders(rfc, 'RFC rejected - see blocking concerns');
    }
  },
  {
    from: 'approved',
    to: 'implemented',
    conditions: (rfc) => {
      return rfc.implementationPR !== undefined;
    },
    actions: async (rfc) => {
      await updateDocumentation(rfc);
      await archiveRFC(rfc);
    }
  }
];

// RFC Bot for GitHub/GitLab
class RFCBot {
  async onPRComment(comment: Comment): Promise<void> {
    const rfc = await this.getRFCFromPR(comment.prNumber);

    if (comment.body.includes('/approve')) {
      await this.addApprover(rfc, comment.author);
    } else if (comment.body.includes('/block')) {
      const reason = comment.body.replace('/block', '').trim();
      await this.addBlocker(rfc, comment.author, reason);
    } else if (comment.body.includes('/resolve')) {
      await this.removeBlocker(rfc, comment.author);
    }

    await this.checkTransitions(rfc);
  }

  async checkTransitions(rfc: RFC): Promise<void> {
    for (const transition of transitions) {
      if (
        rfc.state === transition.from &&
        transition.conditions(rfc)
      ) {
        rfc.state = transition.to;
        await transition.actions(rfc);
        break;
      }
    }
  }
}
```

### Anti-Patterns
- No defined timeline for review periods
- Missing notification of state changes
- No tracking of blocking concerns

---

## Review Guidelines

### When to Use
Establish clear expectations for RFC reviewers to ensure thorough and constructive feedback.

### Example

```markdown
# RFC Review Guidelines

## Reviewer Responsibilities

### Within 3 Days of Review Start
- [ ] Acknowledge receipt of RFC
- [ ] Identify if you have blocking concerns
- [ ] Request clarification on unclear sections

### During Review Period
- [ ] Evaluate technical soundness
- [ ] Consider operational implications
- [ ] Assess security and compliance impact
- [ ] Review against team standards

### Feedback Categories

#### Blocking Concerns
Use `/block` only for:
- Security vulnerabilities
- Significant scalability issues
- Compliance violations
- Missing critical information

#### Non-Blocking Feedback
- Suggestions for improvement
- Alternative approaches to consider
- Requests for clarification
- Minor issues or typos

### Review Checklist

```yaml
review_checklist:
  problem_statement:
    - Is the problem clearly defined?
    - Are metrics for success specified?
    - Is the scope appropriate?

  solution_design:
    - Is the architecture sound?
    - Are interfaces well-defined?
    - Is the implementation feasible?
    - Are edge cases considered?

  alternatives:
    - Were reasonable alternatives considered?
    - Is the rejection rationale sound?
    - Could hybrid approaches work?

  risks:
    - Are risks properly identified?
    - Are mitigations adequate?
    - Is the risk/reward balanced?

  operations:
    - Can we monitor this?
    - Is rollback possible?
    - What's the operational burden?

  security:
    - Are authentication/authorization considered?
    - Is data protected appropriately?
    - Are attack vectors addressed?
```

### Constructive Feedback Examples

**Instead of:** "This won't work"
**Write:** "I have concerns about X because Y. Have you considered Z?"

**Instead of:** "We tried this before"
**Write:** "We attempted similar approach in 2022 (link). Key learnings were..."

**Instead of:** "Too complex"
**Write:** "The complexity in section 3.2 concerns me. Could we simplify by...?"
```

### Anti-Patterns
- Blocking without specific reason
- Reviewing only technical aspects
- Silent disagreement (not participating)

---

## Lightweight RFC Process

### When to Use
Streamlined RFC process for smaller teams or less critical decisions that still benefit from documentation.

### Example

```markdown
# Lightweight RFC: Add Redis Caching Layer

**Author:** @dev-jane | **Date:** 2024-03-10 | **Status:** Proposed

## Problem
API response times averaging 400ms due to repeated database queries.

## Proposal
Add Redis cache for frequently accessed data:
- User profiles (5 min TTL)
- Product catalog (1 hour TTL)
- Session data (sliding 30 min)

## Trade-offs
| Pros | Cons |
|------|------|
| 80% latency reduction | Added infrastructure |
| Reduced DB load | Cache invalidation complexity |
| Session scalability | Redis operational overhead |

## Questions
1. Self-hosted or managed Redis?
2. Cluster mode needed initially?

## Decision
- [ ] @tech-lead
- [ ] @backend-team

---
**Comments below this line**
```

```typescript
// Lightweight RFC Automation
interface LightweightRFC {
  title: string;
  author: string;
  problem: string;
  proposal: string;
  tradeoffs: { pros: string[]; cons: string[] };
  questions: string[];
  approvers: string[];
  deadline: Date;
}

async function createLightweightRFC(
  rfc: LightweightRFC
): Promise<void> {
  // Create GitHub issue with RFC template
  const issue = await github.issues.create({
    title: `[RFC] ${rfc.title}`,
    body: formatRFCTemplate(rfc),
    labels: ['rfc', 'needs-review'],
    assignees: rfc.approvers
  });

  // Set review deadline (5 business days)
  await scheduleReminder(issue.number, rfc.deadline);

  // Post to Slack
  await slack.postMessage({
    channel: '#engineering',
    text: `New RFC: ${rfc.title}\nReview by: ${rfc.deadline}\n${issue.html_url}`
  });
}

// Auto-close approved RFCs
async function checkRFCApproval(issueNumber: number): Promise<void> {
  const issue = await github.issues.get(issueNumber);
  const approvals = countApprovalReactions(issue);

  if (approvals >= 2) {
    await github.issues.update(issueNumber, {
      state: 'closed',
      labels: ['rfc', 'approved']
    });
    await github.issues.createComment(issueNumber,
      'RFC approved with sufficient consensus. Proceed with implementation.'
    );
  }
}
```

### Anti-Patterns
- Using lightweight RFC for high-impact decisions
- Skipping problem statement
- No decision deadline

---

## RFC Metrics and Reporting

### When to Use
Track RFC process health to identify bottlenecks and improve decision-making velocity.

### Example

```typescript
interface RFCMetrics {
  totalRFCs: number;
  byState: Record<RFCState, number>;
  avgTimeToApproval: number;
  avgTimeToImplementation: number;
  approvalRate: number;
  avgReviewParticipation: number;
}

class RFCAnalytics {
  async generateReport(
    startDate: Date,
    endDate: Date
  ): Promise<RFCMetrics> {
    const rfcs = await this.getRFCsInRange(startDate, endDate);

    return {
      totalRFCs: rfcs.length,
      byState: this.groupByState(rfcs),
      avgTimeToApproval: this.calculateAvgApprovalTime(rfcs),
      avgTimeToImplementation: this.calculateAvgImplementationTime(rfcs),
      approvalRate: this.calculateApprovalRate(rfcs),
      avgReviewParticipation: this.calculateAvgParticipation(rfcs)
    };
  }

  generateHealthDashboard(): Dashboard {
    return {
      panels: [
        {
          title: 'RFC Throughput',
          query: `
            SELECT
              date_trunc('week', created_at) as week,
              COUNT(*) as rfcs_created,
              COUNT(*) FILTER (WHERE state = 'approved') as approved,
              COUNT(*) FILTER (WHERE state = 'rejected') as rejected
            FROM rfcs
            WHERE created_at > NOW() - INTERVAL '3 months'
            GROUP BY 1
            ORDER BY 1
          `
        },
        {
          title: 'Time in Review',
          query: `
            SELECT
              title,
              EXTRACT(days FROM approved_at - review_started_at) as review_days
            FROM rfcs
            WHERE state = 'approved'
            ORDER BY review_days DESC
            LIMIT 10
          `
        },
        {
          title: 'Participation Rate',
          query: `
            SELECT
              reviewer,
              COUNT(*) as reviews_given,
              AVG(review_quality_score) as avg_quality
            FROM rfc_reviews
            WHERE created_at > NOW() - INTERVAL '3 months'
            GROUP BY 1
            ORDER BY 2 DESC
          `
        }
      ]
    };
  }
}

// Weekly RFC digest
async function sendWeeklyDigest(): Promise<void> {
  const analytics = new RFCAnalytics();
  const metrics = await analytics.generateReport(
    subDays(new Date(), 7),
    new Date()
  );

  const digest = `
## RFC Weekly Digest

### This Week
- **New RFCs:** ${metrics.totalRFCs}
- **Approved:** ${metrics.byState.approved}
- **In Review:** ${metrics.byState.review}

### Health Metrics
- **Avg. Time to Approval:** ${metrics.avgTimeToApproval} days
- **Review Participation:** ${metrics.avgReviewParticipation} reviewers/RFC
- **Approval Rate:** ${(metrics.approvalRate * 100).toFixed(1)}%

### Attention Needed
${await getStaleRFCs()}
  `;

  await slack.postMessage({
    channel: '#engineering',
    text: digest
  });
}
```

### Anti-Patterns
- Not tracking RFC cycle time
- Ignoring review participation metrics
- No visibility into stuck RFCs

---

## Checklist

### Starting an RFC
- [ ] Change meets RFC threshold (>2 weeks or cross-team)
- [ ] Problem statement drafted
- [ ] Stakeholders identified
- [ ] Initial alternatives researched
- [ ] Success metrics defined

### Submitting for Review
- [ ] All template sections completed
- [ ] Technical design detailed enough for review
- [ ] Risks and mitigations documented
- [ ] Timeline estimated
- [ ] Dependencies identified

### During Review
- [ ] Respond to questions within 2 business days
- [ ] Update RFC based on feedback
- [ ] Track blocking concerns
- [ ] Facilitate consensus building

### Post-Approval
- [ ] Create implementation issues
- [ ] Update RFC status
- [ ] Communicate decision to stakeholders
- [ ] Schedule implementation kickoff

---

## References

- IETF RFC Process: https://www.ietf.org/standards/process/
- Rust RFC Process: https://rust-lang.github.io/rfcs/
- Google Design Docs: https://www.industrialempathy.com/posts/design-docs-at-google/
- ADR vs RFC: https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
