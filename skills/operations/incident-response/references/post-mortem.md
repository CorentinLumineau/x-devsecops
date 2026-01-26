---
title: Post-Mortem Reference
category: operations
type: reference
version: "1.0.0"
---

# Post-Mortem

> Part of the operations/incident-response knowledge skill

## Overview

Post-mortems enable learning from incidents through blameless analysis. This reference covers post-mortem structure, facilitation, and action item tracking.

## Quick Reference (80/20)

| Section | Purpose |
|---------|---------|
| Summary | What happened, when, impact |
| Timeline | Chronological event sequence |
| Root Cause | Why it happened |
| Impact | Users/revenue affected |
| Actions | Preventive measures |
| Lessons | What we learned |

## Patterns

### Pattern 1: Post-Mortem Template

**When to Use**: Documenting incident learnings

**Example**:
```markdown
# Post-Mortem: [Incident Title]

**Date**: YYYY-MM-DD
**Incident ID**: INC-XXXX
**Severity**: P1/P2/P3
**Duration**: X hours Y minutes
**Author**: @author
**Reviewers**: @reviewer1, @reviewer2

## Executive Summary

[2-3 sentence summary of what happened, impact, and resolution]

On [date] at [time], [brief description of incident]. The incident affected [X% of users/specific regions/services] for [duration]. The root cause was [brief root cause]. The issue was resolved by [brief resolution].

## Impact

### User Impact
- **Affected Users**: X,XXX (Y% of total)
- **Affected Regions**: [list]
- **Error Rate**: X% (normal: Y%)
- **Latency**: XXXms P99 (normal: YYYms)

### Business Impact
- **Revenue Loss**: $X,XXX (estimated)
- **SLA Breach**: Yes/No
- **Customer Complaints**: X tickets
- **Reputational Impact**: Low/Medium/High

### Technical Impact
- **Services Affected**: [list]
- **Data Loss**: None/Partial/Significant
- **Cascading Failures**: Yes/No

## Timeline (All times in UTC)

| Time | Event |
|------|-------|
| 14:00 | Deployment of v2.3.1 begins |
| 14:05 | Deployment complete, pods healthy |
| 14:15 | First latency alerts fire |
| 14:18 | On-call engineer paged |
| 14:25 | Investigation begins |
| 14:35 | Root cause identified |
| 14:40 | Rollback initiated |
| 14:45 | Rollback complete |
| 14:50 | Latency returns to normal |
| 14:55 | Monitoring confirms resolution |
| 15:00 | Incident declared resolved |

## Root Cause Analysis

### What Happened

[Detailed technical explanation of what went wrong]

The deployment included a change to the database connection pooling configuration that reduced the maximum connections from 100 to 10. This was an unintended side effect of a configuration refactor that merged multiple config files.

### Why It Happened

**Contributing Factors:**

1. **Configuration Complexity**
   - Multiple configuration files with overlapping settings
   - No validation of critical parameters in CI/CD

2. **Testing Gaps**
   - Load testing not run for this release
   - Staging environment has different connection limits

3. **Deployment Process**
   - No canary deployment for this release
   - Metrics dashboard not monitored during deploy

### 5 Whys Analysis

1. **Why did the service become slow?**
   → Database connections were exhausted

2. **Why were connections exhausted?**
   → Connection pool was limited to 10 connections

3. **Why was the pool limited to 10?**
   → Configuration change set incorrect value

4. **Why wasn't this caught in testing?**
   → Load testing was skipped for "low-risk" change

5. **Why was load testing skipped?**
   → No automated requirement for configuration changes

## Detection

### How Was It Detected?

- **Method**: Automated monitoring alert
- **Alert Name**: `APILatencyP99High`
- **Time to Detect**: 10 minutes after deploy
- **Detection Gap**: Alert threshold too high (500ms vs 200ms normal)

### Detection Improvements

- [ ] Lower latency alert threshold to 300ms
- [ ] Add connection pool utilization alert
- [ ] Create deployment correlation alerts

## Response

### What Went Well

- On-call responded within 5 minutes of page
- Clear escalation to secondary on-call
- Rollback executed quickly and cleanly
- Good communication in #incidents channel

### What Could Be Improved

- Initial investigation focused on wrong area (CPU/memory)
- Dashboard didn't show connection pool metrics
- Rollback required manual approval (added 5 min)

### Response Timeline Analysis

| Phase | Duration | Target | Status |
|-------|----------|--------|--------|
| Detection | 10 min | 5 min | ❌ |
| Acknowledgment | 3 min | 5 min | ✅ |
| Investigation | 15 min | 15 min | ✅ |
| Mitigation | 10 min | 15 min | ✅ |
| Resolution | 5 min | 10 min | ✅ |
| **Total** | **43 min** | **50 min** | ✅ |

## Lessons Learned

### Things That Worked

1. Runbook for database issues was helpful
2. Rollback automation worked flawlessly
3. Team collaboration was excellent

### Things That Didn't Work

1. Configuration validation was insufficient
2. Load testing was manually triggered
3. Connection pool metrics not visible

### Lucky Breaks

1. Incident occurred during business hours with full team
2. Only one region was affected initially
3. No data corruption occurred

## Action Items

### Immediate (This Sprint)

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 1 | Add connection pool validation to CI | @dev1 | 2024-01-20 | 🔄 In Progress |
| 2 | Lower latency alert threshold | @sre1 | 2024-01-18 | ✅ Done |
| 3 | Add connection pool dashboard | @sre2 | 2024-01-22 | ⬜ Todo |

### Short-term (This Quarter)

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 4 | Implement canary deployments | @platform | 2024-02-15 | ⬜ Todo |
| 5 | Add load test to CI pipeline | @qa | 2024-02-28 | ⬜ Todo |
| 6 | Auto-rollback on latency spike | @sre1 | 2024-03-01 | ⬜ Todo |

### Long-term (This Year)

| ID | Action | Owner | Due Date | Status |
|----|--------|-------|----------|--------|
| 7 | Configuration management overhaul | @platform | 2024-06-01 | ⬜ Todo |
| 8 | Chaos engineering program | @sre | 2024-09-01 | ⬜ Todo |

## Supporting Information

### Related Incidents

- [INC-1234](link) - Similar config issue in 2023
- [INC-2345](link) - Database connection exhaustion

### Relevant Dashboards

- [API Performance](https://grafana/api)
- [Database Metrics](https://grafana/db)
- [Deployment Tracking](https://grafana/deploys)

### References

- [Database Connection Pooling Best Practices](link)
- [Configuration Management RFC](link)

---

**Post-Mortem Review Meeting**: YYYY-MM-DD at HH:MM
**Attendees**: @team-lead, @sre-manager, @eng-manager
**Status**: Draft / Under Review / Approved
```

**Anti-Pattern**: Post-mortems with blame or without action items.

### Pattern 2: Blameless Culture Framework

**When to Use**: Establishing psychological safety

**Example**:
```typescript
// post-mortem-guidelines.ts
interface BlamelessPrinciples {
  assumptions: string[];
  language: LanguageGuidelines;
  questions: FacilitatorQuestions;
  antiPatterns: string[];
}

const blamelessFramework: BlamelessPrinciples = {
  assumptions: [
    "People did the best they could with the information they had",
    "Failures are opportunities to improve systems, not punish individuals",
    "Human error is a symptom, not a cause",
    "Complex systems fail in complex ways",
    "Blame fixes nothing; understanding prevents recurrence"
  ],

  language: {
    avoid: [
      "should have known",
      "failed to",
      "mistake",
      "fault",
      "blame",
      "negligent",
      "careless",
      "obvious"
    ],
    prefer: [
      "the system allowed",
      "we discovered",
      "the process didn't catch",
      "we learned",
      "contributing factors",
      "given the context",
      "at the time, it appeared"
    ],
    examples: [
      {
        bad: "The engineer failed to test the change",
        good: "The testing process didn't include this scenario"
      },
      {
        bad: "They should have known this would happen",
        good: "The system didn't provide visibility into this risk"
      },
      {
        bad: "It was a careless mistake",
        good: "The interface made it easy to select the wrong option"
      }
    ]
  },

  questions: {
    forUnderstanding: [
      "What information did you have at the time?",
      "What other options did you consider?",
      "What would have helped you make a different decision?",
      "What signals were you looking at?",
      "How did the system behave compared to expectations?"
    ],
    forImprovement: [
      "How can we make this safer to do?",
      "What guardrails could prevent this?",
      "How can we detect this earlier?",
      "What documentation would help?",
      "How can we make the right choice obvious?"
    ],
    toAvoid: [
      "Why didn't you...",
      "Didn't you realize...",
      "Who approved this?",
      "Why wasn't this tested?",
      "How could you miss..."
    ]
  },

  antiPatterns: [
    "Naming individuals as root causes",
    "Requiring apologies or admissions",
    "Performance reviews based on incidents",
    "Public shaming or criticism",
    "Skipping post-mortems for 'obvious' causes",
    "Action items assigned as punishment",
    "Leadership not attending reviews"
  ]
};

// Post-mortem review checklist
interface ReviewChecklist {
  beforeMeeting: string[];
  duringMeeting: string[];
  afterMeeting: string[];
}

const facilitatorChecklist: ReviewChecklist = {
  beforeMeeting: [
    "Review incident timeline with participants",
    "Identify all contributing factors",
    "Prepare blameless language reminders",
    "Ensure psychological safety is established",
    "Invite relevant stakeholders (not too many)",
    "Share draft document 24h before meeting"
  ],

  duringMeeting: [
    "Start with blameless principles reminder",
    "Walk through timeline chronologically",
    "Ask 'what' and 'how', not 'who' and 'why didn't'",
    "Capture action items with owners",
    "Identify systemic improvements",
    "Thank participants for transparency",
    "Time-box discussion (60-90 minutes)"
  ],

  afterMeeting: [
    "Publish post-mortem within 48 hours",
    "Create tickets for all action items",
    "Schedule follow-up for action item review",
    "Share learnings with broader organization",
    "Update runbooks and documentation",
    "Recognize positive behaviors observed"
  ]
};
```

**Anti-Pattern**: Blame-focused reviews that discourage reporting.

### Pattern 3: Impact Calculation

**When to Use**: Quantifying incident impact

**Example**:
```typescript
// impact-calculator.ts
interface IncidentImpact {
  userImpact: UserImpact;
  businessImpact: BusinessImpact;
  technicalImpact: TechnicalImpact;
  overallSeverity: 'P1' | 'P2' | 'P3' | 'P4';
}

interface UserImpact {
  totalAffected: number;
  percentageAffected: number;
  impactType: 'complete_outage' | 'degraded' | 'partial' | 'minimal';
  regionsAffected: string[];
  durationMinutes: number;
}

interface BusinessImpact {
  estimatedRevenueLoss: number;
  slaBreached: boolean;
  slaPenalty: number;
  customerTickets: number;
  reputationalRisk: 'low' | 'medium' | 'high';
}

interface TechnicalImpact {
  servicesAffected: string[];
  dataLoss: 'none' | 'partial' | 'significant';
  recoveryTimeMinutes: number;
  cascadingFailures: boolean;
}

class ImpactCalculator {
  private readonly REVENUE_PER_MINUTE = 100; // $ per minute
  private readonly TOTAL_USERS = 1000000;

  calculateImpact(incident: IncidentData): IncidentImpact {
    const userImpact = this.calculateUserImpact(incident);
    const businessImpact = this.calculateBusinessImpact(incident, userImpact);
    const technicalImpact = this.calculateTechnicalImpact(incident);
    const overallSeverity = this.calculateSeverity(
      userImpact,
      businessImpact,
      technicalImpact
    );

    return {
      userImpact,
      businessImpact,
      technicalImpact,
      overallSeverity
    };
  }

  private calculateUserImpact(incident: IncidentData): UserImpact {
    const totalAffected = this.estimateAffectedUsers(incident);
    const percentageAffected = (totalAffected / this.TOTAL_USERS) * 100;

    return {
      totalAffected,
      percentageAffected,
      impactType: this.determineImpactType(incident),
      regionsAffected: incident.affectedRegions,
      durationMinutes: this.calculateDuration(incident)
    };
  }

  private calculateBusinessImpact(
    incident: IncidentData,
    userImpact: UserImpact
  ): BusinessImpact {
    const impactMultiplier = this.getImpactMultiplier(userImpact.impactType);
    const estimatedRevenueLoss =
      this.REVENUE_PER_MINUTE *
      userImpact.durationMinutes *
      (userImpact.percentageAffected / 100) *
      impactMultiplier;

    const slaBreached = this.checkSLABreach(userImpact);
    const slaPenalty = slaBreached ? this.calculateSLAPenalty(userImpact) : 0;

    return {
      estimatedRevenueLoss,
      slaBreached,
      slaPenalty,
      customerTickets: incident.supportTickets,
      reputationalRisk: this.assessReputationalRisk(incident, userImpact)
    };
  }

  private calculateTechnicalImpact(incident: IncidentData): TechnicalImpact {
    return {
      servicesAffected: incident.affectedServices,
      dataLoss: incident.dataLoss ?? 'none',
      recoveryTimeMinutes: this.calculateRecoveryTime(incident),
      cascadingFailures: incident.affectedServices.length > 1
    };
  }

  private calculateSeverity(
    user: UserImpact,
    business: BusinessImpact,
    technical: TechnicalImpact
  ): 'P1' | 'P2' | 'P3' | 'P4' {
    // P1: Critical - Major outage affecting >50% users or revenue loss >$10k
    if (
      user.impactType === 'complete_outage' ||
      user.percentageAffected > 50 ||
      business.estimatedRevenueLoss > 10000 ||
      technical.dataLoss === 'significant'
    ) {
      return 'P1';
    }

    // P2: High - Significant degradation affecting >10% users
    if (
      user.impactType === 'degraded' ||
      user.percentageAffected > 10 ||
      business.estimatedRevenueLoss > 1000 ||
      technical.cascadingFailures
    ) {
      return 'P2';
    }

    // P3: Medium - Partial impact affecting <10% users
    if (
      user.impactType === 'partial' ||
      user.percentageAffected > 1 ||
      business.estimatedRevenueLoss > 100
    ) {
      return 'P3';
    }

    // P4: Low - Minimal impact
    return 'P4';
  }

  private estimateAffectedUsers(incident: IncidentData): number {
    // Based on error rates and traffic during incident
    const errorRate = incident.errorRate ?? 0;
    const requestsPerMinute = incident.requestsPerMinute ?? 1000;
    const duration = this.calculateDuration(incident);

    return Math.round(requestsPerMinute * duration * errorRate);
  }

  private determineImpactType(incident: IncidentData): UserImpact['impactType'] {
    const errorRate = incident.errorRate ?? 0;

    if (errorRate > 0.9) return 'complete_outage';
    if (errorRate > 0.5) return 'degraded';
    if (errorRate > 0.1) return 'partial';
    return 'minimal';
  }

  private calculateDuration(incident: IncidentData): number {
    const start = new Date(incident.startTime).getTime();
    const end = new Date(incident.endTime ?? Date.now()).getTime();
    return Math.round((end - start) / 60000);
  }

  private getImpactMultiplier(impactType: UserImpact['impactType']): number {
    const multipliers = {
      complete_outage: 1.0,
      degraded: 0.5,
      partial: 0.2,
      minimal: 0.05
    };
    return multipliers[impactType];
  }

  private checkSLABreach(userImpact: UserImpact): boolean {
    // Example SLA: 99.9% uptime = ~43 minutes downtime/month
    const monthlyDowntimeBudget = 43;
    return userImpact.impactType === 'complete_outage' &&
           userImpact.durationMinutes > monthlyDowntimeBudget;
  }

  private calculateSLAPenalty(userImpact: UserImpact): number {
    // Example: 10% credit for every hour of SLA breach
    const hoursBreached = Math.ceil(userImpact.durationMinutes / 60);
    const monthlyRevenue = this.REVENUE_PER_MINUTE * 60 * 24 * 30;
    return monthlyRevenue * 0.1 * hoursBreached;
  }

  private assessReputationalRisk(
    incident: IncidentData,
    userImpact: UserImpact
  ): 'low' | 'medium' | 'high' {
    if (
      incident.publiclyVisible ||
      userImpact.impactType === 'complete_outage' ||
      incident.supportTickets > 100
    ) {
      return 'high';
    }

    if (
      userImpact.impactType === 'degraded' ||
      incident.supportTickets > 20
    ) {
      return 'medium';
    }

    return 'low';
  }

  private calculateRecoveryTime(incident: IncidentData): number {
    if (!incident.recoveryStartTime || !incident.endTime) {
      return 0;
    }
    const start = new Date(incident.recoveryStartTime).getTime();
    const end = new Date(incident.endTime).getTime();
    return Math.round((end - start) / 60000);
  }
}
```

**Anti-Pattern**: Qualitative-only impact assessment.

### Pattern 4: Action Item Tracking

**When to Use**: Following up on post-mortem actions

**Example**:
```typescript
// action-tracker.ts
interface ActionItem {
  id: string;
  postMortemId: string;
  title: string;
  description: string;
  owner: string;
  priority: 'critical' | 'high' | 'medium' | 'low';
  category: 'detection' | 'prevention' | 'mitigation' | 'process';
  status: 'todo' | 'in_progress' | 'blocked' | 'done';
  dueDate: Date;
  completedDate?: Date;
  jiraTicket?: string;
  blockedReason?: string;
}

interface ActionMetrics {
  total: number;
  completed: number;
  overdue: number;
  blocked: number;
  byCategory: Record<string, number>;
  completionRate: number;
  averageTimeToComplete: number;
}

class ActionItemTracker {
  constructor(
    private store: ActionStore,
    private jiraClient: JiraClient,
    private notificationService: NotificationService
  ) {}

  async createActionItem(
    postMortemId: string,
    action: Omit<ActionItem, 'id' | 'postMortemId' | 'status'>
  ): Promise<ActionItem> {
    const actionItem: ActionItem = {
      id: this.generateId(),
      postMortemId,
      status: 'todo',
      ...action
    };

    // Create Jira ticket if needed
    if (action.priority === 'critical' || action.priority === 'high') {
      const ticket = await this.jiraClient.createTicket({
        summary: `[Post-Mortem] ${action.title}`,
        description: action.description,
        assignee: action.owner,
        priority: this.mapPriority(action.priority),
        labels: ['post-mortem', action.category],
        dueDate: action.dueDate
      });
      actionItem.jiraTicket = ticket.key;
    }

    await this.store.save(actionItem);

    // Notify owner
    await this.notificationService.notify({
      type: 'action_assigned',
      recipient: action.owner,
      data: {
        actionId: actionItem.id,
        title: action.title,
        dueDate: action.dueDate,
        postMortemId
      }
    });

    return actionItem;
  }

  async updateStatus(
    actionId: string,
    status: ActionItem['status'],
    metadata?: { blockedReason?: string }
  ): Promise<void> {
    const action = await this.store.get(actionId);
    if (!action) throw new Error(`Action ${actionId} not found`);

    const updates: Partial<ActionItem> = { status };

    if (status === 'done') {
      updates.completedDate = new Date();
    }

    if (status === 'blocked' && metadata?.blockedReason) {
      updates.blockedReason = metadata.blockedReason;
    }

    await this.store.update(actionId, updates);

    // Sync with Jira
    if (action.jiraTicket) {
      await this.jiraClient.updateStatus(
        action.jiraTicket,
        this.mapStatusToJira(status)
      );
    }
  }

  async getMetrics(timeframe?: { start: Date; end: Date }): Promise<ActionMetrics> {
    const actions = await this.store.getAll(timeframe);

    const total = actions.length;
    const completed = actions.filter(a => a.status === 'done').length;
    const blocked = actions.filter(a => a.status === 'blocked').length;
    const overdue = actions.filter(a =>
      a.status !== 'done' &&
      new Date(a.dueDate) < new Date()
    ).length;

    const byCategory: Record<string, number> = {};
    actions.forEach(a => {
      byCategory[a.category] = (byCategory[a.category] || 0) + 1;
    });

    const completedActions = actions.filter(a => a.completedDate);
    const totalCompletionTime = completedActions.reduce((sum, a) => {
      const created = new Date(a.id.split('-')[0]); // Assuming timestamp in ID
      const completed = new Date(a.completedDate!);
      return sum + (completed.getTime() - created.getTime());
    }, 0);

    return {
      total,
      completed,
      overdue,
      blocked,
      byCategory,
      completionRate: total > 0 ? (completed / total) * 100 : 0,
      averageTimeToComplete: completedActions.length > 0
        ? totalCompletionTime / completedActions.length / (1000 * 60 * 60 * 24) // days
        : 0
    };
  }

  async checkOverdueActions(): Promise<void> {
    const overdueActions = await this.store.getOverdue();

    for (const action of overdueActions) {
      // Notify owner
      await this.notificationService.notify({
        type: 'action_overdue',
        recipient: action.owner,
        data: {
          actionId: action.id,
          title: action.title,
          dueDate: action.dueDate,
          daysPastDue: this.daysPastDue(action.dueDate)
        }
      });

      // Escalate if significantly overdue
      if (this.daysPastDue(action.dueDate) > 7) {
        await this.escalate(action);
      }
    }
  }

  async generateReport(): Promise<string> {
    const metrics = await this.getMetrics();
    const overdueActions = await this.store.getOverdue();
    const blockedActions = await this.store.getBlocked();

    return `
# Post-Mortem Action Items Report

Generated: ${new Date().toISOString()}

## Summary

| Metric | Value |
|--------|-------|
| Total Actions | ${metrics.total} |
| Completed | ${metrics.completed} (${metrics.completionRate.toFixed(1)}%) |
| Overdue | ${metrics.overdue} |
| Blocked | ${metrics.blocked} |
| Avg Time to Complete | ${metrics.averageTimeToComplete.toFixed(1)} days |

## Actions by Category

| Category | Count |
|----------|-------|
${Object.entries(metrics.byCategory).map(([cat, count]) => `| ${cat} | ${count} |`).join('\n')}

## Overdue Actions

${overdueActions.length > 0
  ? overdueActions.map(a => `- **${a.title}** (${a.owner}) - ${this.daysPastDue(a.dueDate)} days overdue`).join('\n')
  : 'No overdue actions'}

## Blocked Actions

${blockedActions.length > 0
  ? blockedActions.map(a => `- **${a.title}** (${a.owner}) - ${a.blockedReason}`).join('\n')
  : 'No blocked actions'}
`;
  }

  private daysPastDue(dueDate: Date): number {
    const now = new Date();
    const due = new Date(dueDate);
    return Math.floor((now.getTime() - due.getTime()) / (1000 * 60 * 60 * 24));
  }

  private async escalate(action: ActionItem): Promise<void> {
    await this.notificationService.notify({
      type: 'action_escalation',
      recipients: ['engineering-managers', 'sre-leads'],
      data: {
        actionId: action.id,
        title: action.title,
        owner: action.owner,
        daysPastDue: this.daysPastDue(action.dueDate),
        postMortemId: action.postMortemId
      }
    });
  }

  private generateId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private mapPriority(priority: ActionItem['priority']): string {
    const mapping = {
      critical: 'Highest',
      high: 'High',
      medium: 'Medium',
      low: 'Low'
    };
    return mapping[priority];
  }

  private mapStatusToJira(status: ActionItem['status']): string {
    const mapping = {
      todo: 'To Do',
      in_progress: 'In Progress',
      blocked: 'Blocked',
      done: 'Done'
    };
    return mapping[status];
  }
}

// Scheduled job
const scheduler = new Scheduler();

scheduler.daily(async () => {
  const tracker = new ActionItemTracker(store, jira, notifications);

  // Check overdue items
  await tracker.checkOverdueActions();

  // Generate weekly report
  if (new Date().getDay() === 1) { // Monday
    const report = await tracker.generateReport();
    await notifications.sendToChannel('#post-mortems', report);
  }
});
```

**Anti-Pattern**: Action items without tracking or follow-up.

### Pattern 5: Post-Mortem Automation

**When to Use**: Automating post-mortem creation

**Example**:
```typescript
// post-mortem-generator.ts
class PostMortemGenerator {
  constructor(
    private incidentService: IncidentService,
    private metricsService: MetricsService,
    private alertService: AlertService,
    private slackService: SlackService,
    private templateEngine: TemplateEngine
  ) {}

  async generateDraft(incidentId: string): Promise<string> {
    // Gather data from multiple sources
    const [incident, timeline, metrics, alerts, slackMessages] = await Promise.all([
      this.incidentService.get(incidentId),
      this.incidentService.getTimeline(incidentId),
      this.metricsService.getIncidentMetrics(incidentId),
      this.alertService.getAlertsForIncident(incidentId),
      this.slackService.getIncidentMessages(incidentId)
    ]);

    const impact = this.calculateImpact(incident, metrics);
    const detectionInfo = this.analyzeDetection(alerts, timeline);
    const responseAnalysis = this.analyzeResponse(timeline, slackMessages);

    return this.templateEngine.render('post-mortem', {
      incident,
      timeline: this.formatTimeline(timeline),
      impact,
      detection: detectionInfo,
      response: responseAnalysis,
      suggestedActions: this.suggestActions(incident, impact, detectionInfo)
    });
  }

  private formatTimeline(events: TimelineEvent[]): FormattedTimeline[] {
    return events.map(event => ({
      time: event.timestamp.toISOString().substr(11, 5),
      event: event.description,
      actor: event.actor,
      source: event.source
    }));
  }

  private calculateImpact(incident: Incident, metrics: IncidentMetrics): Impact {
    const calculator = new ImpactCalculator();
    return calculator.calculateImpact({
      startTime: incident.startTime,
      endTime: incident.endTime,
      errorRate: metrics.errorRate,
      requestsPerMinute: metrics.requestsPerMinute,
      affectedServices: incident.affectedServices,
      affectedRegions: incident.affectedRegions,
      supportTickets: incident.supportTickets,
      publiclyVisible: incident.publiclyVisible
    });
  }

  private analyzeDetection(alerts: Alert[], timeline: TimelineEvent[]): DetectionAnalysis {
    const firstAlert = alerts.sort((a, b) =>
      a.timestamp.getTime() - b.timestamp.getTime()
    )[0];

    const incidentStart = timeline.find(e => e.type === 'incident_start');
    const firstResponse = timeline.find(e => e.type === 'acknowledgment');

    return {
      detectionMethod: firstAlert?.source ?? 'manual',
      timeToDetect: incidentStart && firstAlert
        ? (firstAlert.timestamp.getTime() - incidentStart.timestamp.getTime()) / 60000
        : null,
      timeToAcknowledge: firstAlert && firstResponse
        ? (firstResponse.timestamp.getTime() - firstAlert.timestamp.getTime()) / 60000
        : null,
      alertsThatFired: alerts.map(a => a.name),
      alertsThatShouldHaveFired: this.identifyMissingAlerts(alerts, timeline)
    };
  }

  private analyzeResponse(
    timeline: TimelineEvent[],
    slackMessages: SlackMessage[]
  ): ResponseAnalysis {
    const phases = this.identifyPhases(timeline);
    const participants = this.identifyParticipants(slackMessages);
    const decisions = this.extractDecisions(slackMessages);

    return {
      phases,
      participants,
      decisions,
      whatWorked: this.inferWhatWorked(timeline, slackMessages),
      whatCouldImprove: this.inferImprovements(timeline, slackMessages)
    };
  }

  private suggestActions(
    incident: Incident,
    impact: Impact,
    detection: DetectionAnalysis
  ): SuggestedAction[] {
    const actions: SuggestedAction[] = [];

    // Detection improvements
    if (detection.timeToDetect && detection.timeToDetect > 10) {
      actions.push({
        category: 'detection',
        title: 'Improve detection time',
        description: `Detection took ${detection.timeToDetect} minutes. Consider lowering alert thresholds.`,
        priority: 'high'
      });
    }

    if (detection.alertsThatShouldHaveFired.length > 0) {
      actions.push({
        category: 'detection',
        title: 'Add missing alerts',
        description: `Add alerts for: ${detection.alertsThatShouldHaveFired.join(', ')}`,
        priority: 'high'
      });
    }

    // Prevention based on root cause patterns
    if (incident.rootCause?.includes('config')) {
      actions.push({
        category: 'prevention',
        title: 'Improve configuration validation',
        description: 'Add validation for configuration changes in CI/CD',
        priority: 'high'
      });
    }

    if (incident.rootCause?.includes('capacity')) {
      actions.push({
        category: 'prevention',
        title: 'Implement auto-scaling',
        description: 'Configure HPA based on observed traffic patterns',
        priority: 'medium'
      });
    }

    // Mitigation improvements
    if (impact.technicalImpact.recoveryTimeMinutes > 30) {
      actions.push({
        category: 'mitigation',
        title: 'Improve recovery time',
        description: 'Implement automated rollback or faster recovery procedures',
        priority: 'high'
      });
    }

    return actions;
  }

  private identifyMissingAlerts(
    alerts: Alert[],
    timeline: TimelineEvent[]
  ): string[] {
    const firedAlertTypes = new Set(alerts.map(a => a.type));
    const expectedAlerts = this.getExpectedAlerts(timeline);

    return expectedAlerts.filter(a => !firedAlertTypes.has(a));
  }

  private getExpectedAlerts(timeline: TimelineEvent[]): string[] {
    // Based on incident type, return expected alerts
    const alerts: string[] = [];

    const hasLatencyIssue = timeline.some(e =>
      e.description.toLowerCase().includes('latency')
    );
    if (hasLatencyIssue) {
      alerts.push('high_latency_p99', 'high_latency_p50');
    }

    const hasErrorSpike = timeline.some(e =>
      e.description.toLowerCase().includes('error')
    );
    if (hasErrorSpike) {
      alerts.push('error_rate_high', 'error_budget_burn');
    }

    return alerts;
  }

  private identifyPhases(timeline: TimelineEvent[]): ResponsePhase[] {
    // Group events into response phases
    return [
      { name: 'Detection', events: timeline.filter(e => e.phase === 'detection') },
      { name: 'Investigation', events: timeline.filter(e => e.phase === 'investigation') },
      { name: 'Mitigation', events: timeline.filter(e => e.phase === 'mitigation') },
      { name: 'Resolution', events: timeline.filter(e => e.phase === 'resolution') }
    ];
  }

  private identifyParticipants(messages: SlackMessage[]): string[] {
    return [...new Set(messages.map(m => m.user))];
  }

  private extractDecisions(messages: SlackMessage[]): string[] {
    // Look for decision indicators in messages
    const decisionPatterns = [
      /decided to/i,
      /going to/i,
      /let's/i,
      /we'll/i,
      /action:/i,
      /rolling back/i
    ];

    return messages
      .filter(m => decisionPatterns.some(p => p.test(m.text)))
      .map(m => m.text);
  }

  private inferWhatWorked(
    timeline: TimelineEvent[],
    messages: SlackMessage[]
  ): string[] {
    const items: string[] = [];

    // Quick detection
    const detectionTime = this.calculateDetectionTime(timeline);
    if (detectionTime && detectionTime < 5) {
      items.push('Incident detected within 5 minutes');
    }

    // Quick response
    const responseTime = this.calculateResponseTime(timeline);
    if (responseTime && responseTime < 5) {
      items.push('On-call responded quickly');
    }

    // Good communication
    const participantCount = this.identifyParticipants(messages).length;
    if (participantCount > 2) {
      items.push('Good team collaboration');
    }

    return items;
  }

  private inferImprovements(
    timeline: TimelineEvent[],
    messages: SlackMessage[]
  ): string[] {
    const items: string[] = [];

    // Slow detection
    const detectionTime = this.calculateDetectionTime(timeline);
    if (detectionTime && detectionTime > 15) {
      items.push('Detection time could be improved');
    }

    // Long investigation
    const investigationDuration = this.calculatePhaseDuration(timeline, 'investigation');
    if (investigationDuration && investigationDuration > 30) {
      items.push('Investigation phase was lengthy');
    }

    return items;
  }

  private calculateDetectionTime(timeline: TimelineEvent[]): number | null {
    const start = timeline.find(e => e.type === 'incident_start');
    const detected = timeline.find(e => e.type === 'alert_fired');
    if (!start || !detected) return null;
    return (detected.timestamp.getTime() - start.timestamp.getTime()) / 60000;
  }

  private calculateResponseTime(timeline: TimelineEvent[]): number | null {
    const alert = timeline.find(e => e.type === 'alert_fired');
    const ack = timeline.find(e => e.type === 'acknowledgment');
    if (!alert || !ack) return null;
    return (ack.timestamp.getTime() - alert.timestamp.getTime()) / 60000;
  }

  private calculatePhaseDuration(timeline: TimelineEvent[], phase: string): number | null {
    const phaseEvents = timeline.filter(e => e.phase === phase);
    if (phaseEvents.length < 2) return null;
    const first = phaseEvents[0];
    const last = phaseEvents[phaseEvents.length - 1];
    return (last.timestamp.getTime() - first.timestamp.getTime()) / 60000;
  }
}
```

**Anti-Pattern**: Manual data gathering for post-mortems.

## Checklist

- [ ] Post-mortem scheduled within 48 hours
- [ ] Blameless principles communicated
- [ ] Timeline documented accurately
- [ ] Root cause analysis completed
- [ ] Impact quantified
- [ ] Action items assigned with owners
- [ ] Follow-up scheduled for actions
- [ ] Learnings shared with organization
- [ ] Runbooks updated if needed
- [ ] Post-mortem archived for future reference

## References

- [Google SRE Book - Postmortems](https://sre.google/sre-book/postmortem-culture/)
- [Etsy's Blameless Post-Mortems](https://www.etsy.com/codeascraft/blameless-postmortems/)
- [PagerDuty Post-Mortem Guide](https://postmortems.pagerduty.com/)
- [Atlassian Incident Management](https://www.atlassian.com/incident-management/postmortem)
