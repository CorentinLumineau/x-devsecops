---
title: Escalation Reference
category: operations
type: reference
version: "1.0.0"
---

# Escalation

> Part of the operations/incident-response knowledge skill

## Overview

Escalation procedures ensure incidents reach the right people at the right time. This reference covers escalation matrices, communication protocols, and automation patterns.

## Quick Reference (80/20)

| Severity | Response Time | Escalation Trigger |
|----------|---------------|-------------------|
| P1 | 5 minutes | Immediate |
| P2 | 15 minutes | After 15 min |
| P3 | 1 hour | After 1 hour |
| P4 | 4 hours | Next business day |

## Patterns

### Pattern 1: Escalation Matrix

**When to Use**: Defining escalation paths

**Example**:
```yaml
# escalation-matrix.yaml
escalation_policies:
  # P1 - Critical: Major outage affecting >50% users
  p1_critical:
    severity: P1
    response_sla: 5m
    resolution_sla: 4h
    auto_escalate_after: 15m
    levels:
      - level: 1
        name: Primary On-Call
        contacts:
          - type: pagerduty
            schedule: primary-oncall
        timeout: 5m

      - level: 2
        name: Secondary On-Call
        contacts:
          - type: pagerduty
            schedule: secondary-oncall
          - type: slack
            channel: "#incident-response"
        timeout: 10m

      - level: 3
        name: Engineering Lead
        contacts:
          - type: pagerduty
            user: eng-lead
          - type: phone
            number: "+1-555-0100"
        timeout: 10m

      - level: 4
        name: Engineering Director
        contacts:
          - type: pagerduty
            user: eng-director
          - type: sms
            number: "+1-555-0101"
        timeout: 15m

      - level: 5
        name: Executive (CTO)
        contacts:
          - type: phone
            number: "+1-555-0102"
          - type: email
            address: cto@company.com

  # P2 - High: Significant degradation
  p2_high:
    severity: P2
    response_sla: 15m
    resolution_sla: 8h
    auto_escalate_after: 30m
    levels:
      - level: 1
        name: Primary On-Call
        contacts:
          - type: pagerduty
            schedule: primary-oncall
        timeout: 15m

      - level: 2
        name: Secondary On-Call + Team Lead
        contacts:
          - type: pagerduty
            schedule: secondary-oncall
          - type: slack
            channel: "#platform-team"
        timeout: 30m

      - level: 3
        name: Engineering Lead
        contacts:
          - type: pagerduty
            user: eng-lead
        timeout: 60m

  # P3 - Medium: Partial impact
  p3_medium:
    severity: P3
    response_sla: 1h
    resolution_sla: 24h
    auto_escalate_after: 2h
    levels:
      - level: 1
        name: Primary On-Call
        contacts:
          - type: pagerduty
            schedule: primary-oncall
          - type: slack
            channel: "#alerts"
        timeout: 1h

      - level: 2
        name: Team Lead
        contacts:
          - type: slack
            user: team-lead
          - type: email
            address: team-lead@company.com
        timeout: 2h

  # P4 - Low: Minimal impact
  p4_low:
    severity: P4
    response_sla: 4h
    resolution_sla: 72h
    auto_escalate_after: 8h
    levels:
      - level: 1
        name: Team Queue
        contacts:
          - type: slack
            channel: "#support-queue"
          - type: jira
            project: SUPPORT
        timeout: 4h

# Service-specific escalations
service_overrides:
  payments:
    escalation_policy: p1_critical
    additional_contacts:
      - type: pagerduty
        user: payments-lead
      - type: slack
        channel: "#payments-team"

  authentication:
    escalation_policy: p1_critical
    additional_contacts:
      - type: pagerduty
        user: security-oncall

# Time-based modifications
business_hours:
  timezone: America/New_York
  start: "09:00"
  end: "18:00"
  days: [mon, tue, wed, thu, fri]

after_hours_modifications:
  p3_medium:
    # Don't page after hours for P3
    levels:
      - level: 1
        contacts:
          - type: slack
            channel: "#alerts"
          - type: email
            address: oncall@company.com
```

**Anti-Pattern**: No defined escalation paths.

### Pattern 2: Automated Escalation

**When to Use**: Programmatic escalation handling

**Example**:
```typescript
// escalation-service.ts
interface EscalationPolicy {
  severity: string;
  responseSla: number; // minutes
  resolutionSla: number; // minutes
  autoEscalateAfter: number; // minutes
  levels: EscalationLevel[];
}

interface EscalationLevel {
  level: number;
  name: string;
  contacts: Contact[];
  timeout: number; // minutes
}

interface Contact {
  type: 'pagerduty' | 'slack' | 'phone' | 'sms' | 'email';
  target: string;
}

interface IncidentEscalation {
  incidentId: string;
  currentLevel: number;
  escalatedAt: Date;
  acknowledgedBy?: string;
  acknowledgedAt?: Date;
  history: EscalationEvent[];
}

interface EscalationEvent {
  level: number;
  action: 'notified' | 'acknowledged' | 'escalated' | 'resolved';
  timestamp: Date;
  contact?: string;
  note?: string;
}

class EscalationService {
  constructor(
    private pagerduty: PagerDutyClient,
    private slack: SlackClient,
    private twilio: TwilioClient,
    private email: EmailClient,
    private store: EscalationStore,
    private scheduler: SchedulerService
  ) {}

  async initiateEscalation(
    incidentId: string,
    severity: string
  ): Promise<void> {
    const policy = await this.getPolicy(severity);

    const escalation: IncidentEscalation = {
      incidentId,
      currentLevel: 1,
      escalatedAt: new Date(),
      history: []
    };

    await this.store.save(escalation);

    // Start level 1 notifications
    await this.notifyLevel(incidentId, policy, 1);

    // Schedule auto-escalation
    this.scheduleAutoEscalation(incidentId, policy);
  }

  async acknowledge(
    incidentId: string,
    acknowledgedBy: string
  ): Promise<void> {
    const escalation = await this.store.get(incidentId);
    if (!escalation) {
      throw new Error(`Escalation not found for incident ${incidentId}`);
    }

    escalation.acknowledgedBy = acknowledgedBy;
    escalation.acknowledgedAt = new Date();
    escalation.history.push({
      level: escalation.currentLevel,
      action: 'acknowledged',
      timestamp: new Date(),
      contact: acknowledgedBy
    });

    await this.store.save(escalation);

    // Cancel pending escalation timers
    this.scheduler.cancel(`escalation:${incidentId}`);

    // Notify that incident is acknowledged
    await this.slack.postMessage('#incidents', {
      text: `Incident ${incidentId} acknowledged by ${acknowledgedBy}`
    });
  }

  async escalateToNextLevel(incidentId: string): Promise<void> {
    const escalation = await this.store.get(incidentId);
    if (!escalation) {
      throw new Error(`Escalation not found for incident ${incidentId}`);
    }

    if (escalation.acknowledgedBy) {
      // Already acknowledged, don't escalate
      return;
    }

    const incident = await this.getIncident(incidentId);
    const policy = await this.getPolicy(incident.severity);

    const nextLevel = escalation.currentLevel + 1;

    if (nextLevel > policy.levels.length) {
      // Already at highest level
      await this.notifyMaxEscalation(incidentId);
      return;
    }

    escalation.currentLevel = nextLevel;
    escalation.history.push({
      level: nextLevel,
      action: 'escalated',
      timestamp: new Date(),
      note: `Auto-escalated after ${policy.levels[nextLevel - 2].timeout} minutes`
    });

    await this.store.save(escalation);
    await this.notifyLevel(incidentId, policy, nextLevel);

    // Schedule next escalation
    this.scheduleAutoEscalation(incidentId, policy);
  }

  private async notifyLevel(
    incidentId: string,
    policy: EscalationPolicy,
    level: number
  ): Promise<void> {
    const levelConfig = policy.levels[level - 1];
    const incident = await this.getIncident(incidentId);

    for (const contact of levelConfig.contacts) {
      await this.notifyContact(contact, incident, levelConfig);
    }

    // Record notification
    const escalation = await this.store.get(incidentId);
    escalation!.history.push({
      level,
      action: 'notified',
      timestamp: new Date(),
      note: `Notified ${levelConfig.name}`
    });
    await this.store.save(escalation!);
  }

  private async notifyContact(
    contact: Contact,
    incident: Incident,
    level: EscalationLevel
  ): Promise<void> {
    const message = this.formatMessage(incident, level);

    switch (contact.type) {
      case 'pagerduty':
        await this.pagerduty.createIncident({
          service: contact.target,
          title: incident.title,
          body: message,
          urgency: this.mapUrgency(incident.severity)
        });
        break;

      case 'slack':
        await this.slack.postMessage(contact.target, {
          text: message,
          attachments: [{
            color: this.getColor(incident.severity),
            fields: [
              { title: 'Severity', value: incident.severity, short: true },
              { title: 'Status', value: incident.status, short: true },
              { title: 'Escalation Level', value: level.name }
            ]
          }]
        });
        break;

      case 'phone':
        await this.twilio.call(contact.target, message);
        break;

      case 'sms':
        await this.twilio.sms(contact.target, message);
        break;

      case 'email':
        await this.email.send({
          to: contact.target,
          subject: `[${incident.severity}] ${incident.title}`,
          body: message
        });
        break;
    }
  }

  private scheduleAutoEscalation(
    incidentId: string,
    policy: EscalationPolicy
  ): void {
    const escalation = this.store.get(incidentId);

    if (!escalation) return;

    const currentLevel = policy.levels[escalation.currentLevel - 1];

    if (escalation.currentLevel < policy.levels.length) {
      this.scheduler.schedule(
        `escalation:${incidentId}`,
        currentLevel.timeout * 60 * 1000,
        () => this.escalateToNextLevel(incidentId)
      );
    }
  }

  private formatMessage(incident: Incident, level: EscalationLevel): string {
    return `
[${incident.severity}] ${incident.title}

Incident ID: ${incident.id}
Started: ${incident.startedAt.toISOString()}
Duration: ${this.calculateDuration(incident)}
Escalation Level: ${level.name}

${incident.summary}

Dashboard: ${incident.dashboardUrl}
Runbook: ${incident.runbookUrl}

To acknowledge: /incident ack ${incident.id}
`.trim();
  }

  private calculateDuration(incident: Incident): string {
    const ms = Date.now() - incident.startedAt.getTime();
    const minutes = Math.floor(ms / 60000);
    if (minutes < 60) return `${minutes} minutes`;
    const hours = Math.floor(minutes / 60);
    return `${hours}h ${minutes % 60}m`;
  }

  private mapUrgency(severity: string): 'high' | 'low' {
    return severity === 'P1' || severity === 'P2' ? 'high' : 'low';
  }

  private getColor(severity: string): string {
    const colors: Record<string, string> = {
      P1: '#FF0000',
      P2: '#FFA500',
      P3: '#FFFF00',
      P4: '#00FF00'
    };
    return colors[severity] ?? '#808080';
  }

  private async notifyMaxEscalation(incidentId: string): Promise<void> {
    await this.slack.postMessage('#incidents', {
      text: `:rotating_light: MAXIMUM ESCALATION REACHED for incident ${incidentId}. All escalation levels exhausted without acknowledgment.`
    });
  }

  private async getPolicy(severity: string): Promise<EscalationPolicy> {
    // Load from config
    return {} as EscalationPolicy;
  }

  private async getIncident(incidentId: string): Promise<Incident> {
    // Load from incident service
    return {} as Incident;
  }
}
```

**Anti-Pattern**: Manual escalation only.

### Pattern 3: Communication Templates

**When to Use**: Standardized incident communication

**Example**:
```typescript
// communication-templates.ts
interface CommunicationTemplate {
  id: string;
  name: string;
  audience: 'internal' | 'external' | 'executive';
  channels: ('slack' | 'email' | 'status_page')[];
  template: string;
}

const templates: CommunicationTemplate[] = [
  {
    id: 'incident-declared',
    name: 'Incident Declared',
    audience: 'internal',
    channels: ['slack'],
    template: `
:rotating_light: **Incident Declared**

**Title**: {{title}}
**Severity**: {{severity}}
**Incident Commander**: {{commander}}
**Started**: {{startTime}}

**Summary**: {{summary}}

**Affected Services**: {{services}}

**Links**:
- [Incident Channel](#{{incidentChannel}})
- [Dashboard]({{dashboardUrl}})
- [Runbook]({{runbookUrl}})

React with :eyes: if you're joining the response.
`.trim()
  },

  {
    id: 'status-update-internal',
    name: 'Internal Status Update',
    audience: 'internal',
    channels: ['slack'],
    template: `
:information_source: **Status Update** ({{updateNumber}})

**Incident**: {{title}}
**Current Status**: {{status}}
**Duration**: {{duration}}

**Update**:
{{updateText}}

**Next Steps**:
{{nextSteps}}

**ETA to Resolution**: {{eta}}
`.trim()
  },

  {
    id: 'status-update-external',
    name: 'External Status Update',
    audience: 'external',
    channels: ['status_page', 'email'],
    template: `
**{{title}}**

We are currently {{status}} an issue affecting {{affectedFeatures}}.

**Impact**: {{impactDescription}}

**Current Status**: {{statusDescription}}

We are actively working to resolve this issue. The next update will be provided in {{nextUpdateTime}}.

We apologize for any inconvenience this may cause.
`.trim()
  },

  {
    id: 'incident-resolved',
    name: 'Incident Resolved',
    audience: 'internal',
    channels: ['slack'],
    template: `
:white_check_mark: **Incident Resolved**

**Title**: {{title}}
**Duration**: {{duration}}
**Resolved By**: {{resolvedBy}}

**Resolution Summary**:
{{resolutionSummary}}

**Root Cause** (preliminary):
{{rootCause}}

**Post-Mortem**: {{postMortemDate}}

Thank you to everyone who helped respond:
{{responders}}
`.trim()
  },

  {
    id: 'executive-brief',
    name: 'Executive Brief',
    audience: 'executive',
    channels: ['email', 'slack'],
    template: `
**Executive Incident Brief**

**Incident**: {{title}}
**Severity**: {{severity}}
**Duration**: {{duration}}
**Status**: {{status}}

**Business Impact**:
- Users Affected: {{usersAffected}}
- Revenue Impact: {{revenueImpact}}
- SLA Status: {{slaStatus}}

**Summary**:
{{executiveSummary}}

**Resolution** (if resolved):
{{resolution}}

**Follow-up Actions**:
{{followUpActions}}

**Next Update**: {{nextUpdate}}
`.trim()
  },

  {
    id: 'escalation-notice',
    name: 'Escalation Notice',
    audience: 'internal',
    channels: ['slack', 'email'],
    template: `
:arrow_up: **Escalation Notice**

**Incident**: {{title}}
**Previous Level**: {{previousLevel}}
**Current Level**: {{currentLevel}}
**Reason**: {{escalationReason}}

**Current Status**:
{{currentStatus}}

**Why Escalated**:
{{escalationReason}}

**Action Required**:
{{actionRequired}}

Please acknowledge within {{responseTime}}.
`.trim()
  }
];

class CommunicationService {
  constructor(
    private slack: SlackClient,
    private email: EmailClient,
    private statusPage: StatusPageClient,
    private templateEngine: TemplateEngine
  ) {}

  async send(
    templateId: string,
    data: Record<string, any>,
    overrides?: { channels?: string[]; recipients?: string[] }
  ): Promise<void> {
    const template = templates.find(t => t.id === templateId);
    if (!template) {
      throw new Error(`Template ${templateId} not found`);
    }

    const content = this.templateEngine.render(template.template, data);
    const channels = overrides?.channels ?? template.channels;

    for (const channel of channels) {
      switch (channel) {
        case 'slack':
          await this.sendSlack(content, data, template.audience);
          break;

        case 'email':
          await this.sendEmail(content, data, template.audience, overrides?.recipients);
          break;

        case 'status_page':
          await this.updateStatusPage(content, data);
          break;
      }
    }
  }

  private async sendSlack(
    content: string,
    data: Record<string, any>,
    audience: string
  ): Promise<void> {
    const channel = this.getSlackChannel(audience, data);

    await this.slack.postMessage(channel, {
      text: content,
      unfurl_links: false
    });
  }

  private async sendEmail(
    content: string,
    data: Record<string, any>,
    audience: string,
    recipients?: string[]
  ): Promise<void> {
    const to = recipients ?? this.getEmailRecipients(audience);

    await this.email.send({
      to,
      subject: `[${data.severity}] ${data.title}`,
      body: content
    });
  }

  private async updateStatusPage(
    content: string,
    data: Record<string, any>
  ): Promise<void> {
    await this.statusPage.createOrUpdateIncident({
      name: data.title,
      status: this.mapStatusPageStatus(data.status),
      body: content,
      components: data.affectedComponents,
      componentStatus: this.mapComponentStatus(data.status)
    });
  }

  private getSlackChannel(audience: string, data: Record<string, any>): string {
    switch (audience) {
      case 'internal':
        return data.incidentChannel ?? '#incidents';
      case 'executive':
        return '#executive-alerts';
      default:
        return '#incidents';
    }
  }

  private getEmailRecipients(audience: string): string[] {
    switch (audience) {
      case 'executive':
        return ['cto@company.com', 'ceo@company.com', 'vp-eng@company.com'];
      case 'internal':
        return ['engineering@company.com'];
      default:
        return [];
    }
  }

  private mapStatusPageStatus(status: string): string {
    const mapping: Record<string, string> = {
      investigating: 'investigating',
      identified: 'identified',
      monitoring: 'monitoring',
      resolved: 'resolved'
    };
    return mapping[status] ?? 'investigating';
  }

  private mapComponentStatus(status: string): string {
    const mapping: Record<string, string> = {
      investigating: 'major_outage',
      identified: 'partial_outage',
      monitoring: 'degraded_performance',
      resolved: 'operational'
    };
    return mapping[status] ?? 'major_outage';
  }
}

// Usage
const comms = new CommunicationService(slack, email, statusPage, templates);

// Declare incident
await comms.send('incident-declared', {
  title: 'API Latency Degradation',
  severity: 'P2',
  commander: '@oncall-engineer',
  startTime: '2024-01-15 14:00 UTC',
  summary: 'API response times elevated across all endpoints',
  services: 'api-gateway, user-service',
  incidentChannel: 'inc-20240115-api',
  dashboardUrl: 'https://grafana.example.com/d/api',
  runbookUrl: 'https://wiki.example.com/runbooks/api-latency'
});

// External update
await comms.send('status-update-external', {
  title: 'Service Degradation',
  status: 'investigating',
  affectedFeatures: 'API and Dashboard',
  impactDescription: 'Some users may experience slow response times',
  statusDescription: 'Our team is actively investigating the issue',
  nextUpdateTime: '30 minutes'
});
```

**Anti-Pattern**: Ad-hoc communication during incidents.

### Pattern 4: On-Call Handoff

**When to Use**: Transferring incident ownership

**Example**:
```typescript
// handoff-service.ts
interface HandoffContext {
  incidentId: string;
  fromEngineer: string;
  toEngineer: string;
  reason: 'shift_change' | 'expertise' | 'fatigue' | 'unavailable';
  handoffTime: Date;
}

interface HandoffBriefing {
  incident: IncidentSummary;
  currentStatus: string;
  actionsCompleted: string[];
  actionsInProgress: string[];
  blockers: string[];
  hypotheses: string[];
  nextSteps: string[];
  contacts: Contact[];
  resources: Resource[];
}

class HandoffService {
  constructor(
    private incidentService: IncidentService,
    private slack: SlackClient,
    private pagerduty: PagerDutyClient
  ) {}

  async initiateHandoff(context: HandoffContext): Promise<void> {
    // Generate briefing
    const briefing = await this.generateBriefing(context.incidentId);

    // Post handoff in incident channel
    await this.postHandoffAnnouncement(context, briefing);

    // Update incident ownership
    await this.incidentService.updateCommander(
      context.incidentId,
      context.toEngineer
    );

    // Transfer PagerDuty acknowledgment
    await this.pagerduty.reassign(
      context.incidentId,
      context.toEngineer
    );

    // Schedule sync call if needed
    if (this.requiresSyncCall(context)) {
      await this.scheduleSyncCall(context);
    }
  }

  private async generateBriefing(incidentId: string): Promise<HandoffBriefing> {
    const incident = await this.incidentService.get(incidentId);
    const timeline = await this.incidentService.getTimeline(incidentId);
    const notes = await this.incidentService.getNotes(incidentId);

    return {
      incident: {
        id: incident.id,
        title: incident.title,
        severity: incident.severity,
        startedAt: incident.startedAt,
        duration: this.calculateDuration(incident.startedAt)
      },
      currentStatus: incident.status,
      actionsCompleted: this.extractCompletedActions(timeline),
      actionsInProgress: this.extractInProgressActions(notes),
      blockers: this.extractBlockers(notes),
      hypotheses: this.extractHypotheses(notes),
      nextSteps: this.extractNextSteps(notes),
      contacts: this.extractContacts(incident),
      resources: this.extractResources(incident)
    };
  }

  private async postHandoffAnnouncement(
    context: HandoffContext,
    briefing: HandoffBriefing
  ): Promise<void> {
    const channel = `#inc-${context.incidentId}`;

    await this.slack.postMessage(channel, {
      text: `
:handshake: **Incident Handoff**

**From**: @${context.fromEngineer}
**To**: @${context.toEngineer}
**Reason**: ${this.formatReason(context.reason)}
**Time**: ${context.handoffTime.toISOString()}

---

**Briefing for @${context.toEngineer}:**

**Current Status**: ${briefing.currentStatus}
**Duration**: ${briefing.incident.duration}

**Completed Actions**:
${briefing.actionsCompleted.map(a => `- ${a}`).join('\n')}

**In Progress**:
${briefing.actionsInProgress.map(a => `- ${a}`).join('\n')}

**Blockers**:
${briefing.blockers.length > 0 ? briefing.blockers.map(b => `- :warning: ${b}`).join('\n') : 'None'}

**Current Hypotheses**:
${briefing.hypotheses.map(h => `- ${h}`).join('\n')}

**Recommended Next Steps**:
${briefing.nextSteps.map((s, i) => `${i + 1}. ${s}`).join('\n')}

**Key Contacts**:
${briefing.contacts.map(c => `- ${c.role}: @${c.name}`).join('\n')}

**Resources**:
${briefing.resources.map(r => `- [${r.name}](${r.url})`).join('\n')}

---

@${context.toEngineer} please confirm receipt with :white_check_mark:
      `.trim()
    });
  }

  private formatReason(reason: HandoffContext['reason']): string {
    const reasons = {
      shift_change: 'End of shift',
      expertise: 'Subject matter expertise needed',
      fatigue: 'Responder fatigue',
      unavailable: 'Responder unavailable'
    };
    return reasons[reason];
  }

  private requiresSyncCall(context: HandoffContext): boolean {
    // Complex incidents or expertise handoffs need sync calls
    return context.reason === 'expertise';
  }

  private async scheduleSyncCall(context: HandoffContext): Promise<void> {
    // Create a quick sync meeting
    await this.slack.postMessage(`#inc-${context.incidentId}`, {
      text: `
:telephone_receiver: A sync call has been scheduled for the handoff.
Join: https://meet.example.com/incident-${context.incidentId}
Time: Now
Duration: 5-10 minutes
      `.trim()
    });
  }

  private calculateDuration(startedAt: Date): string {
    const ms = Date.now() - startedAt.getTime();
    const hours = Math.floor(ms / 3600000);
    const minutes = Math.floor((ms % 3600000) / 60000);
    return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
  }

  private extractCompletedActions(timeline: TimelineEvent[]): string[] {
    return timeline
      .filter(e => e.type === 'action' && e.status === 'completed')
      .map(e => e.description);
  }

  private extractInProgressActions(notes: Note[]): string[] {
    return notes
      .filter(n => n.type === 'action' && n.status === 'in_progress')
      .map(n => n.content);
  }

  private extractBlockers(notes: Note[]): string[] {
    return notes
      .filter(n => n.type === 'blocker')
      .map(n => n.content);
  }

  private extractHypotheses(notes: Note[]): string[] {
    return notes
      .filter(n => n.type === 'hypothesis')
      .map(n => n.content);
  }

  private extractNextSteps(notes: Note[]): string[] {
    return notes
      .filter(n => n.type === 'next_step')
      .map(n => n.content);
  }

  private extractContacts(incident: Incident): Contact[] {
    return incident.responders.map(r => ({
      name: r.name,
      role: r.role
    }));
  }

  private extractResources(incident: Incident): Resource[] {
    return [
      { name: 'Dashboard', url: incident.dashboardUrl },
      { name: 'Runbook', url: incident.runbookUrl },
      { name: 'Timeline', url: incident.timelineUrl }
    ].filter(r => r.url);
  }
}
```

**Anti-Pattern**: Handoffs without context transfer.

### Pattern 5: Severity Classification

**When to Use**: Determining incident priority

**Example**:
```typescript
// severity-classifier.ts
interface SeverityFactors {
  userImpact: UserImpactLevel;
  serviceImpact: ServiceImpactLevel;
  dataRisk: DataRiskLevel;
  financialImpact: FinancialImpactLevel;
  reputationalRisk: ReputationalRiskLevel;
}

type UserImpactLevel =
  | 'none'        // No users affected
  | 'minimal'     // <1% of users
  | 'partial'     // 1-10% of users
  | 'significant' // 10-50% of users
  | 'widespread'; // >50% of users

type ServiceImpactLevel =
  | 'none'        // No service impact
  | 'degraded'    // Slow but functional
  | 'partial'     // Some features unavailable
  | 'major'       // Core features unavailable
  | 'complete';   // Total outage

type DataRiskLevel =
  | 'none'        // No data at risk
  | 'exposure'    // Data might be exposed
  | 'corruption'  // Data might be corrupted
  | 'loss';       // Data loss occurring

type FinancialImpactLevel =
  | 'none'        // No financial impact
  | 'low'         // <$1k/hour
  | 'medium'      // $1k-10k/hour
  | 'high'        // $10k-100k/hour
  | 'severe';     // >$100k/hour

type ReputationalRiskLevel =
  | 'none'        // Internal only
  | 'low'         // Few customers notice
  | 'medium'      // Customers complaining
  | 'high'        // Media attention possible
  | 'severe';     // Media attention likely

class SeverityClassifier {
  classify(factors: SeverityFactors): 'P1' | 'P2' | 'P3' | 'P4' {
    const scores = {
      user: this.scoreUserImpact(factors.userImpact),
      service: this.scoreServiceImpact(factors.serviceImpact),
      data: this.scoreDataRisk(factors.dataRisk),
      financial: this.scoreFinancialImpact(factors.financialImpact),
      reputation: this.scoreReputationalRisk(factors.reputationalRisk)
    };

    const maxScore = Math.max(...Object.values(scores));
    const avgScore = Object.values(scores).reduce((a, b) => a + b, 0) / 5;

    // P1 if any factor is critical or multiple high factors
    if (maxScore === 5 || (maxScore >= 4 && avgScore >= 3)) {
      return 'P1';
    }

    // P2 if any factor is high or multiple medium factors
    if (maxScore >= 4 || (maxScore >= 3 && avgScore >= 2.5)) {
      return 'P2';
    }

    // P3 if any factor is medium
    if (maxScore >= 3 || avgScore >= 2) {
      return 'P3';
    }

    // P4 for minimal impact
    return 'P4';
  }

  private scoreUserImpact(level: UserImpactLevel): number {
    const scores: Record<UserImpactLevel, number> = {
      none: 1,
      minimal: 2,
      partial: 3,
      significant: 4,
      widespread: 5
    };
    return scores[level];
  }

  private scoreServiceImpact(level: ServiceImpactLevel): number {
    const scores: Record<ServiceImpactLevel, number> = {
      none: 1,
      degraded: 2,
      partial: 3,
      major: 4,
      complete: 5
    };
    return scores[level];
  }

  private scoreDataRisk(level: DataRiskLevel): number {
    const scores: Record<DataRiskLevel, number> = {
      none: 1,
      exposure: 3,
      corruption: 4,
      loss: 5
    };
    return scores[level];
  }

  private scoreFinancialImpact(level: FinancialImpactLevel): number {
    const scores: Record<FinancialImpactLevel, number> = {
      none: 1,
      low: 2,
      medium: 3,
      high: 4,
      severe: 5
    };
    return scores[level];
  }

  private scoreReputationalRisk(level: ReputationalRiskLevel): number {
    const scores: Record<ReputationalRiskLevel, number> = {
      none: 1,
      low: 2,
      medium: 3,
      high: 4,
      severe: 5
    };
    return scores[level];
  }

  getSeverityDescription(severity: 'P1' | 'P2' | 'P3' | 'P4'): string {
    const descriptions = {
      P1: 'Critical - Immediate response required. Major outage or data incident.',
      P2: 'High - Urgent response required. Significant impact on users or revenue.',
      P3: 'Medium - Response within business hours. Partial impact, workarounds available.',
      P4: 'Low - Queue for next available engineer. Minimal impact.'
    };
    return descriptions[severity];
  }

  getExpectedResponse(severity: 'P1' | 'P2' | 'P3' | 'P4'): {
    response: string;
    resolution: string;
    updates: string;
  } {
    const expectations = {
      P1: {
        response: '5 minutes',
        resolution: '4 hours',
        updates: 'Every 15 minutes'
      },
      P2: {
        response: '15 minutes',
        resolution: '8 hours',
        updates: 'Every 30 minutes'
      },
      P3: {
        response: '1 hour',
        resolution: '24 hours',
        updates: 'Every 2 hours'
      },
      P4: {
        response: '4 hours',
        resolution: '72 hours',
        updates: 'Daily'
      }
    };
    return expectations[severity];
  }
}

// Interactive classification
async function classifyInteractively(): Promise<SeverityFactors> {
  const questions = [
    {
      name: 'userImpact',
      prompt: 'User Impact',
      options: ['none', 'minimal (<1%)', 'partial (1-10%)', 'significant (10-50%)', 'widespread (>50%)']
    },
    {
      name: 'serviceImpact',
      prompt: 'Service Impact',
      options: ['none', 'degraded', 'partial', 'major', 'complete outage']
    },
    {
      name: 'dataRisk',
      prompt: 'Data Risk',
      options: ['none', 'exposure possible', 'corruption possible', 'loss occurring']
    },
    {
      name: 'financialImpact',
      prompt: 'Financial Impact',
      options: ['none', 'low (<$1k/hr)', 'medium ($1k-10k/hr)', 'high ($10k-100k/hr)', 'severe (>$100k/hr)']
    },
    {
      name: 'reputationalRisk',
      prompt: 'Reputational Risk',
      options: ['none', 'low', 'medium', 'high', 'severe (media likely)']
    }
  ];

  // In practice, this would be a Slack workflow or web form
  return {} as SeverityFactors;
}
```

**Anti-Pattern**: Subjective severity without criteria.

## Checklist

- [ ] Escalation matrix documented
- [ ] Contact information current
- [ ] Auto-escalation configured
- [ ] Communication templates ready
- [ ] Handoff procedures defined
- [ ] Severity criteria clear
- [ ] SLAs defined per severity
- [ ] After-hours procedures set
- [ ] Service-specific overrides documented
- [ ] Regular escalation drills conducted

## References

- [PagerDuty Escalation Policies](https://support.pagerduty.com/docs/escalation-policies)
- [Google SRE On-Call](https://sre.google/sre-book/being-on-call/)
- [Incident Response Guide](https://response.pagerduty.com/)
- [Atlassian Incident Severity](https://www.atlassian.com/incident-management/kpis/severity-levels)
