---
title: Prioritization Reference
category: meta
type: reference
version: "1.0.0"
---

# Prioritization

> Part of the meta/analysis knowledge skill

## Overview

Effective prioritization ensures teams focus on highest-impact work. This reference covers prioritization frameworks, scoring methods, and decision-making tools.

## Quick Reference (80/20)

| Framework | Best For |
|-----------|----------|
| RICE | Product features |
| MoSCoW | Requirements |
| Eisenhower | Time management |
| WSJF | Agile planning |
| Value vs Effort | Quick decisions |

## Patterns

### Pattern 1: RICE Scoring

**When to Use**: Product feature prioritization

**Example**:
```typescript
// rice-scoring.ts
interface RICEScore {
  reach: number;       // Users affected per quarter
  impact: number;      // Impact score (0.25, 0.5, 1, 2, 3)
  confidence: number;  // Confidence percentage (0.5, 0.8, 1.0)
  effort: number;      // Person-months
}

interface Feature {
  id: string;
  name: string;
  description: string;
  scores: RICEScore;
  riceScore?: number;
}

class RICECalculator {
  // Impact scale:
  // 3 = Massive impact
  // 2 = High impact
  // 1 = Medium impact
  // 0.5 = Low impact
  // 0.25 = Minimal impact

  calculateScore(scores: RICEScore): number {
    const { reach, impact, confidence, effort } = scores;
    return (reach * impact * confidence) / effort;
  }

  rankFeatures(features: Feature[]): Feature[] {
    return features
      .map(feature => ({
        ...feature,
        riceScore: this.calculateScore(feature.scores)
      }))
      .sort((a, b) => (b.riceScore ?? 0) - (a.riceScore ?? 0));
  }

  estimateReach(metrics: {
    totalUsers: number;
    usagePercentage: number;
    frequencyPerQuarter: number;
  }): number {
    return Math.round(
      metrics.totalUsers *
      metrics.usagePercentage *
      metrics.frequencyPerQuarter
    );
  }

  estimateImpact(factors: {
    revenueImpact: 'none' | 'low' | 'medium' | 'high' | 'massive';
    userSatisfaction: 'none' | 'low' | 'medium' | 'high' | 'massive';
    strategicAlignment: 'none' | 'low' | 'medium' | 'high';
  }): number {
    const impactMap = {
      none: 0,
      low: 0.5,
      medium: 1,
      high: 2,
      massive: 3
    };

    const scores = [
      impactMap[factors.revenueImpact],
      impactMap[factors.userSatisfaction],
      impactMap[factors.strategicAlignment] ?? 0
    ];

    return scores.reduce((a, b) => a + b, 0) / scores.length;
  }

  estimateConfidence(factors: {
    hasUserResearch: boolean;
    hasPrototype: boolean;
    hasTechnicalSpike: boolean;
    hasCompetitorData: boolean;
  }): number {
    let confidence = 0.5; // Base confidence

    if (factors.hasUserResearch) confidence += 0.15;
    if (factors.hasPrototype) confidence += 0.15;
    if (factors.hasTechnicalSpike) confidence += 0.1;
    if (factors.hasCompetitorData) confidence += 0.1;

    return Math.min(confidence, 1.0);
  }

  estimateEffort(tasks: {
    design: number;      // Person-days
    frontend: number;    // Person-days
    backend: number;     // Person-days
    qa: number;          // Person-days
    deployment: number;  // Person-days
  }): number {
    const totalDays = Object.values(tasks).reduce((a, b) => a + b, 0);
    return totalDays / 20; // Convert to person-months (20 working days)
  }
}

// Example usage
const calculator = new RICECalculator();

const features: Feature[] = [
  {
    id: 'feat-1',
    name: 'One-click checkout',
    description: 'Streamline checkout to single click for returning users',
    scores: {
      reach: calculator.estimateReach({
        totalUsers: 100000,
        usagePercentage: 0.3,
        frequencyPerQuarter: 4
      }),
      impact: calculator.estimateImpact({
        revenueImpact: 'high',
        userSatisfaction: 'high',
        strategicAlignment: 'high'
      }),
      confidence: calculator.estimateConfidence({
        hasUserResearch: true,
        hasPrototype: true,
        hasTechnicalSpike: false,
        hasCompetitorData: true
      }),
      effort: calculator.estimateEffort({
        design: 5,
        frontend: 10,
        backend: 15,
        qa: 5,
        deployment: 2
      })
    }
  },
  {
    id: 'feat-2',
    name: 'Dark mode',
    description: 'Add dark theme option',
    scores: {
      reach: 50000,
      impact: 0.5,
      confidence: 0.8,
      effort: 1
    }
  }
];

const ranked = calculator.rankFeatures(features);
console.table(ranked.map(f => ({
  name: f.name,
  reach: f.scores.reach,
  impact: f.scores.impact,
  confidence: f.scores.confidence,
  effort: f.scores.effort,
  riceScore: f.riceScore?.toFixed(0)
})));
```

**Anti-Pattern**: Inconsistent scoring criteria.

### Pattern 2: MoSCoW Method

**When to Use**: Requirements prioritization

**Example**:
```typescript
// moscow-prioritization.ts
type MoSCoWCategory = 'must' | 'should' | 'could' | 'wont';

interface Requirement {
  id: string;
  title: string;
  description: string;
  category: MoSCoWCategory;
  rationale: string;
  dependencies: string[];
  estimate?: number;
}

interface MoSCoWAnalysis {
  must: Requirement[];
  should: Requirement[];
  could: Requirement[];
  wont: Requirement[];
  summary: {
    totalEffort: number;
    mustEffort: number;
    shouldEffort: number;
    couldEffort: number;
  };
}

class MoSCoWPrioritizer {
  // Must Have: Critical for delivery, non-negotiable
  // Should Have: Important but not vital
  // Could Have: Nice to have, low impact if excluded
  // Won't Have: Not in this release

  private requirements: Requirement[] = [];

  addRequirement(req: Requirement): void {
    this.requirements.push(req);
  }

  categorize(
    id: string,
    category: MoSCoWCategory,
    rationale: string
  ): void {
    const req = this.requirements.find(r => r.id === id);
    if (req) {
      req.category = category;
      req.rationale = rationale;
    }
  }

  analyze(): MoSCoWAnalysis {
    const grouped = {
      must: this.requirements.filter(r => r.category === 'must'),
      should: this.requirements.filter(r => r.category === 'should'),
      could: this.requirements.filter(r => r.category === 'could'),
      wont: this.requirements.filter(r => r.category === 'wont')
    };

    const sumEffort = (reqs: Requirement[]) =>
      reqs.reduce((sum, r) => sum + (r.estimate ?? 0), 0);

    return {
      ...grouped,
      summary: {
        totalEffort: sumEffort(this.requirements),
        mustEffort: sumEffort(grouped.must),
        shouldEffort: sumEffort(grouped.should),
        couldEffort: sumEffort(grouped.could)
      }
    };
  }

  validateCapacity(availableCapacity: number): {
    fits: boolean;
    mustFits: boolean;
    recommendation: string;
  } {
    const analysis = this.analyze();

    const mustFits = analysis.summary.mustEffort <= availableCapacity;
    const mustShouldFits =
      analysis.summary.mustEffort + analysis.summary.shouldEffort <= availableCapacity;

    let recommendation: string;
    if (!mustFits) {
      recommendation = 'CRITICAL: Must-haves exceed capacity. Re-evaluate scope.';
    } else if (mustShouldFits) {
      recommendation = 'Good: Can deliver Must + Should haves.';
    } else {
      recommendation = 'Can deliver Must-haves. Prioritize Should-haves.';
    }

    return {
      fits: mustShouldFits,
      mustFits,
      recommendation
    };
  }

  generateReport(): string {
    const analysis = this.analyze();
    const validation = this.validateCapacity(100); // Assuming 100 points capacity

    return `
# MoSCoW Analysis Report

## Summary

| Category | Count | Effort |
|----------|-------|--------|
| Must Have | ${analysis.must.length} | ${analysis.summary.mustEffort} |
| Should Have | ${analysis.should.length} | ${analysis.summary.shouldEffort} |
| Could Have | ${analysis.could.length} | ${analysis.summary.couldEffort} |
| Won't Have | ${analysis.wont.length} | - |

## Capacity Analysis

${validation.recommendation}

## Must Have Requirements

${analysis.must.map(r => `
### ${r.id}: ${r.title}

${r.description}

**Rationale**: ${r.rationale}
**Estimate**: ${r.estimate ?? 'TBD'} points
${r.dependencies.length > 0 ? `**Dependencies**: ${r.dependencies.join(', ')}` : ''}
`).join('\n')}

## Should Have Requirements

${analysis.should.map(r => `- **${r.id}**: ${r.title} (${r.estimate ?? 'TBD'} points)`).join('\n')}

## Could Have Requirements

${analysis.could.map(r => `- **${r.id}**: ${r.title} (${r.estimate ?? 'TBD'} points)`).join('\n')}

## Won't Have (This Release)

${analysis.wont.map(r => `- **${r.id}**: ${r.title} - ${r.rationale}`).join('\n')}
    `.trim();
  }
}

// Example
const prioritizer = new MoSCoWPrioritizer();

prioritizer.addRequirement({
  id: 'REQ-001',
  title: 'User Authentication',
  description: 'Users must be able to log in securely',
  category: 'must',
  rationale: 'Core security requirement',
  dependencies: [],
  estimate: 20
});

prioritizer.addRequirement({
  id: 'REQ-002',
  title: 'Password Reset',
  description: 'Users can reset forgotten passwords',
  category: 'must',
  rationale: 'Essential for user access recovery',
  dependencies: ['REQ-001'],
  estimate: 10
});

prioritizer.addRequirement({
  id: 'REQ-003',
  title: 'Social Login',
  description: 'Login via Google/GitHub',
  category: 'should',
  rationale: 'Improves UX but not blocking',
  dependencies: ['REQ-001'],
  estimate: 15
});

prioritizer.addRequirement({
  id: 'REQ-004',
  title: 'Biometric Login',
  description: 'Face ID / Fingerprint',
  category: 'could',
  rationale: 'Nice to have for mobile',
  dependencies: ['REQ-001'],
  estimate: 25
});

console.log(prioritizer.generateReport());
```

**Anti-Pattern**: Too many "must haves".

### Pattern 3: Weighted Shortest Job First (WSJF)

**When to Use**: SAFe/Agile prioritization

**Example**:
```typescript
// wsjf-scoring.ts
interface WSJFItem {
  id: string;
  name: string;
  userBusinessValue: number;  // 1-10
  timeCriticality: number;    // 1-10
  riskReduction: number;      // 1-10 (Risk Reduction/Opportunity Enablement)
  jobSize: number;            // Relative size (1, 2, 3, 5, 8, 13)
  wsjfScore?: number;
  costOfDelay?: number;
}

class WSJFCalculator {
  // Cost of Delay = User/Business Value + Time Criticality + Risk Reduction
  // WSJF = Cost of Delay / Job Size

  calculateCostOfDelay(item: WSJFItem): number {
    return item.userBusinessValue + item.timeCriticality + item.riskReduction;
  }

  calculateWSJF(item: WSJFItem): number {
    const costOfDelay = this.calculateCostOfDelay(item);
    return costOfDelay / item.jobSize;
  }

  rankItems(items: WSJFItem[]): WSJFItem[] {
    return items
      .map(item => ({
        ...item,
        costOfDelay: this.calculateCostOfDelay(item),
        wsjfScore: this.calculateWSJF(item)
      }))
      .sort((a, b) => (b.wsjfScore ?? 0) - (a.wsjfScore ?? 0));
  }

  // Relative estimation using Fibonacci
  estimateJobSize(complexity: {
    technical: 'trivial' | 'simple' | 'moderate' | 'complex' | 'very-complex';
    uncertainty: 'low' | 'medium' | 'high';
    dependencies: number;
  }): number {
    const complexityMap = {
      trivial: 1,
      simple: 2,
      moderate: 3,
      complex: 5,
      'very-complex': 8
    };

    const uncertaintyMultiplier = {
      low: 1,
      medium: 1.5,
      high: 2
    };

    const dependencyFactor = 1 + (complexity.dependencies * 0.2);

    const base = complexityMap[complexity.technical];
    const adjusted = base * uncertaintyMultiplier[complexity.uncertainty] * dependencyFactor;

    // Round to nearest Fibonacci
    const fibonacci = [1, 2, 3, 5, 8, 13, 21];
    return fibonacci.reduce((prev, curr) =>
      Math.abs(curr - adjusted) < Math.abs(prev - adjusted) ? curr : prev
    );
  }

  // Guide for scoring
  scoringGuide = {
    userBusinessValue: {
      10: 'Critical to business success',
      8: 'Significant revenue/user impact',
      5: 'Moderate business value',
      3: 'Some business value',
      1: 'Minimal business value'
    },
    timeCriticality: {
      10: 'Urgent - losing value daily',
      8: 'High urgency - weeks matter',
      5: 'Moderate urgency - quarter matters',
      3: 'Low urgency - can wait',
      1: 'No time pressure'
    },
    riskReduction: {
      10: 'Enables multiple high-value features',
      8: 'Significant risk mitigation',
      5: 'Moderate enablement/risk reduction',
      3: 'Some enablement value',
      1: 'No risk/enablement value'
    }
  };

  generateMatrix(items: WSJFItem[]): string {
    const ranked = this.rankItems(items);

    return `
# WSJF Prioritization Matrix

| Rank | Item | Business Value | Time Critical | Risk/Opp | CoD | Size | WSJF |
|------|------|----------------|---------------|----------|-----|------|------|
${ranked.map((item, i) => `| ${i + 1} | ${item.name} | ${item.userBusinessValue} | ${item.timeCriticality} | ${item.riskReduction} | ${item.costOfDelay} | ${item.jobSize} | ${item.wsjfScore?.toFixed(1)} |`).join('\n')}

## Recommended Sequence

${ranked.map((item, i) => `${i + 1}. **${item.name}** (WSJF: ${item.wsjfScore?.toFixed(1)})`).join('\n')}

## Key Insights

- Highest CoD: ${ranked.reduce((max, item) => (item.costOfDelay ?? 0) > (max.costOfDelay ?? 0) ? item : max, ranked[0]).name}
- Smallest Job: ${ranked.reduce((min, item) => item.jobSize < min.jobSize ? item : min, ranked[0]).name}
- Best WSJF: ${ranked[0].name}
    `.trim();
  }
}

// Example
const wsjf = new WSJFCalculator();

const backlog: WSJFItem[] = [
  {
    id: 'FEAT-1',
    name: 'Payment Integration',
    userBusinessValue: 9,
    timeCriticality: 8,
    riskReduction: 7,
    jobSize: 8
  },
  {
    id: 'FEAT-2',
    name: 'Email Notifications',
    userBusinessValue: 5,
    timeCriticality: 3,
    riskReduction: 2,
    jobSize: 3
  },
  {
    id: 'FEAT-3',
    name: 'Performance Optimization',
    userBusinessValue: 6,
    timeCriticality: 7,
    riskReduction: 8,
    jobSize: 5
  }
];

console.log(wsjf.generateMatrix(backlog));
```

**Anti-Pattern**: Comparing WSJF across different teams.

### Pattern 4: Eisenhower Matrix

**When to Use**: Personal/team task prioritization

**Example**:
```typescript
// eisenhower-matrix.ts
type Quadrant = 'do' | 'schedule' | 'delegate' | 'eliminate';

interface Task {
  id: string;
  title: string;
  urgent: boolean;
  important: boolean;
  quadrant?: Quadrant;
  dueDate?: Date;
  delegateTo?: string;
}

class EisenhowerMatrix {
  // Q1: Urgent + Important = DO (Crises, deadlines)
  // Q2: Not Urgent + Important = SCHEDULE (Planning, growth)
  // Q3: Urgent + Not Important = DELEGATE (Interruptions)
  // Q4: Not Urgent + Not Important = ELIMINATE (Time wasters)

  categorize(task: Task): Quadrant {
    if (task.urgent && task.important) return 'do';
    if (!task.urgent && task.important) return 'schedule';
    if (task.urgent && !task.important) return 'delegate';
    return 'eliminate';
  }

  organizeTasks(tasks: Task[]): Record<Quadrant, Task[]> {
    const matrix: Record<Quadrant, Task[]> = {
      do: [],
      schedule: [],
      delegate: [],
      eliminate: []
    };

    for (const task of tasks) {
      const quadrant = this.categorize(task);
      task.quadrant = quadrant;
      matrix[quadrant].push(task);
    }

    // Sort Q1 by due date
    matrix.do.sort((a, b) =>
      (a.dueDate?.getTime() ?? Infinity) - (b.dueDate?.getTime() ?? Infinity)
    );

    return matrix;
  }

  assessUrgency(task: {
    dueDate?: Date;
    hasExternalDeadline: boolean;
    blocksOthers: boolean;
    requestedUrgently: boolean;
  }): boolean {
    if (task.dueDate) {
      const daysUntilDue = (task.dueDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24);
      if (daysUntilDue <= 2) return true;
    }

    return task.hasExternalDeadline || task.blocksOthers || task.requestedUrgently;
  }

  assessImportance(task: {
    alignsWithGoals: boolean;
    hasLongTermImpact: boolean;
    affectsKeyMetrics: boolean;
    isStrategic: boolean;
  }): boolean {
    const score =
      (task.alignsWithGoals ? 1 : 0) +
      (task.hasLongTermImpact ? 1 : 0) +
      (task.affectsKeyMetrics ? 1 : 0) +
      (task.isStrategic ? 1 : 0);

    return score >= 2;
  }

  generateActionPlan(tasks: Task[]): string {
    const matrix = this.organizeTasks(tasks);

    return `
# Eisenhower Matrix Action Plan

## Q1: DO NOW (Urgent + Important)
${matrix.do.length > 0
  ? matrix.do.map(t => `- [ ] ${t.title}${t.dueDate ? ` (Due: ${t.dueDate.toLocaleDateString()})` : ''}`).join('\n')
  : 'No urgent important tasks'}

**Action**: Focus on these immediately. Block time today.

## Q2: SCHEDULE (Not Urgent + Important)
${matrix.schedule.length > 0
  ? matrix.schedule.map(t => `- [ ] ${t.title}`).join('\n')
  : 'No tasks to schedule'}

**Action**: Block specific time slots for these. These drive long-term success.

## Q3: DELEGATE (Urgent + Not Important)
${matrix.delegate.length > 0
  ? matrix.delegate.map(t => `- [ ] ${t.title}${t.delegateTo ? ` -> @${t.delegateTo}` : ' (Find delegate)'}`).join('\n')
  : 'No tasks to delegate'}

**Action**: Assign to appropriate team member or automate.

## Q4: ELIMINATE (Not Urgent + Not Important)
${matrix.eliminate.length > 0
  ? matrix.eliminate.map(t => `- ~${t.title}~`).join('\n')
  : 'No tasks to eliminate'}

**Action**: Remove from list or batch for minimal time investment.

## Summary

| Quadrant | Count | Action |
|----------|-------|--------|
| Do | ${matrix.do.length} | Immediate focus |
| Schedule | ${matrix.schedule.length} | Plan this week |
| Delegate | ${matrix.delegate.length} | Assign today |
| Eliminate | ${matrix.eliminate.length} | Remove/batch |

## Recommendations

${matrix.do.length > 5 ? '- Too many urgent tasks. Investigate why and prevent future urgency.' : ''}
${matrix.schedule.length < matrix.do.length ? '- Spend more time in Q2 (Schedule) to reduce Q1 (Do) emergencies.' : ''}
${matrix.eliminate.length === 0 ? '- Good discipline on avoiding time wasters!' : ''}
    `.trim();
  }
}

// Example
const matrix = new EisenhowerMatrix();

const tasks: Task[] = [
  {
    id: '1',
    title: 'Fix production outage',
    urgent: true,
    important: true,
    dueDate: new Date()
  },
  {
    id: '2',
    title: 'Strategic planning for Q2',
    urgent: false,
    important: true
  },
  {
    id: '3',
    title: 'Respond to vendor inquiry',
    urgent: true,
    important: false,
    delegateTo: 'ops-team'
  },
  {
    id: '4',
    title: 'Organize email inbox',
    urgent: false,
    important: false
  }
];

console.log(matrix.generateActionPlan(tasks));
```

**Anti-Pattern**: Everything marked urgent.

### Pattern 5: Value vs Effort Matrix

**When to Use**: Quick visual prioritization

**Example**:
```typescript
// value-effort-matrix.ts
interface Initiative {
  id: string;
  name: string;
  value: number;  // 1-10
  effort: number; // 1-10
  category?: 'quick-win' | 'major-project' | 'fill-in' | 'thankless';
}

class ValueEffortMatrix {
  // Quick Wins: High Value, Low Effort (Top Left)
  // Major Projects: High Value, High Effort (Top Right)
  // Fill-Ins: Low Value, Low Effort (Bottom Left)
  // Thankless Tasks: Low Value, High Effort (Bottom Right)

  private readonly VALUE_THRESHOLD = 5;
  private readonly EFFORT_THRESHOLD = 5;

  categorize(initiative: Initiative): Initiative['category'] {
    const highValue = initiative.value >= this.VALUE_THRESHOLD;
    const highEffort = initiative.effort >= this.EFFORT_THRESHOLD;

    if (highValue && !highEffort) return 'quick-win';
    if (highValue && highEffort) return 'major-project';
    if (!highValue && !highEffort) return 'fill-in';
    return 'thankless';
  }

  analyze(initiatives: Initiative[]): {
    categorized: Record<NonNullable<Initiative['category']>, Initiative[]>;
    recommendations: string[];
    priorityOrder: Initiative[];
  } {
    const categorized: Record<NonNullable<Initiative['category']>, Initiative[]> = {
      'quick-win': [],
      'major-project': [],
      'fill-in': [],
      'thankless': []
    };

    for (const initiative of initiatives) {
      const category = this.categorize(initiative);
      initiative.category = category;
      categorized[category].push(initiative);
    }

    // Sort each category by value/effort ratio
    for (const category of Object.keys(categorized)) {
      categorized[category as keyof typeof categorized].sort((a, b) =>
        (b.value / b.effort) - (a.value / a.effort)
      );
    }

    // Priority order: Quick Wins -> Major Projects -> Fill-Ins
    const priorityOrder = [
      ...categorized['quick-win'],
      ...categorized['major-project'],
      ...categorized['fill-in']
      // Thankless tasks not included
    ];

    const recommendations = this.generateRecommendations(categorized);

    return { categorized, recommendations, priorityOrder };
  }

  private generateRecommendations(
    categorized: Record<NonNullable<Initiative['category']>, Initiative[]>
  ): string[] {
    const recommendations: string[] = [];

    if (categorized['quick-win'].length > 0) {
      recommendations.push(
        `Start with "${categorized['quick-win'][0].name}" - highest value quick win`
      );
    }

    if (categorized['thankless'].length > 0) {
      recommendations.push(
        `Consider eliminating or automating: ${categorized['thankless'].map(i => i.name).join(', ')}`
      );
    }

    if (categorized['major-project'].length > 2) {
      recommendations.push(
        'Multiple major projects identified. Consider sequencing to avoid resource conflicts.'
      );
    }

    if (categorized['quick-win'].length === 0 && categorized['major-project'].length > 0) {
      recommendations.push(
        'No quick wins available. Break down major projects into smaller deliverables.'
      );
    }

    return recommendations;
  }

  generateVisualization(initiatives: Initiative[]): string {
    const { categorized, recommendations, priorityOrder } = this.analyze(initiatives);

    // ASCII visualization
    const grid = this.createGrid(initiatives);

    return `
# Value vs Effort Matrix

\`\`\`
     HIGH VALUE
        10 |${grid.topRow}
           |
         5 +---------------
           |${grid.bottomRow}
        0  +---5-------10---> EFFORT
              LOW    HIGH
\`\`\`

## Quick Wins (Do First)
${categorized['quick-win'].map(i => `- ${i.name} (V:${i.value}/E:${i.effort})`).join('\n') || 'None'}

## Major Projects (Plan Carefully)
${categorized['major-project'].map(i => `- ${i.name} (V:${i.value}/E:${i.effort})`).join('\n') || 'None'}

## Fill-Ins (When Time Permits)
${categorized['fill-in'].map(i => `- ${i.name} (V:${i.value}/E:${i.effort})`).join('\n') || 'None'}

## Thankless Tasks (Avoid/Eliminate)
${categorized['thankless'].map(i => `- ${i.name} (V:${i.value}/E:${i.effort})`).join('\n') || 'None'}

## Recommendations

${recommendations.map(r => `- ${r}`).join('\n')}

## Execution Order

${priorityOrder.map((i, idx) => `${idx + 1}. ${i.name}`).join('\n')}
    `.trim();
  }

  private createGrid(initiatives: Initiative[]): { topRow: string; bottomRow: string } {
    // Simplified ASCII representation
    const topLeft = initiatives.filter(i => i.value >= 5 && i.effort < 5);
    const topRight = initiatives.filter(i => i.value >= 5 && i.effort >= 5);
    const bottomLeft = initiatives.filter(i => i.value < 5 && i.effort < 5);
    const bottomRight = initiatives.filter(i => i.value < 5 && i.effort >= 5);

    return {
      topRow: ` [QW:${topLeft.length}]    | [MP:${topRight.length}]`,
      bottomRow: ` [FI:${bottomLeft.length}]    | [TT:${bottomRight.length}]`
    };
  }
}

// Example
const matrix = new ValueEffortMatrix();

const initiatives: Initiative[] = [
  { id: '1', name: 'Add caching layer', value: 8, effort: 2 },
  { id: '2', name: 'Rewrite auth system', value: 9, effort: 9 },
  { id: '3', name: 'Update documentation', value: 3, effort: 2 },
  { id: '4', name: 'Manual data migration', value: 2, effort: 8 },
  { id: '5', name: 'Add dark mode', value: 6, effort: 3 }
];

console.log(matrix.generateVisualization(initiatives));
```

**Anti-Pattern**: Not revisiting priorities as context changes.

## Checklist

- [ ] Clear criteria for scoring
- [ ] Consistent scoring across items
- [ ] Stakeholder input gathered
- [ ] Dependencies considered
- [ ] Capacity constraints factored
- [ ] Regular re-prioritization scheduled
- [ ] Results communicated to team
- [ ] Framework matches context
- [ ] Trade-offs documented
- [ ] Decision rationale captured

## References

- [RICE Scoring Model](https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/)
- [MoSCoW Method](https://www.agilebusiness.org/page/ProjectFramework_10_MoSCoWPrioritisation)
- [WSJF in SAFe](https://www.scaledagileframework.com/wsjf/)
- [Eisenhower Matrix](https://www.eisenhower.me/eisenhower-matrix/)
