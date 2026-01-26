---
title: Feature Flag Cleanup Reference
category: delivery
type: reference
version: "1.0.0"
---

# Feature Flag Cleanup

> Part of the delivery/feature-flags knowledge skill

## Overview

Feature flag cleanup prevents technical debt accumulation. This reference covers flag lifecycle management, detection of stale flags, and automated cleanup processes.

## Quick Reference (80/20)

| State | Action |
|-------|--------|
| Active | Monitor and document |
| Rolled Out | Schedule removal |
| Stale | Alert and investigate |
| Expired | Remove from code |
| Archived | Document learnings |

## Patterns

### Pattern 1: Flag Lifecycle Management

**When to Use**: Managing flag states and transitions

**Example**:
```typescript
// flag-lifecycle.ts
type FlagState =
  | 'draft'      // Created but not enabled
  | 'testing'    // In QA/staging
  | 'rolling'    // Gradual rollout
  | 'active'     // Fully enabled
  | 'stale'      // No activity detected
  | 'deprecated' // Marked for removal
  | 'archived';  // Removed from code

interface FlagLifecycle {
  key: string;
  state: FlagState;
  createdAt: Date;
  createdBy: string;
  owner: string;
  expirationDate?: Date;
  lastEvaluated?: Date;
  rolloutCompletedAt?: Date;
  deprecatedAt?: Date;
  archivedAt?: Date;
  jiraTicket?: string;
  removalPR?: string;
}

class FlagLifecycleService {
  private readonly STALE_THRESHOLD_DAYS = 30;
  private readonly DEFAULT_EXPIRATION_DAYS = 90;

  constructor(
    private flagStore: FlagStore,
    private metricsService: MetricsService,
    private notificationService: NotificationService
  ) {}

  async createFlag(
    key: string,
    owner: string,
    config: FlagConfig
  ): Promise<FlagLifecycle> {
    const lifecycle: FlagLifecycle = {
      key,
      state: 'draft',
      createdAt: new Date(),
      createdBy: owner,
      owner,
      expirationDate: this.calculateExpiration(config.expectedDuration)
    };

    await this.flagStore.saveLifecycle(lifecycle);
    return lifecycle;
  }

  async transitionState(key: string, newState: FlagState): Promise<void> {
    const lifecycle = await this.flagStore.getLifecycle(key);
    if (!lifecycle) {
      throw new Error(`Flag ${key} not found`);
    }

    this.validateTransition(lifecycle.state, newState);

    const updates: Partial<FlagLifecycle> = { state: newState };

    switch (newState) {
      case 'active':
        updates.rolloutCompletedAt = new Date();
        break;
      case 'deprecated':
        updates.deprecatedAt = new Date();
        break;
      case 'archived':
        updates.archivedAt = new Date();
        break;
    }

    await this.flagStore.updateLifecycle(key, updates);
    await this.notifyStateChange(lifecycle, newState);
  }

  private validateTransition(from: FlagState, to: FlagState): void {
    const validTransitions: Record<FlagState, FlagState[]> = {
      draft: ['testing', 'archived'],
      testing: ['rolling', 'draft', 'archived'],
      rolling: ['active', 'testing', 'archived'],
      active: ['stale', 'deprecated', 'archived'],
      stale: ['active', 'deprecated', 'archived'],
      deprecated: ['archived', 'active'],
      archived: [] // Terminal state
    };

    if (!validTransitions[from].includes(to)) {
      throw new Error(`Invalid transition from ${from} to ${to}`);
    }
  }

  async detectStaleFlags(): Promise<FlagLifecycle[]> {
    const activeFlags = await this.flagStore.getFlagsByState('active');
    const staleFlags: FlagLifecycle[] = [];

    for (const flag of activeFlags) {
      const lastEvaluated = await this.metricsService.getLastEvaluation(flag.key);

      if (!lastEvaluated) {
        staleFlags.push(flag);
        continue;
      }

      const daysSinceEvaluation = this.daysBetween(lastEvaluated, new Date());

      if (daysSinceEvaluation > this.STALE_THRESHOLD_DAYS) {
        staleFlags.push(flag);
        await this.transitionState(flag.key, 'stale');
      }
    }

    return staleFlags;
  }

  async getExpiredFlags(): Promise<FlagLifecycle[]> {
    const flags = await this.flagStore.getAllFlags();
    const now = new Date();

    return flags.filter(flag =>
      flag.expirationDate &&
      flag.expirationDate < now &&
      flag.state !== 'archived'
    );
  }

  private calculateExpiration(expectedDuration?: number): Date {
    const days = expectedDuration ?? this.DEFAULT_EXPIRATION_DAYS;
    const date = new Date();
    date.setDate(date.getDate() + days);
    return date;
  }

  private daysBetween(date1: Date, date2: Date): number {
    const diffTime = Math.abs(date2.getTime() - date1.getTime());
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  }

  private async notifyStateChange(
    flag: FlagLifecycle,
    newState: FlagState
  ): Promise<void> {
    await this.notificationService.notify({
      type: 'flag_state_change',
      recipient: flag.owner,
      data: {
        flagKey: flag.key,
        previousState: flag.state,
        newState,
        timestamp: new Date()
      }
    });
  }
}
```

**Anti-Pattern**: Flags without owners or expiration dates.

### Pattern 2: Code Scanning for Dead Flags

**When to Use**: Detecting unused flag references

**Example**:
```typescript
// flag-scanner.ts
import * as fs from 'fs';
import * as path from 'path';

interface FlagUsage {
  flagKey: string;
  file: string;
  line: number;
  context: string;
}

interface ScanResult {
  definedFlags: string[];
  usedFlags: Map<string, FlagUsage[]>;
  unusedFlags: string[];
  undefinedUsages: FlagUsage[];
}

class FlagCodeScanner {
  private readonly FLAG_PATTERNS = [
    // JavaScript/TypeScript
    /isEnabled\(['"]([^'"]+)['"]\)/g,
    /useFeatureFlag\(['"]([^'"]+)['"]\)/g,
    /flagService\.evaluate\(['"]([^'"]+)['"]/g,
    /getFlag\(['"]([^'"]+)['"]\)/g,
    // Go
    /IsEnabled\(ctx,\s*["']([^"']+)["']/g,
    /GetFlag\(["']([^"']+)["']/g,
    // Python
    /is_enabled\(['"]([^'"]+)['"]\)/g,
    /feature_flag\(['"]([^'"]+)['"]\)/g
  ];

  private readonly IGNORED_DIRS = [
    'node_modules',
    'dist',
    'build',
    '.git',
    'vendor',
    '__pycache__'
  ];

  private readonly FILE_EXTENSIONS = [
    '.ts', '.tsx', '.js', '.jsx',
    '.go', '.py', '.java', '.kt'
  ];

  async scan(
    sourceDir: string,
    definedFlags: string[]
  ): Promise<ScanResult> {
    const usedFlags = new Map<string, FlagUsage[]>();

    await this.scanDirectory(sourceDir, usedFlags);

    const unusedFlags = definedFlags.filter(
      flag => !usedFlags.has(flag)
    );

    const allUsedKeys = Array.from(usedFlags.keys());
    const undefinedUsages: FlagUsage[] = [];

    for (const [key, usages] of usedFlags) {
      if (!definedFlags.includes(key)) {
        undefinedUsages.push(...usages);
      }
    }

    return {
      definedFlags,
      usedFlags,
      unusedFlags,
      undefinedUsages
    };
  }

  private async scanDirectory(
    dir: string,
    usedFlags: Map<string, FlagUsage[]>
  ): Promise<void> {
    const entries = await fs.promises.readdir(dir, { withFileTypes: true });

    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);

      if (entry.isDirectory()) {
        if (!this.IGNORED_DIRS.includes(entry.name)) {
          await this.scanDirectory(fullPath, usedFlags);
        }
      } else if (entry.isFile()) {
        const ext = path.extname(entry.name);
        if (this.FILE_EXTENSIONS.includes(ext)) {
          await this.scanFile(fullPath, usedFlags);
        }
      }
    }
  }

  private async scanFile(
    filePath: string,
    usedFlags: Map<string, FlagUsage[]>
  ): Promise<void> {
    const content = await fs.promises.readFile(filePath, 'utf-8');
    const lines = content.split('\n');

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      for (const pattern of this.FLAG_PATTERNS) {
        pattern.lastIndex = 0; // Reset regex state
        let match;

        while ((match = pattern.exec(line)) !== null) {
          const flagKey = match[1];
          const usage: FlagUsage = {
            flagKey,
            file: filePath,
            line: i + 1,
            context: line.trim()
          };

          if (!usedFlags.has(flagKey)) {
            usedFlags.set(flagKey, []);
          }
          usedFlags.get(flagKey)!.push(usage);
        }
      }
    }
  }

  generateReport(result: ScanResult): string {
    const lines: string[] = [
      '# Feature Flag Scan Report',
      '',
      `Scan Date: ${new Date().toISOString()}`,
      '',
      '## Summary',
      `- Total Defined Flags: ${result.definedFlags.length}`,
      `- Flags In Use: ${result.usedFlags.size}`,
      `- Unused Flags: ${result.unusedFlags.length}`,
      `- Undefined Usages: ${result.undefinedUsages.length}`,
      ''
    ];

    if (result.unusedFlags.length > 0) {
      lines.push('## Unused Flags (Candidates for Removal)');
      lines.push('');
      result.unusedFlags.forEach(flag => {
        lines.push(`- \`${flag}\``);
      });
      lines.push('');
    }

    if (result.undefinedUsages.length > 0) {
      lines.push('## Undefined Flag Usages (Potential Issues)');
      lines.push('');
      result.undefinedUsages.forEach(usage => {
        lines.push(`- \`${usage.flagKey}\` at ${usage.file}:${usage.line}`);
        lines.push(`  \`\`\`${usage.context}\`\`\``);
      });
      lines.push('');
    }

    lines.push('## Flag Usage Details');
    lines.push('');
    for (const [key, usages] of result.usedFlags) {
      lines.push(`### ${key}`);
      lines.push(`Used in ${usages.length} location(s):`);
      usages.slice(0, 5).forEach(usage => {
        lines.push(`- ${usage.file}:${usage.line}`);
      });
      if (usages.length > 5) {
        lines.push(`- ... and ${usages.length - 5} more`);
      }
      lines.push('');
    }

    return lines.join('\n');
  }
}

// CI Integration
async function runFlagScan(): Promise<void> {
  const scanner = new FlagCodeScanner();
  const flagService = new FlagService();

  // Get defined flags from flag service
  const definedFlags = await flagService.getAllFlagKeys();

  // Scan source code
  const result = await scanner.scan('./src', definedFlags);

  // Generate report
  const report = scanner.generateReport(result);
  await fs.promises.writeFile('flag-scan-report.md', report);

  // Fail CI if there are issues
  if (result.unusedFlags.length > 0 || result.undefinedUsages.length > 0) {
    console.error('Flag scan found issues:');
    console.error(`- ${result.unusedFlags.length} unused flags`);
    console.error(`- ${result.undefinedUsages.length} undefined usages`);

    if (process.env.FAIL_ON_FLAG_ISSUES === 'true') {
      process.exit(1);
    }
  }
}
```

**Anti-Pattern**: Manual flag tracking in spreadsheets.

### Pattern 3: Automated Cleanup Pipeline

**When to Use**: Systematic flag removal

**Example**:
```yaml
# .github/workflows/flag-cleanup.yml
name: Feature Flag Cleanup

on:
  schedule:
    - cron: '0 9 * * 1' # Every Monday at 9 AM
  workflow_dispatch:

jobs:
  scan-flags:
    runs-on: ubuntu-latest
    outputs:
      has_issues: ${{ steps.scan.outputs.has_issues }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Scan for stale flags
        id: scan
        run: |
          npm run flag:scan > flag-report.md

          # Check for issues
          UNUSED=$(grep -c "Unused Flags" flag-report.md || true)
          UNDEFINED=$(grep -c "Undefined Flag" flag-report.md || true)

          if [ "$UNUSED" -gt 0 ] || [ "$UNDEFINED" -gt 0 ]; then
            echo "has_issues=true" >> $GITHUB_OUTPUT
          else
            echo "has_issues=false" >> $GITHUB_OUTPUT
          fi

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: flag-scan-report
          path: flag-report.md

  create-cleanup-issues:
    needs: scan-flags
    if: needs.scan-flags.outputs.has_issues == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download report
        uses: actions/download-artifact@v4
        with:
          name: flag-scan-report

      - name: Create cleanup issues
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const report = fs.readFileSync('flag-report.md', 'utf8');

            // Parse unused flags
            const unusedMatch = report.match(/## Unused Flags.*?\n([\s\S]*?)(?=##|$)/);
            if (unusedMatch) {
              const flags = unusedMatch[1].match(/`([^`]+)`/g) || [];

              for (const flag of flags) {
                const flagName = flag.replace(/`/g, '');

                // Check if issue already exists
                const existingIssues = await github.rest.issues.listForRepo({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  labels: 'flag-cleanup',
                  state: 'open'
                });

                const exists = existingIssues.data.some(
                  issue => issue.title.includes(flagName)
                );

                if (!exists) {
                  await github.rest.issues.create({
                    owner: context.repo.owner,
                    repo: context.repo.repo,
                    title: `[Flag Cleanup] Remove unused flag: ${flagName}`,
                    body: `## Summary\n\nThe feature flag \`${flagName}\` is no longer used in the codebase and should be removed.\n\n## Tasks\n\n- [ ] Remove flag from feature flag service\n- [ ] Remove any related configuration\n- [ ] Update documentation\n- [ ] Verify no runtime dependencies\n\n## Generated by\n\nAutomated flag scan on ${new Date().toISOString()}`,
                    labels: ['flag-cleanup', 'tech-debt']
                  });
                }
              }
            }

  notify-owners:
    needs: scan-flags
    if: needs.scan-flags.outputs.has_issues == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Download report
        uses: actions/download-artifact@v4
        with:
          name: flag-scan-report

      - name: Notify via Slack
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Feature Flag Cleanup Required",
              "blocks": [
                {
                  "type": "header",
                  "text": {
                    "type": "plain_text",
                    "text": "Feature Flag Cleanup Report"
                  }
                },
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "The weekly flag scan found issues requiring attention. Please review the <${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}|scan report>."
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

```typescript
// cleanup-generator.ts
interface CleanupPlan {
  flagKey: string;
  files: FileChange[];
  testFiles: string[];
  configChanges: ConfigChange[];
}

interface FileChange {
  path: string;
  type: 'remove_usage' | 'remove_import' | 'simplify_conditional';
  line: number;
  before: string;
  after: string;
}

interface ConfigChange {
  source: string;
  type: 'remove_flag' | 'remove_variant' | 'remove_targeting';
}

class CleanupGenerator {
  async generateCleanupPlan(flagKey: string, variant: 'control' | 'treatment'): Promise<CleanupPlan> {
    const usages = await this.findFlagUsages(flagKey);
    const fileChanges: FileChange[] = [];

    for (const usage of usages) {
      const change = await this.analyzeUsage(usage, variant);
      if (change) {
        fileChanges.push(change);
      }
    }

    const testFiles = await this.findRelatedTests(flagKey);

    return {
      flagKey,
      files: fileChanges,
      testFiles,
      configChanges: [
        { source: 'feature-flags', type: 'remove_flag' }
      ]
    };
  }

  private async analyzeUsage(
    usage: FlagUsage,
    variant: 'control' | 'treatment'
  ): Promise<FileChange | null> {
    const content = await fs.promises.readFile(usage.file, 'utf-8');
    const lines = content.split('\n');
    const line = lines[usage.line - 1];

    // Pattern: if (isEnabled('flag')) { ... } else { ... }
    const conditionalMatch = line.match(/if\s*\(\s*isEnabled\(['"]([^'"]+)['"]\)\s*\)/);
    if (conditionalMatch) {
      return this.simplifyConditional(usage, lines, variant);
    }

    // Pattern: const variant = useFeatureFlag('flag') ? 'new' : 'old'
    const ternaryMatch = line.match(/useFeatureFlag\(['"]([^'"]+)['"]\)\s*\?\s*([^:]+)\s*:\s*(.+)/);
    if (ternaryMatch) {
      const replacement = variant === 'treatment' ? ternaryMatch[2].trim() : ternaryMatch[3].trim();
      return {
        path: usage.file,
        type: 'simplify_conditional',
        line: usage.line,
        before: line,
        after: line.replace(ternaryMatch[0], replacement)
      };
    }

    return null;
  }

  private simplifyConditional(
    usage: FlagUsage,
    lines: string[],
    variant: 'control' | 'treatment'
  ): FileChange {
    // Find the if-else block boundaries
    const startLine = usage.line - 1;
    let braceCount = 0;
    let elseIndex = -1;
    let endIndex = startLine;

    for (let i = startLine; i < lines.length; i++) {
      const line = lines[i];
      braceCount += (line.match(/{/g) || []).length;
      braceCount -= (line.match(/}/g) || []).length;

      if (braceCount === 0 && i > startLine) {
        endIndex = i;
        break;
      }

      if (line.includes('} else {') && braceCount === 1) {
        elseIndex = i;
      }
    }

    if (variant === 'treatment') {
      // Keep the if block content, remove else
      const ifContent = lines.slice(startLine + 1, elseIndex).join('\n');
      return {
        path: usage.file,
        type: 'simplify_conditional',
        line: usage.line,
        before: lines.slice(startLine, endIndex + 1).join('\n'),
        after: ifContent
      };
    } else {
      // Keep the else block content, remove if
      const elseContent = lines.slice(elseIndex + 1, endIndex).join('\n');
      return {
        path: usage.file,
        type: 'simplify_conditional',
        line: usage.line,
        before: lines.slice(startLine, endIndex + 1).join('\n'),
        after: elseContent
      };
    }
  }

  async applyCleanupPlan(plan: CleanupPlan): Promise<void> {
    // Sort changes by file and line (reverse order to not affect line numbers)
    const changesByFile = new Map<string, FileChange[]>();

    for (const change of plan.files) {
      if (!changesByFile.has(change.path)) {
        changesByFile.set(change.path, []);
      }
      changesByFile.get(change.path)!.push(change);
    }

    for (const [filePath, changes] of changesByFile) {
      // Sort by line number descending
      changes.sort((a, b) => b.line - a.line);

      let content = await fs.promises.readFile(filePath, 'utf-8');

      for (const change of changes) {
        content = content.replace(change.before, change.after);
      }

      await fs.promises.writeFile(filePath, content);
    }
  }

  private async findFlagUsages(flagKey: string): Promise<FlagUsage[]> {
    const scanner = new FlagCodeScanner();
    const result = await scanner.scan('./src', [flagKey]);
    return result.usedFlags.get(flagKey) || [];
  }

  private async findRelatedTests(flagKey: string): Promise<string[]> {
    const scanner = new FlagCodeScanner();
    const result = await scanner.scan('./tests', [flagKey]);
    const usages = result.usedFlags.get(flagKey) || [];
    return [...new Set(usages.map(u => u.file))];
  }
}
```

**Anti-Pattern**: Manual code cleanup without automation.

### Pattern 4: Flag Deprecation Workflow

**When to Use**: Graceful flag retirement

**Example**:
```typescript
// deprecation-workflow.ts
interface DeprecationConfig {
  flagKey: string;
  targetValue: any; // The permanent value after removal
  notifyOwners: boolean;
  deprecationPeriodDays: number;
  steps: DeprecationStep[];
}

interface DeprecationStep {
  day: number;
  action: 'notify' | 'warn_in_logs' | 'set_percentage' | 'archive';
  params?: Record<string, any>;
}

class DeprecationWorkflow {
  private readonly DEFAULT_STEPS: DeprecationStep[] = [
    { day: 0, action: 'notify', params: { message: 'Flag deprecated' } },
    { day: 7, action: 'warn_in_logs' },
    { day: 14, action: 'set_percentage', params: { percentage: 100 } },
    { day: 21, action: 'notify', params: { message: 'Final warning' } },
    { day: 30, action: 'archive' }
  ];

  constructor(
    private flagService: FlagService,
    private lifecycleService: FlagLifecycleService,
    private notificationService: NotificationService,
    private scheduler: SchedulerService
  ) {}

  async startDeprecation(config: DeprecationConfig): Promise<void> {
    // Mark flag as deprecated
    await this.lifecycleService.transitionState(config.flagKey, 'deprecated');

    // Schedule all steps
    const steps = config.steps.length > 0 ? config.steps : this.DEFAULT_STEPS;
    const startDate = new Date();

    for (const step of steps) {
      const executeAt = new Date(startDate);
      executeAt.setDate(executeAt.getDate() + step.day);

      await this.scheduler.schedule(
        `deprecation:${config.flagKey}:step:${step.day}`,
        executeAt,
        () => this.executeStep(config, step)
      );
    }

    // Create removal PR automatically
    await this.createRemovalDraft(config);
  }

  private async executeStep(
    config: DeprecationConfig,
    step: DeprecationStep
  ): Promise<void> {
    switch (step.action) {
      case 'notify':
        await this.notifyStakeholders(config, step.params?.message);
        break;

      case 'warn_in_logs':
        await this.enableDeprecationWarning(config.flagKey);
        break;

      case 'set_percentage':
        await this.flagService.setPercentage(
          config.flagKey,
          step.params?.percentage ?? 100
        );
        break;

      case 'archive':
        await this.finalizeRemoval(config);
        break;
    }
  }

  private async notifyStakeholders(
    config: DeprecationConfig,
    message?: string
  ): Promise<void> {
    const lifecycle = await this.lifecycleService.getFlag(config.flagKey);

    await this.notificationService.notify({
      type: 'flag_deprecation',
      recipients: [lifecycle.owner, ...(lifecycle.watchers || [])],
      data: {
        flagKey: config.flagKey,
        message: message || `Flag ${config.flagKey} is being deprecated`,
        targetValue: config.targetValue,
        removalDate: this.calculateRemovalDate(config)
      }
    });
  }

  private async enableDeprecationWarning(flagKey: string): Promise<void> {
    // Add middleware to log deprecation warnings
    await this.flagService.addMiddleware(flagKey, {
      type: 'deprecation_warning',
      handler: (context) => {
        console.warn(
          `[DEPRECATED] Feature flag '${flagKey}' is deprecated. ` +
          `Called from ${context.caller}. Please remove usage.`
        );
      }
    });
  }

  private async createRemovalDraft(config: DeprecationConfig): Promise<void> {
    const generator = new CleanupGenerator();
    const plan = await generator.generateCleanupPlan(
      config.flagKey,
      config.targetValue ? 'treatment' : 'control'
    );

    // Create draft PR with changes
    const branchName = `flag-cleanup/${config.flagKey}`;

    // This would integrate with your Git/GitHub workflow
    await this.createBranch(branchName);
    await generator.applyCleanupPlan(plan);
    await this.createPullRequest({
      branch: branchName,
      title: `[Flag Cleanup] Remove ${config.flagKey}`,
      body: this.generatePRDescription(config, plan),
      draft: true
    });
  }

  private async finalizeRemoval(config: DeprecationConfig): Promise<void> {
    // Archive the flag
    await this.lifecycleService.transitionState(config.flagKey, 'archived');

    // Remove from flag service
    await this.flagService.deleteFlag(config.flagKey);

    // Mark PR as ready for review
    await this.markPRReady(config.flagKey);

    // Final notification
    await this.notificationService.notify({
      type: 'flag_removed',
      data: {
        flagKey: config.flagKey,
        message: `Flag ${config.flagKey} has been archived. Please merge the cleanup PR.`
      }
    });
  }

  private calculateRemovalDate(config: DeprecationConfig): Date {
    const date = new Date();
    date.setDate(date.getDate() + config.deprecationPeriodDays);
    return date;
  }

  private generatePRDescription(
    config: DeprecationConfig,
    plan: CleanupPlan
  ): string {
    return `
## Summary

This PR removes the deprecated feature flag \`${config.flagKey}\`.

## Changes

### Files Modified
${plan.files.map(f => `- ${f.path}`).join('\n')}

### Tests Affected
${plan.testFiles.map(f => `- ${f}`).join('\n')}

## Verification

- [ ] All usages removed from code
- [ ] Tests updated/removed
- [ ] No runtime dependencies
- [ ] Documentation updated

## Notes

Target value after removal: \`${config.targetValue}\`
`;
  }

  private async createBranch(name: string): Promise<void> {
    // Git integration
  }

  private async createPullRequest(config: any): Promise<void> {
    // GitHub API integration
  }

  private async markPRReady(flagKey: string): Promise<void> {
    // GitHub API integration
  }
}

// Usage
const workflow = new DeprecationWorkflow(
  flagService,
  lifecycleService,
  notificationService,
  scheduler
);

await workflow.startDeprecation({
  flagKey: 'new-checkout-flow',
  targetValue: true, // Keep the new checkout
  notifyOwners: true,
  deprecationPeriodDays: 30,
  steps: [
    { day: 0, action: 'notify', params: { message: 'Starting deprecation' } },
    { day: 7, action: 'set_percentage', params: { percentage: 100 } },
    { day: 14, action: 'warn_in_logs' },
    { day: 30, action: 'archive' }
  ]
});
```

**Anti-Pattern**: Abrupt flag removal without notice.

### Pattern 5: Technical Debt Dashboard

**When to Use**: Visibility into flag debt

**Example**:
```typescript
// flag-dashboard.ts
interface FlagMetrics {
  totalFlags: number;
  byState: Record<FlagState, number>;
  byAge: {
    under30Days: number;
    thirtyTo90Days: number;
    over90Days: number;
  };
  expiringSoon: FlagLifecycle[];
  staleFlags: FlagLifecycle[];
  ownershipDistribution: Record<string, number>;
  technicalDebtScore: number;
}

class FlagDashboardService {
  constructor(
    private flagStore: FlagStore,
    private metricsService: MetricsService
  ) {}

  async getMetrics(): Promise<FlagMetrics> {
    const flags = await this.flagStore.getAllFlags();
    const now = new Date();

    const byState = this.groupByState(flags);
    const byAge = this.groupByAge(flags, now);
    const expiringSoon = this.getExpiringSoon(flags, now, 14);
    const staleFlags = flags.filter(f => f.state === 'stale');
    const ownershipDistribution = this.getOwnershipDistribution(flags);
    const technicalDebtScore = this.calculateDebtScore(flags);

    return {
      totalFlags: flags.length,
      byState,
      byAge,
      expiringSoon,
      staleFlags,
      ownershipDistribution,
      technicalDebtScore
    };
  }

  private groupByState(flags: FlagLifecycle[]): Record<FlagState, number> {
    const result: Record<string, number> = {};

    for (const flag of flags) {
      result[flag.state] = (result[flag.state] || 0) + 1;
    }

    return result as Record<FlagState, number>;
  }

  private groupByAge(
    flags: FlagLifecycle[],
    now: Date
  ): FlagMetrics['byAge'] {
    const result = {
      under30Days: 0,
      thirtyTo90Days: 0,
      over90Days: 0
    };

    for (const flag of flags) {
      const age = this.daysBetween(flag.createdAt, now);

      if (age < 30) {
        result.under30Days++;
      } else if (age < 90) {
        result.thirtyTo90Days++;
      } else {
        result.over90Days++;
      }
    }

    return result;
  }

  private getExpiringSoon(
    flags: FlagLifecycle[],
    now: Date,
    days: number
  ): FlagLifecycle[] {
    const threshold = new Date(now);
    threshold.setDate(threshold.getDate() + days);

    return flags.filter(flag =>
      flag.expirationDate &&
      flag.expirationDate <= threshold &&
      flag.state !== 'archived'
    );
  }

  private getOwnershipDistribution(
    flags: FlagLifecycle[]
  ): Record<string, number> {
    const result: Record<string, number> = {};

    for (const flag of flags) {
      result[flag.owner] = (result[flag.owner] || 0) + 1;
    }

    return result;
  }

  private calculateDebtScore(flags: FlagLifecycle[]): number {
    // Lower is better (0-100)
    let score = 0;
    const weights = {
      stale: 10,
      expired: 15,
      old: 5, // > 90 days
      noExpiration: 3,
      noOwner: 5
    };

    for (const flag of flags) {
      if (flag.state === 'stale') score += weights.stale;
      if (flag.expirationDate && flag.expirationDate < new Date()) {
        score += weights.expired;
      }
      if (this.daysBetween(flag.createdAt, new Date()) > 90) {
        score += weights.old;
      }
      if (!flag.expirationDate) score += weights.noExpiration;
      if (!flag.owner) score += weights.noOwner;
    }

    // Normalize to 0-100
    const maxScore = flags.length * 38; // Max possible per flag
    return Math.min(100, Math.round((score / maxScore) * 100));
  }

  private daysBetween(date1: Date, date2: Date): number {
    const diffTime = Math.abs(date2.getTime() - date1.getTime());
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  }

  async generateReport(): Promise<string> {
    const metrics = await this.getMetrics();

    return `
# Feature Flag Technical Debt Report

Generated: ${new Date().toISOString()}

## Summary

- **Total Flags**: ${metrics.totalFlags}
- **Technical Debt Score**: ${metrics.technicalDebtScore}/100 (${this.getScoreRating(metrics.technicalDebtScore)})

## Flags by State

| State | Count |
|-------|-------|
${Object.entries(metrics.byState).map(([state, count]) => `| ${state} | ${count} |`).join('\n')}

## Flags by Age

| Age Range | Count |
|-----------|-------|
| Under 30 days | ${metrics.byAge.under30Days} |
| 30-90 days | ${metrics.byAge.thirtyTo90Days} |
| Over 90 days | ${metrics.byAge.over90Days} |

## Flags Expiring Soon (14 days)

${metrics.expiringSoon.length > 0
  ? metrics.expiringSoon.map(f => `- **${f.key}** (expires ${f.expirationDate?.toISOString().split('T')[0]})`).join('\n')
  : 'None'}

## Stale Flags

${metrics.staleFlags.length > 0
  ? metrics.staleFlags.map(f => `- **${f.key}** (owner: ${f.owner})`).join('\n')
  : 'None'}

## Ownership Distribution

| Owner | Count |
|-------|-------|
${Object.entries(metrics.ownershipDistribution)
  .sort(([, a], [, b]) => b - a)
  .map(([owner, count]) => `| ${owner} | ${count} |`)
  .join('\n')}

## Recommendations

${this.generateRecommendations(metrics)}
`;
  }

  private getScoreRating(score: number): string {
    if (score < 20) return 'Excellent';
    if (score < 40) return 'Good';
    if (score < 60) return 'Fair';
    if (score < 80) return 'Poor';
    return 'Critical';
  }

  private generateRecommendations(metrics: FlagMetrics): string {
    const recommendations: string[] = [];

    if (metrics.staleFlags.length > 0) {
      recommendations.push(`- Review and remove ${metrics.staleFlags.length} stale flags`);
    }

    if (metrics.expiringSoon.length > 0) {
      recommendations.push(`- Address ${metrics.expiringSoon.length} flags expiring soon`);
    }

    if (metrics.byAge.over90Days > metrics.totalFlags * 0.3) {
      recommendations.push('- Too many old flags (>30%). Prioritize cleanup sprint');
    }

    if (metrics.technicalDebtScore > 50) {
      recommendations.push('- High debt score. Schedule dedicated cleanup time');
    }

    return recommendations.length > 0
      ? recommendations.join('\n')
      : 'No immediate action required.';
  }
}
```

**Anti-Pattern**: No visibility into flag accumulation.

## Checklist

- [ ] All flags have owners assigned
- [ ] Expiration dates set for temporary flags
- [ ] Stale flag detection automated
- [ ] Code scanning integrated into CI
- [ ] Cleanup workflow documented
- [ ] Deprecation notices sent to stakeholders
- [ ] Technical debt dashboard available
- [ ] Regular cleanup sprints scheduled
- [ ] Flag removal PRs auto-generated
- [ ] Metrics tracked for flag lifecycle

## References

- [Feature Flag Best Practices](https://launchdarkly.com/blog/best-practices-for-feature-flags/)
- [Managing Technical Debt](https://martinfowler.com/bliki/TechnicalDebt.html)
- [Flag Cleanup Strategies](https://www.split.io/blog/feature-flag-debt/)
- [Trunk Based Development](https://trunkbaseddevelopment.com/feature-flags/)
