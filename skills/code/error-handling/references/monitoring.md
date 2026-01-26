---
title: Error Monitoring Setup Reference
category: code
type: reference
version: "1.0.0"
---

# Error Monitoring Setup

> Part of the code/error-handling knowledge skill

## Overview

Error monitoring captures, aggregates, and alerts on application errors. This reference covers error tracking setup, alerting strategies, and integration patterns for observability.

## Quick Reference (80/20)

| Component | Purpose |
|-----------|---------|
| Error capture | Collect errors with context |
| Aggregation | Group similar errors |
| Alerting | Notify on new/spike errors |
| Source maps | Map minified to source |
| User context | Track affected users |
| Release tracking | Correlate with deployments |

## Patterns

### Pattern 1: Error Capture Service

**When to Use**: Centralized error collection

**Example**:
```typescript
interface ErrorContext {
  userId?: string;
  sessionId?: string;
  requestId?: string;
  environment: string;
  release: string;
  tags: Record<string, string>;
  extra: Record<string, any>;
}

interface CapturedError {
  id: string;
  message: string;
  stack?: string;
  type: string;
  timestamp: Date;
  context: ErrorContext;
  fingerprint: string;
  level: 'error' | 'warning' | 'info';
}

class ErrorMonitor {
  private static instance: ErrorMonitor;
  private errors: CapturedError[] = [];
  private context: Partial<ErrorContext> = {};
  private beforeSendHooks: Array<(error: CapturedError) => CapturedError | null> = [];

  private constructor(
    private config: {
      dsn: string;
      environment: string;
      release: string;
      sampleRate?: number;
      maxBreadcrumbs?: number;
    }
  ) {}

  static init(config: typeof ErrorMonitor.prototype.config): ErrorMonitor {
    if (!ErrorMonitor.instance) {
      ErrorMonitor.instance = new ErrorMonitor(config);
      ErrorMonitor.instance.setupGlobalHandlers();
    }
    return ErrorMonitor.instance;
  }

  static getInstance(): ErrorMonitor {
    if (!ErrorMonitor.instance) {
      throw new Error('ErrorMonitor not initialized');
    }
    return ErrorMonitor.instance;
  }

  setUser(user: { id: string; email?: string; username?: string }): void {
    this.context.userId = user.id;
    this.context.extra = {
      ...this.context.extra,
      userEmail: user.email,
      username: user.username
    };
  }

  setTags(tags: Record<string, string>): void {
    this.context.tags = { ...this.context.tags, ...tags };
  }

  setExtra(extra: Record<string, any>): void {
    this.context.extra = { ...this.context.extra, ...extra };
  }

  beforeSend(hook: (error: CapturedError) => CapturedError | null): void {
    this.beforeSendHooks.push(hook);
  }

  captureException(error: Error, additionalContext?: Partial<ErrorContext>): string {
    // Sample rate check
    if (this.config.sampleRate && Math.random() > this.config.sampleRate) {
      return '';
    }

    let captured: CapturedError = {
      id: this.generateId(),
      message: error.message,
      stack: error.stack,
      type: error.name,
      timestamp: new Date(),
      context: {
        environment: this.config.environment,
        release: this.config.release,
        tags: { ...this.context.tags, ...additionalContext?.tags },
        extra: { ...this.context.extra, ...additionalContext?.extra },
        userId: additionalContext?.userId || this.context.userId,
        sessionId: this.context.sessionId,
        requestId: additionalContext?.requestId
      },
      fingerprint: this.generateFingerprint(error),
      level: 'error'
    };

    // Run before send hooks
    for (const hook of this.beforeSendHooks) {
      const result = hook(captured);
      if (result === null) {
        return ''; // Filtered out
      }
      captured = result;
    }

    this.errors.push(captured);
    this.sendToBackend(captured);

    return captured.id;
  }

  captureMessage(message: string, level: 'error' | 'warning' | 'info' = 'info'): string {
    const captured: CapturedError = {
      id: this.generateId(),
      message,
      type: 'Message',
      timestamp: new Date(),
      context: {
        environment: this.config.environment,
        release: this.config.release,
        tags: this.context.tags || {},
        extra: this.context.extra || {}
      },
      fingerprint: this.hashString(message),
      level
    };

    this.errors.push(captured);
    this.sendToBackend(captured);

    return captured.id;
  }

  private setupGlobalHandlers(): void {
    // Node.js handlers
    if (typeof process !== 'undefined') {
      process.on('uncaughtException', (error) => {
        this.captureException(error, { tags: { handler: 'uncaughtException' } });
        console.error('Uncaught Exception:', error);
        process.exit(1);
      });

      process.on('unhandledRejection', (reason) => {
        const error = reason instanceof Error
          ? reason
          : new Error(String(reason));
        this.captureException(error, { tags: { handler: 'unhandledRejection' } });
      });
    }

    // Browser handlers
    if (typeof window !== 'undefined') {
      window.onerror = (message, source, lineno, colno, error) => {
        if (error) {
          this.captureException(error, {
            extra: { source, lineno, colno }
          });
        }
      };

      window.onunhandledrejection = (event) => {
        const error = event.reason instanceof Error
          ? event.reason
          : new Error(String(event.reason));
        this.captureException(error, { tags: { handler: 'unhandledRejection' } });
      };
    }
  }

  private generateFingerprint(error: Error): string {
    // Create unique fingerprint for grouping similar errors
    const parts = [
      error.name,
      error.message.replace(/\d+/g, 'N'), // Normalize numbers
      error.stack?.split('\n')[1]?.trim() || '' // First stack frame
    ];
    return this.hashString(parts.join('|'));
  }

  private hashString(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash).toString(16);
  }

  private generateId(): string {
    return `${Date.now().toString(36)}-${Math.random().toString(36).substr(2, 9)}`;
  }

  private async sendToBackend(error: CapturedError): Promise<void> {
    try {
      await fetch(this.config.dsn, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(error)
      });
    } catch (e) {
      console.error('Failed to send error to monitoring service:', e);
    }
  }
}

// Usage
ErrorMonitor.init({
  dsn: 'https://errors.example.com/api/capture',
  environment: process.env.NODE_ENV || 'development',
  release: process.env.APP_VERSION || '1.0.0',
  sampleRate: 1.0
});

// Filter sensitive data
ErrorMonitor.getInstance().beforeSend((error) => {
  // Remove passwords from extra data
  if (error.context.extra?.password) {
    delete error.context.extra.password;
  }

  // Don't send development errors
  if (error.context.environment === 'development') {
    return null;
  }

  return error;
});
```

**Anti-Pattern**: No error filtering, sending all errors including sensitive data.

### Pattern 2: Express Error Monitoring Middleware

**When to Use**: HTTP request error tracking

**Example**:
```typescript
import { Request, Response, NextFunction } from 'express';

interface RequestErrorContext {
  requestId: string;
  method: string;
  path: string;
  query: Record<string, any>;
  headers: Record<string, string>;
  body?: any;
  userId?: string;
  ip: string;
  userAgent: string;
  responseTime: number;
  statusCode: number;
}

function errorMonitoringMiddleware() {
  return (req: Request, res: Response, next: NextFunction) => {
    const startTime = Date.now();
    const requestId = req.headers['x-request-id'] as string || generateRequestId();

    // Add request ID to response
    res.setHeader('X-Request-ID', requestId);

    // Store context for error handler
    (req as any).monitoringContext = {
      requestId,
      startTime
    };

    // Capture response on finish
    res.on('finish', () => {
      const duration = Date.now() - startTime;

      // Log slow requests
      if (duration > 5000) {
        ErrorMonitor.getInstance().captureMessage(
          `Slow request: ${req.method} ${req.path} took ${duration}ms`,
          'warning'
        );
      }

      // Log error responses
      if (res.statusCode >= 500) {
        const context = buildRequestContext(req, res, duration);
        ErrorMonitor.getInstance().setExtra({ requestContext: context });
      }
    });

    next();
  };
}

function errorTrackingHandler() {
  return (error: Error, req: Request, res: Response, next: NextFunction) => {
    const { requestId, startTime } = (req as any).monitoringContext || {};
    const duration = startTime ? Date.now() - startTime : 0;

    const context = buildRequestContext(req, res, duration);

    // Capture with full context
    const errorId = ErrorMonitor.getInstance().captureException(error, {
      requestId,
      extra: {
        request: context,
        errorId: requestId
      },
      tags: {
        endpoint: `${req.method} ${req.route?.path || req.path}`,
        statusCode: String(res.statusCode || 500)
      }
    });

    // Include error ID in response
    res.setHeader('X-Error-ID', errorId);

    next(error);
  };
}

function buildRequestContext(
  req: Request,
  res: Response,
  duration: number
): RequestErrorContext {
  return {
    requestId: (req as any).monitoringContext?.requestId,
    method: req.method,
    path: req.path,
    query: req.query,
    headers: sanitizeHeaders(req.headers),
    body: sanitizeBody(req.body),
    userId: (req as any).user?.id,
    ip: req.ip || req.socket.remoteAddress || '',
    userAgent: req.headers['user-agent'] || '',
    responseTime: duration,
    statusCode: res.statusCode
  };
}

function sanitizeHeaders(headers: Record<string, any>): Record<string, string> {
  const sensitiveHeaders = ['authorization', 'cookie', 'x-api-key'];
  const sanitized: Record<string, string> = {};

  for (const [key, value] of Object.entries(headers)) {
    if (sensitiveHeaders.includes(key.toLowerCase())) {
      sanitized[key] = '[REDACTED]';
    } else {
      sanitized[key] = String(value);
    }
  }

  return sanitized;
}

function sanitizeBody(body: any): any {
  if (!body) return undefined;

  const sensitiveFields = ['password', 'token', 'secret', 'apiKey', 'creditCard'];
  const sanitized = { ...body };

  for (const field of sensitiveFields) {
    if (sanitized[field]) {
      sanitized[field] = '[REDACTED]';
    }
  }

  return sanitized;
}

// Usage
const app = express();
app.use(errorMonitoringMiddleware());
// ... routes
app.use(errorTrackingHandler());
```

**Anti-Pattern**: Logging full request bodies including passwords.

### Pattern 3: Alerting Configuration

**When to Use**: Setting up error alerts

**Example**:
```typescript
interface AlertRule {
  id: string;
  name: string;
  condition: AlertCondition;
  actions: AlertAction[];
  throttle: {
    count: number;
    windowMinutes: number;
  };
}

interface AlertCondition {
  type: 'threshold' | 'anomaly' | 'new_error';
  metric?: string;
  threshold?: number;
  comparison?: 'gt' | 'lt' | 'gte' | 'lte';
  timeWindowMinutes?: number;
}

interface AlertAction {
  type: 'slack' | 'pagerduty' | 'email' | 'webhook';
  config: Record<string, any>;
}

class AlertManager {
  private rules: AlertRule[] = [];
  private alertCounts: Map<string, { count: number; resetAt: number }> = new Map();
  private errorCounts: Map<string, number> = new Map();
  private seenFingerprints: Set<string> = new Set();

  addRule(rule: AlertRule): void {
    this.rules.push(rule);
  }

  async processError(error: CapturedError): Promise<void> {
    // Update error counts
    const countKey = `${error.fingerprint}:${this.getTimeWindow(5)}`;
    this.errorCounts.set(countKey, (this.errorCounts.get(countKey) || 0) + 1);

    for (const rule of this.rules) {
      if (this.shouldAlert(rule, error)) {
        await this.executeActions(rule, error);
      }
    }
  }

  private shouldAlert(rule: AlertRule, error: CapturedError): boolean {
    // Check throttle
    if (this.isThrottled(rule)) {
      return false;
    }

    // Evaluate condition
    switch (rule.condition.type) {
      case 'new_error':
        return this.isNewError(error);

      case 'threshold':
        return this.exceedsThreshold(rule.condition, error);

      case 'anomaly':
        return this.isAnomaly(rule.condition, error);

      default:
        return false;
    }
  }

  private isNewError(error: CapturedError): boolean {
    if (this.seenFingerprints.has(error.fingerprint)) {
      return false;
    }
    this.seenFingerprints.add(error.fingerprint);
    return true;
  }

  private exceedsThreshold(condition: AlertCondition, error: CapturedError): boolean {
    const countKey = `${error.fingerprint}:${this.getTimeWindow(condition.timeWindowMinutes || 5)}`;
    const count = this.errorCounts.get(countKey) || 0;

    switch (condition.comparison) {
      case 'gt': return count > (condition.threshold || 0);
      case 'gte': return count >= (condition.threshold || 0);
      case 'lt': return count < (condition.threshold || 0);
      case 'lte': return count <= (condition.threshold || 0);
      default: return false;
    }
  }

  private isAnomaly(condition: AlertCondition, error: CapturedError): boolean {
    // Simple anomaly detection: compare to rolling average
    const recentCounts: number[] = [];
    const now = Date.now();

    for (let i = 1; i <= 12; i++) { // Last hour in 5-min windows
      const windowKey = `${error.fingerprint}:${this.getTimeWindow(5, now - i * 5 * 60 * 1000)}`;
      recentCounts.push(this.errorCounts.get(windowKey) || 0);
    }

    const average = recentCounts.reduce((a, b) => a + b, 0) / recentCounts.length;
    const stdDev = Math.sqrt(
      recentCounts.reduce((sum, count) => sum + Math.pow(count - average, 2), 0) / recentCounts.length
    );

    const currentKey = `${error.fingerprint}:${this.getTimeWindow(5)}`;
    const currentCount = this.errorCounts.get(currentKey) || 0;

    // Alert if current count is > 2 standard deviations from mean
    return currentCount > average + 2 * stdDev;
  }

  private isThrottled(rule: AlertRule): boolean {
    const throttleKey = rule.id;
    const throttleData = this.alertCounts.get(throttleKey);
    const now = Date.now();

    if (!throttleData || now > throttleData.resetAt) {
      this.alertCounts.set(throttleKey, {
        count: 1,
        resetAt: now + rule.throttle.windowMinutes * 60 * 1000
      });
      return false;
    }

    if (throttleData.count >= rule.throttle.count) {
      return true;
    }

    throttleData.count++;
    return false;
  }

  private async executeActions(rule: AlertRule, error: CapturedError): Promise<void> {
    for (const action of rule.actions) {
      try {
        await this.executeAction(action, rule, error);
      } catch (e) {
        console.error(`Failed to execute alert action ${action.type}:`, e);
      }
    }
  }

  private async executeAction(
    action: AlertAction,
    rule: AlertRule,
    error: CapturedError
  ): Promise<void> {
    switch (action.type) {
      case 'slack':
        await this.sendSlackAlert(action.config, rule, error);
        break;
      case 'pagerduty':
        await this.sendPagerDutyAlert(action.config, rule, error);
        break;
      case 'email':
        await this.sendEmailAlert(action.config, rule, error);
        break;
      case 'webhook':
        await this.sendWebhookAlert(action.config, rule, error);
        break;
    }
  }

  private async sendSlackAlert(
    config: Record<string, any>,
    rule: AlertRule,
    error: CapturedError
  ): Promise<void> {
    const payload = {
      channel: config.channel,
      attachments: [{
        color: 'danger',
        title: `Alert: ${rule.name}`,
        text: error.message,
        fields: [
          { title: 'Error Type', value: error.type, short: true },
          { title: 'Environment', value: error.context.environment, short: true },
          { title: 'Release', value: error.context.release, short: true },
          { title: 'Error ID', value: error.id, short: true }
        ],
        footer: `Fingerprint: ${error.fingerprint}`,
        ts: Math.floor(error.timestamp.getTime() / 1000)
      }]
    };

    await fetch(config.webhookUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
  }

  private getTimeWindow(minutes: number, timestamp: number = Date.now()): string {
    const windowStart = Math.floor(timestamp / (minutes * 60 * 1000));
    return `${windowStart}`;
  }
}

// Configuration
const alertManager = new AlertManager();

alertManager.addRule({
  id: 'new-error-alert',
  name: 'New Error Type Detected',
  condition: { type: 'new_error' },
  actions: [
    {
      type: 'slack',
      config: {
        channel: '#errors',
        webhookUrl: process.env.SLACK_WEBHOOK_URL
      }
    }
  ],
  throttle: { count: 10, windowMinutes: 60 }
});

alertManager.addRule({
  id: 'error-spike-alert',
  name: 'Error Rate Spike',
  condition: {
    type: 'threshold',
    threshold: 100,
    comparison: 'gt',
    timeWindowMinutes: 5
  },
  actions: [
    {
      type: 'pagerduty',
      config: { routingKey: process.env.PAGERDUTY_KEY }
    }
  ],
  throttle: { count: 1, windowMinutes: 30 }
});
```

**Anti-Pattern**: Alerting on every error without throttling.

### Pattern 4: Source Map Integration

**When to Use**: Debugging minified JavaScript errors

**Example**:
```typescript
import { SourceMapConsumer, RawSourceMap } from 'source-map';

interface SourceMapStore {
  get(release: string, filename: string): Promise<RawSourceMap | null>;
}

class StackTraceParser {
  constructor(private sourceMapStore: SourceMapStore) {}

  async parseAndEnhance(
    stack: string,
    release: string
  ): Promise<EnhancedStackTrace> {
    const frames = this.parseStack(stack);
    const enhancedFrames: EnhancedStackFrame[] = [];

    for (const frame of frames) {
      const enhanced = await this.enhanceFrame(frame, release);
      enhancedFrames.push(enhanced);
    }

    return {
      original: stack,
      frames: enhancedFrames
    };
  }

  private parseStack(stack: string): StackFrame[] {
    const frames: StackFrame[] = [];
    const lines = stack.split('\n');

    for (const line of lines) {
      // Parse Chrome/Node format: "    at functionName (filename:line:column)"
      const match = line.match(/at\s+(.+?)\s+\((.+?):(\d+):(\d+)\)/);
      if (match) {
        frames.push({
          functionName: match[1],
          filename: match[2],
          line: parseInt(match[3]),
          column: parseInt(match[4])
        });
      }
    }

    return frames;
  }

  private async enhanceFrame(
    frame: StackFrame,
    release: string
  ): Promise<EnhancedStackFrame> {
    const sourceMap = await this.sourceMapStore.get(release, frame.filename);

    if (!sourceMap) {
      return {
        ...frame,
        original: frame
      };
    }

    const consumer = await new SourceMapConsumer(sourceMap);

    try {
      const position = consumer.originalPositionFor({
        line: frame.line,
        column: frame.column
      });

      if (position.source) {
        const sourceContent = consumer.sourceContentFor(position.source);

        return {
          functionName: position.name || frame.functionName,
          filename: position.source,
          line: position.line || frame.line,
          column: position.column || frame.column,
          original: frame,
          contextLines: this.getContextLines(sourceContent, position.line || 0)
        };
      }
    } finally {
      consumer.destroy();
    }

    return {
      ...frame,
      original: frame
    };
  }

  private getContextLines(
    source: string | null,
    line: number,
    contextSize: number = 5
  ): string[] | undefined {
    if (!source) return undefined;

    const lines = source.split('\n');
    const start = Math.max(0, line - contextSize - 1);
    const end = Math.min(lines.length, line + contextSize);

    return lines.slice(start, end).map((content, index) => {
      const lineNumber = start + index + 1;
      const prefix = lineNumber === line ? '> ' : '  ';
      return `${prefix}${lineNumber}: ${content}`;
    });
  }
}

interface StackFrame {
  functionName: string;
  filename: string;
  line: number;
  column: number;
}

interface EnhancedStackFrame extends StackFrame {
  original: StackFrame;
  contextLines?: string[];
}

interface EnhancedStackTrace {
  original: string;
  frames: EnhancedStackFrame[];
}

// Upload source maps during build
async function uploadSourceMaps(
  release: string,
  sourceMapDir: string
): Promise<void> {
  const files = await fs.promises.readdir(sourceMapDir);

  for (const file of files) {
    if (file.endsWith('.map')) {
      const content = await fs.promises.readFile(
        path.join(sourceMapDir, file),
        'utf8'
      );

      await fetch('https://errors.example.com/api/sourcemaps', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          release,
          filename: file.replace('.map', ''),
          sourceMap: JSON.parse(content)
        })
      });
    }
  }
}
```

**Anti-Pattern**: Debugging minified stack traces without source maps.

### Pattern 5: Release Tracking

**When to Use**: Correlating errors with deployments

**Example**:
```typescript
interface Release {
  version: string;
  environment: string;
  deployedAt: Date;
  deployedBy: string;
  commits: Commit[];
  previousVersion?: string;
}

interface Commit {
  sha: string;
  message: string;
  author: string;
  timestamp: Date;
}

class ReleaseTracker {
  private releases: Map<string, Release> = new Map();

  async registerRelease(release: Release): Promise<void> {
    this.releases.set(`${release.environment}:${release.version}`, release);

    // Notify monitoring service
    await fetch('https://errors.example.com/api/releases', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(release)
    });
  }

  async trackDeployment(): Promise<void> {
    const version = process.env.APP_VERSION || await this.getGitVersion();
    const environment = process.env.NODE_ENV || 'development';
    const previousRelease = this.releases.get(`${environment}:current`);

    const release: Release = {
      version,
      environment,
      deployedAt: new Date(),
      deployedBy: process.env.DEPLOYED_BY || 'unknown',
      commits: await this.getCommitsSince(previousRelease?.version),
      previousVersion: previousRelease?.version
    };

    await this.registerRelease(release);

    // Mark release as healthy after validation period
    setTimeout(async () => {
      await this.markReleaseHealthy(release);
    }, 5 * 60 * 1000); // 5 minutes
  }

  private async getGitVersion(): Promise<string> {
    const { execSync } = await import('child_process');
    return execSync('git rev-parse --short HEAD').toString().trim();
  }

  private async getCommitsSince(version?: string): Promise<Commit[]> {
    if (!version) return [];

    const { execSync } = await import('child_process');
    const log = execSync(
      `git log ${version}..HEAD --format="%H|%s|%an|%aI"`
    ).toString();

    return log.split('\n')
      .filter(line => line)
      .map(line => {
        const [sha, message, author, timestamp] = line.split('|');
        return { sha, message, author, timestamp: new Date(timestamp) };
      });
  }

  private async markReleaseHealthy(release: Release): Promise<void> {
    // Check error rate during validation period
    const errorRate = await this.getErrorRate(release);

    if (errorRate > 0.01) { // > 1% error rate
      await this.alertOnBadRelease(release, errorRate);
    }
  }

  private async getErrorRate(release: Release): Promise<number> {
    // Query error monitoring service
    const response = await fetch(
      `https://errors.example.com/api/releases/${release.version}/error-rate`
    );
    const data = await response.json();
    return data.errorRate;
  }

  private async alertOnBadRelease(release: Release, errorRate: number): Promise<void> {
    console.error(`Release ${release.version} has high error rate: ${errorRate * 100}%`);
    // Send alert, potentially trigger rollback
  }
}

// CI/CD integration
// In your deployment script:
const releaseTracker = new ReleaseTracker();

async function deploy(): Promise<void> {
  // ... deployment steps ...

  await releaseTracker.trackDeployment();

  console.log('Release tracked, monitoring for errors...');
}
```

**Anti-Pattern**: No release tracking, unable to correlate errors with deployments.

## Checklist

- [ ] Error monitoring service configured
- [ ] Global error handlers set up
- [ ] Request context captured with errors
- [ ] Sensitive data filtered from reports
- [ ] Source maps uploaded for production builds
- [ ] Alerting rules configured
- [ ] Alert throttling enabled
- [ ] Release tracking integrated
- [ ] User context attached to errors
- [ ] Dashboards created for error trends

## References

- [Sentry Error Monitoring](https://docs.sentry.io/)
- [Datadog Error Tracking](https://docs.datadoghq.com/error_tracking/)
- [Source Maps Specification](https://sourcemaps.info/spec.html)
- [OpenTelemetry Error Handling](https://opentelemetry.io/docs/concepts/signals/traces/#span-events)
