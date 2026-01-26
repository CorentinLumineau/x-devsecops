---
title: Performance Debugging Reference
category: quality
type: reference
version: "1.0.0"
---

# Performance Debugging

> Part of the quality/debugging knowledge skill

## Overview

Performance debugging identifies and resolves bottlenecks that cause slow response times, high resource usage, or degraded user experience. This reference covers profiling techniques, common performance issues, and optimization strategies.

## 80/20 Quick Reference

**Performance Issue Types:**

| Issue | Symptoms | Primary Tool |
|-------|----------|--------------|
| CPU-bound | High CPU, slow execution | CPU profiler |
| Memory-bound | High memory, GC pauses | Heap profiler |
| I/O-bound | Waiting on disk/network | Async profiler |
| Concurrency | Deadlocks, contention | Thread profiler |
| N+1 queries | Slow DB operations | Query analyzer |

**Performance Debugging Flow:**

| Step | Action | Goal |
|------|--------|------|
| 1. Measure | Establish baseline | Know starting point |
| 2. Profile | Identify hotspots | Find bottlenecks |
| 3. Analyze | Understand root cause | Determine fix |
| 4. Optimize | Implement improvement | Improve performance |
| 5. Verify | Compare to baseline | Confirm improvement |

## Patterns

### Pattern 1: CPU Profiling

**When to Use**: High CPU usage, slow computation

**Node.js Built-in Profiler:**
```bash
# Generate V8 profiler output
node --prof app.js

# Process the output
node --prof-process isolate-*.log > profile.txt

# Key sections to analyze:
# [JavaScript]: Time in JS code
# [C++]: Time in native code
# [Summary]: Overall breakdown
# [Bottom up]: Most expensive functions
```

**Programmatic Profiling:**
```typescript
import { Session } from 'inspector';
import { writeFileSync } from 'fs';

class CPUProfiler {
  private session: Session;

  constructor() {
    this.session = new Session();
    this.session.connect();
  }

  async profile<T>(
    name: string,
    fn: () => Promise<T>
  ): Promise<{ result: T; profile: any }> {
    // Enable profiler
    this.session.post('Profiler.enable');

    // Start profiling
    this.session.post('Profiler.start');

    const result = await fn();

    // Stop and get profile
    return new Promise((resolve) => {
      this.session.post('Profiler.stop', (err, { profile }) => {
        // Save profile for Chrome DevTools
        writeFileSync(
          `${name}-${Date.now()}.cpuprofile`,
          JSON.stringify(profile)
        );

        resolve({ result, profile });
      });
    });
  }

  analyzeProfile(profile: any): ProfileAnalysis {
    const nodes = profile.nodes;
    const samples = profile.samples;
    const timeDeltas = profile.timeDeltas;

    // Build call tree
    const nodeMap = new Map(nodes.map((n: any) => [n.id, n]));

    // Calculate time per function
    const timings: Map<string, number> = new Map();

    for (let i = 0; i < samples.length; i++) {
      const nodeId = samples[i];
      const node = nodeMap.get(nodeId);
      const time = timeDeltas[i];

      const funcName = node.callFrame.functionName || '(anonymous)';
      const current = timings.get(funcName) || 0;
      timings.set(funcName, current + time);
    }

    // Sort by time
    const sorted = [...timings.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 20);

    return {
      totalTime: timeDeltas.reduce((a: number, b: number) => a + b, 0),
      hotspots: sorted.map(([name, time]) => ({
        function: name,
        time,
        percentage: (time / profile.endTime) * 100
      }))
    };
  }
}

// Usage
const profiler = new CPUProfiler();

const { result, profile } = await profiler.profile(
  'order-processing',
  async () => processLargeOrder(order)
);

const analysis = profiler.analyzeProfile(profile);
console.log('Hotspots:', analysis.hotspots);
```

**Identifying CPU Hotspots:**
```typescript
// Common CPU-bound issues

// Issue 1: Inefficient algorithm
// O(n²) when O(n) is possible
function findDuplicatesSlow(items: string[]): string[] {
  const duplicates: string[] = [];
  for (let i = 0; i < items.length; i++) {
    for (let j = i + 1; j < items.length; j++) {
      if (items[i] === items[j] && !duplicates.includes(items[i])) {
        duplicates.push(items[i]);
      }
    }
  }
  return duplicates;
}

// Fixed: O(n)
function findDuplicatesFast(items: string[]): string[] {
  const seen = new Set<string>();
  const duplicates = new Set<string>();

  for (const item of items) {
    if (seen.has(item)) {
      duplicates.add(item);
    }
    seen.add(item);
  }

  return [...duplicates];
}

// Issue 2: Excessive object creation
function processDataSlow(data: Data[]): Result[] {
  return data.map(item => {
    // Creates new object for each transformation
    const step1 = { ...item, processed: true };
    const step2 = { ...step1, timestamp: Date.now() };
    const step3 = { ...step2, hash: computeHash(step2) };
    return step3;
  });
}

// Fixed: Mutate in place or single transformation
function processDataFast(data: Data[]): Result[] {
  return data.map(item => ({
    ...item,
    processed: true,
    timestamp: Date.now(),
    hash: computeHash(item)
  }));
}

// Issue 3: Synchronous operations in loop
async function fetchAllSlow(ids: string[]): Promise<Data[]> {
  const results: Data[] = [];
  for (const id of ids) {
    results.push(await fetchData(id)); // Sequential!
  }
  return results;
}

// Fixed: Parallel with concurrency control
async function fetchAllFast(ids: string[]): Promise<Data[]> {
  const CONCURRENCY = 10;
  const results: Data[] = [];

  for (let i = 0; i < ids.length; i += CONCURRENCY) {
    const batch = ids.slice(i, i + CONCURRENCY);
    const batchResults = await Promise.all(
      batch.map(id => fetchData(id))
    );
    results.push(...batchResults);
  }

  return results;
}
```

**Anti-Pattern**: Optimizing without profiling first.

### Pattern 2: Memory Profiling

**When to Use**: High memory usage, memory leaks, GC pauses

**Heap Snapshot Analysis:**
```typescript
import { writeHeapSnapshot } from 'v8';

class MemoryProfiler {
  private baseline: number = 0;

  takeSnapshot(name: string): string {
    // Force GC before snapshot (requires --expose-gc)
    if (global.gc) {
      global.gc();
    }

    const filename = writeHeapSnapshot();
    console.log(`Heap snapshot written to: ${filename}`);

    return filename;
  }

  getMemoryUsage(): MemoryUsage {
    const usage = process.memoryUsage();
    return {
      heapUsed: usage.heapUsed / 1024 / 1024, // MB
      heapTotal: usage.heapTotal / 1024 / 1024,
      external: usage.external / 1024 / 1024,
      rss: usage.rss / 1024 / 1024
    };
  }

  trackMemory(interval: number = 1000): () => MemoryHistory {
    const history: MemoryUsage[] = [];

    const timer = setInterval(() => {
      history.push(this.getMemoryUsage());
    }, interval);

    return () => {
      clearInterval(timer);
      return {
        samples: history,
        peak: Math.max(...history.map(h => h.heapUsed)),
        growth: history[history.length - 1].heapUsed - history[0].heapUsed
      };
    };
  }

  async profileFunction<T>(
    name: string,
    fn: () => Promise<T>
  ): Promise<{ result: T; memory: MemoryProfile }> {
    const before = this.getMemoryUsage();

    // Take before snapshot
    const beforeSnapshot = this.takeSnapshot(`${name}-before`);

    const result = await fn();

    // Take after snapshot
    const afterSnapshot = this.takeSnapshot(`${name}-after`);

    const after = this.getMemoryUsage();

    return {
      result,
      memory: {
        before,
        after,
        delta: {
          heapUsed: after.heapUsed - before.heapUsed,
          heapTotal: after.heapTotal - before.heapTotal
        },
        snapshots: [beforeSnapshot, afterSnapshot]
      }
    };
  }
}

// Usage
const profiler = new MemoryProfiler();

const stopTracking = profiler.trackMemory(100);

// Run the potentially leaky operation
await processLargeDataset(data);

const history = stopTracking();
console.log('Memory growth:', history.growth, 'MB');
console.log('Peak usage:', history.peak, 'MB');
```

**Common Memory Leaks:**
```typescript
// Leak 1: Event listener accumulation
class LeakyService {
  private emitter = new EventEmitter();

  handleRequest(request: Request): void {
    // BAD: New listener added each request, never removed
    this.emitter.on('data', (data) => {
      this.processData(request, data);
    });
  }
}

// Fixed: Remove listeners or use once
class FixedService {
  private emitter = new EventEmitter();

  handleRequest(request: Request): void {
    const handler = (data: any) => {
      this.processData(request, data);
    };

    this.emitter.once('data', handler); // Auto-removes after first call

    // Or manually manage
    // this.emitter.on('data', handler);
    // request.on('close', () => this.emitter.off('data', handler));
  }
}

// Leak 2: Closure holding references
class CacheManager {
  private cache = new Map<string, any>();

  // BAD: Closure holds reference to entire response object
  cacheResponse(key: string, response: LargeResponse): void {
    this.cache.set(key, {
      data: response.data,
      timestamp: Date.now(),
      // Closure captures entire 'response' even though we only need 'data'
      getData: () => response.data
    });
  }
}

// Fixed: Don't capture unnecessary references
class FixedCacheManager {
  private cache = new Map<string, any>();

  cacheResponse(key: string, response: LargeResponse): void {
    const data = response.data; // Extract what we need
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      getData: () => data // Closure only captures 'data'
    });
  }
}

// Leak 3: Unbounded cache growth
class UnboundedCache {
  private cache = new Map<string, any>();

  set(key: string, value: any): void {
    this.cache.set(key, value); // Grows forever!
  }
}

// Fixed: LRU cache with max size
class BoundedCache {
  private cache = new Map<string, any>();
  private maxSize: number;

  constructor(maxSize: number = 1000) {
    this.maxSize = maxSize;
  }

  set(key: string, value: any): void {
    if (this.cache.size >= this.maxSize) {
      // Remove oldest entry (first inserted)
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
    }
    this.cache.set(key, value);
  }
}

// Leak 4: Timer references
class LeakyScheduler {
  schedule(task: () => void): void {
    // BAD: No way to cancel, keeps references
    setInterval(task, 1000);
  }
}

// Fixed: Track and cleanup timers
class FixedScheduler {
  private timers: Set<NodeJS.Timer> = new Set();

  schedule(task: () => void): () => void {
    const timer = setInterval(task, 1000);
    this.timers.add(timer);

    return () => {
      clearInterval(timer);
      this.timers.delete(timer);
    };
  }

  cleanup(): void {
    for (const timer of this.timers) {
      clearInterval(timer);
    }
    this.timers.clear();
  }
}
```

**Anti-Pattern**: Ignoring memory growth in long-running services.

### Pattern 3: I/O and Async Profiling

**When to Use**: Slow network/database operations, async bottlenecks

**Async Hooks Profiling:**
```typescript
import { AsyncLocalStorage } from 'async_hooks';

interface AsyncOperation {
  type: string;
  start: number;
  end?: number;
  duration?: number;
}

class AsyncProfiler {
  private operations: Map<number, AsyncOperation> = new Map();
  private storage = new AsyncLocalStorage<{ traceId: string }>();

  enable(): void {
    const asyncHooks = require('async_hooks');

    const hook = asyncHooks.createHook({
      init: (asyncId: number, type: string) => {
        this.operations.set(asyncId, {
          type,
          start: performance.now()
        });
      },
      destroy: (asyncId: number) => {
        const op = this.operations.get(asyncId);
        if (op) {
          op.end = performance.now();
          op.duration = op.end - op.start;
        }
      }
    });

    hook.enable();
  }

  getSlowOperations(threshold: number = 100): AsyncOperation[] {
    return [...this.operations.values()]
      .filter(op => op.duration && op.duration > threshold)
      .sort((a, b) => (b.duration || 0) - (a.duration || 0));
  }
}
```

**Request Timing Breakdown:**
```typescript
interface TimingBreakdown {
  total: number;
  phases: {
    name: string;
    duration: number;
    percentage: number;
  }[];
}

class RequestTimer {
  private startTime: number;
  private phases: Array<{ name: string; start: number; end?: number }> = [];
  private currentPhase?: string;

  constructor() {
    this.startTime = performance.now();
  }

  startPhase(name: string): void {
    if (this.currentPhase) {
      this.endPhase();
    }
    this.currentPhase = name;
    this.phases.push({ name, start: performance.now() });
  }

  endPhase(): void {
    const phase = this.phases[this.phases.length - 1];
    if (phase && !phase.end) {
      phase.end = performance.now();
    }
    this.currentPhase = undefined;
  }

  getBreakdown(): TimingBreakdown {
    this.endPhase();
    const total = performance.now() - this.startTime;

    return {
      total,
      phases: this.phases.map(phase => ({
        name: phase.name,
        duration: (phase.end || performance.now()) - phase.start,
        percentage: (((phase.end || performance.now()) - phase.start) / total) * 100
      }))
    };
  }
}

// Usage in request handler
async function handleRequest(req: Request): Promise<Response> {
  const timer = new RequestTimer();

  timer.startPhase('auth');
  const user = await authenticateRequest(req);

  timer.startPhase('validation');
  const data = await validateRequestData(req.body);

  timer.startPhase('database');
  const result = await queryDatabase(data);

  timer.startPhase('processing');
  const processed = processResult(result);

  timer.startPhase('serialization');
  const response = serializeResponse(processed);

  const breakdown = timer.getBreakdown();
  console.log('Request timing:', breakdown);
  // { total: 245, phases: [
  //   { name: 'auth', duration: 50, percentage: 20.4 },
  //   { name: 'validation', duration: 10, percentage: 4.1 },
  //   { name: 'database', duration: 150, percentage: 61.2 },  // BOTTLENECK
  //   { name: 'processing', duration: 20, percentage: 8.2 },
  //   { name: 'serialization', duration: 15, percentage: 6.1 }
  // ]}

  return response;
}
```

**Database Query Profiling:**
```typescript
class QueryProfiler {
  private queries: Array<{
    sql: string;
    duration: number;
    rowCount: number;
    timestamp: Date;
  }> = [];

  wrap<T extends (...args: any[]) => Promise<any>>(
    queryFn: T
  ): T {
    return (async (...args: any[]) => {
      const sql = args[0];
      const start = performance.now();

      const result = await queryFn(...args);

      const duration = performance.now() - start;
      this.queries.push({
        sql,
        duration,
        rowCount: result.rowCount || result.length || 0,
        timestamp: new Date()
      });

      // Log slow queries
      if (duration > 100) {
        console.warn('Slow query detected:', {
          sql: sql.slice(0, 100),
          duration,
          rowCount: result.rowCount
        });
      }

      return result;
    }) as T;
  }

  getSlowQueries(threshold: number = 100): typeof this.queries {
    return this.queries
      .filter(q => q.duration > threshold)
      .sort((a, b) => b.duration - a.duration);
  }

  getNPlusOnePatterns(): Map<string, number> {
    // Detect N+1 query patterns
    const patterns = new Map<string, number>();

    for (const query of this.queries) {
      // Normalize query (remove specific IDs)
      const normalized = query.sql
        .replace(/\d+/g, '?')
        .replace(/'[^']*'/g, '?');

      const count = patterns.get(normalized) || 0;
      patterns.set(normalized, count + 1);
    }

    // Return patterns executed more than 10 times
    return new Map(
      [...patterns.entries()].filter(([, count]) => count > 10)
    );
  }
}
```

**Anti-Pattern**: Not measuring actual I/O time, guessing at bottlenecks.

### Pattern 4: Application Performance Monitoring

**When to Use**: Production performance tracking

**Custom APM Implementation:**
```typescript
interface Transaction {
  id: string;
  name: string;
  type: string;
  startTime: number;
  endTime?: number;
  spans: Span[];
  metadata: Record<string, any>;
}

interface Span {
  id: string;
  name: string;
  type: string;
  startTime: number;
  endTime?: number;
  metadata: Record<string, any>;
}

class APM {
  private transactions: Map<string, Transaction> = new Map();
  private currentTransaction?: Transaction;

  startTransaction(name: string, type: string): Transaction {
    const transaction: Transaction = {
      id: crypto.randomUUID(),
      name,
      type,
      startTime: performance.now(),
      spans: [],
      metadata: {}
    };

    this.transactions.set(transaction.id, transaction);
    this.currentTransaction = transaction;

    return transaction;
  }

  endTransaction(transaction: Transaction): void {
    transaction.endTime = performance.now();

    // Report to monitoring service
    this.report(transaction);
  }

  startSpan(name: string, type: string): Span {
    const span: Span = {
      id: crypto.randomUUID(),
      name,
      type,
      startTime: performance.now(),
      metadata: {}
    };

    if (this.currentTransaction) {
      this.currentTransaction.spans.push(span);
    }

    return span;
  }

  endSpan(span: Span): void {
    span.endTime = performance.now();
  }

  private report(transaction: Transaction): void {
    const duration = (transaction.endTime || performance.now()) -
                    transaction.startTime;

    const spanSummary = transaction.spans.map(span => ({
      name: span.name,
      type: span.type,
      duration: (span.endTime || performance.now()) - span.startTime
    }));

    console.log('Transaction:', {
      name: transaction.name,
      type: transaction.type,
      duration,
      spans: spanSummary
    });

    // Send to monitoring service (DataDog, New Relic, etc.)
    // await this.sendMetrics(transaction);
  }
}

// Usage with middleware
function apmMiddleware(apm: APM) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const transaction = apm.startTransaction(
      `${req.method} ${req.path}`,
      'request'
    );

    transaction.metadata = {
      method: req.method,
      path: req.path,
      userAgent: req.headers['user-agent']
    };

    // Override res.end to capture when response completes
    const originalEnd = res.end;
    res.end = function(...args: any[]) {
      transaction.metadata.statusCode = res.statusCode;
      apm.endTransaction(transaction);
      return originalEnd.apply(res, args);
    };

    next();
  };
}

// Usage in service
class OrderService {
  constructor(private apm: APM) {}

  async processOrder(order: Order): Promise<Result> {
    const dbSpan = this.apm.startSpan('fetch_customer', 'db');
    const customer = await this.db.findCustomer(order.customerId);
    this.apm.endSpan(dbSpan);

    const paymentSpan = this.apm.startSpan('process_payment', 'external');
    const payment = await this.paymentGateway.charge(customer, order.total);
    this.apm.endSpan(paymentSpan);

    const emailSpan = this.apm.startSpan('send_confirmation', 'external');
    await this.emailService.sendConfirmation(customer, order);
    this.apm.endSpan(emailSpan);

    return { success: true };
  }
}
```

**Anti-Pattern**: No production monitoring, only discovering issues from user complaints.

## Checklist

- [ ] Baseline performance measured before optimization
- [ ] CPU profiler used for computation-heavy code
- [ ] Memory profiler used for long-running services
- [ ] I/O operations timed and analyzed
- [ ] Database queries profiled for N+1 patterns
- [ ] Async operations tracked for bottlenecks
- [ ] Performance regression tests in place
- [ ] APM monitoring in production
- [ ] Performance budgets defined
- [ ] Optimizations verified with benchmarks

## References

- [Node.js Profiling Guide](https://nodejs.org/en/docs/guides/simple-profiling)
- [Chrome DevTools Performance](https://developer.chrome.com/docs/devtools/performance)
- [V8 Memory Profiling](https://v8.dev/docs/memory-profiling)
- [Clinic.js Performance Toolkit](https://clinicjs.org/)
