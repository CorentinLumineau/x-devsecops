---
title: Debugging Strategies Reference
category: quality
type: reference
version: "1.0.0"
---

# Debugging Strategies

> Part of the quality/debugging knowledge skill

## Overview

Effective debugging requires systematic approaches to identify, isolate, and fix defects. This reference covers debugging methodologies, techniques for different bug types, and tools to accelerate the debugging process.

## 80/20 Quick Reference

**Debugging Methodology:**

| Step | Action | Goal |
|------|--------|------|
| 1. Reproduce | Create minimal repro | Confirm the bug |
| 2. Isolate | Binary search / divide | Narrow scope |
| 3. Hypothesize | Form testable theory | Guide investigation |
| 4. Verify | Test hypothesis | Confirm root cause |
| 5. Fix | Implement solution | Resolve issue |
| 6. Validate | Test fix + regression | Prevent recurrence |

**Bug Type to Strategy:**

| Bug Type | Primary Strategy |
|----------|------------------|
| Crash/Exception | Stack trace analysis |
| Logic error | Step-through debugging |
| Race condition | Logging + timing analysis |
| Performance | Profiling + tracing |
| Memory leak | Heap analysis |
| Integration | Contract/boundary testing |

## Patterns

### Pattern 1: Scientific Debugging Method

**When to Use**: All debugging scenarios

**The Process:**
```
1. OBSERVE: Gather facts about the bug
   - What is the expected behavior?
   - What is the actual behavior?
   - When did it start happening?
   - What changed recently?

2. HYPOTHESIZE: Form a testable theory
   - "I believe X is causing Y because Z"
   - Should be specific and falsifiable

3. EXPERIMENT: Test the hypothesis
   - Design minimal test to prove/disprove
   - Change only one variable at a time
   - Record results

4. ANALYZE: Evaluate results
   - Did the experiment confirm the hypothesis?
   - If not, what did we learn?
   - Form new hypothesis based on evidence

5. REPEAT: Until root cause found
```

**Implementation Example:**
```typescript
// Bug: Users report orders failing intermittently

// Step 1: OBSERVE
// - Orders fail with "Payment timeout" error
// - Happens ~10% of the time
// - Started after deployment on 2024-01-15
// - More frequent during peak hours

// Step 2: HYPOTHESIZE
// Hypothesis 1: Payment gateway is overloaded during peak
// Hypothesis 2: Our connection pool is exhausted
// Hypothesis 3: Network timeout is too aggressive

// Step 3: EXPERIMENT
// Test Hypothesis 1: Check payment gateway metrics
async function investigateGatewayLoad(): Promise<void> {
  // Query payment gateway status API
  const gatewayMetrics = await paymentGateway.getMetrics({
    startTime: '2024-01-15',
    endTime: 'now'
  });

  console.log('Gateway response times:', gatewayMetrics.p99ResponseTime);
  console.log('Gateway error rate:', gatewayMetrics.errorRate);
  // Result: Gateway metrics normal, not the cause
}

// Test Hypothesis 2: Check our connection pool
async function investigateConnectionPool(): Promise<void> {
  const poolMetrics = await db.getPoolMetrics();

  console.log('Active connections:', poolMetrics.active);
  console.log('Waiting requests:', poolMetrics.waiting);
  console.log('Pool size:', poolMetrics.size);
  // Result: Pool often maxed out during peak hours - LIKELY CAUSE
}

// Step 4: ANALYZE
// Connection pool exhaustion confirmed as root cause
// New connections wait, causing timeouts

// Step 5: FIX
// Increase pool size and add connection timeout handling
const dbConfig = {
  pool: {
    min: 10,
    max: 50,  // Increased from 20
    acquireTimeoutMillis: 30000,
    idleTimeoutMillis: 10000
  }
};
```

**Anti-Pattern**: Randomly changing code hoping to fix the bug.

### Pattern 2: Binary Search Debugging

**When to Use**: Bug exists but unclear which change introduced it

**Git Bisect:**
```bash
# Start bisect session
git bisect start

# Mark current commit as bad (has the bug)
git bisect bad

# Mark a known good commit (no bug)
git bisect good v1.2.0

# Git checks out middle commit
# Test if bug exists, then mark

git bisect good  # Bug not present
# or
git bisect bad   # Bug present

# Repeat until Git identifies the problematic commit
# Git will say: "abc123 is the first bad commit"

# End bisect session
git bisect reset
```

**Automated Git Bisect:**
```bash
# Create test script
cat > test-bug.sh << 'EOF'
#!/bin/bash
npm ci
npm test -- --grep "order processing"
EOF
chmod +x test-bug.sh

# Run automated bisect
git bisect start
git bisect bad HEAD
git bisect good v1.2.0
git bisect run ./test-bug.sh

# Git will automatically find the bad commit
```

**Binary Search in Code:**
```typescript
// Bug: Function returns wrong result for some inputs
function complexCalculation(data: Data[]): number {
  // Add binary search checkpoints
  const step1 = processPhase1(data);
  console.log('After phase 1:', step1);  // Checkpoint 1

  const step2 = processPhase2(step1);
  console.log('After phase 2:', step2);  // Checkpoint 2

  const step3 = processPhase3(step2);
  console.log('After phase 3:', step3);  // Checkpoint 3

  return finalCalculation(step3);
}

// If step 2 is wrong but step 1 is correct,
// the bug is in processPhase2

// Then add checkpoints within processPhase2
function processPhase2(input: Phase1Result): Phase2Result {
  const a = transformA(input);
  console.log('After transformA:', a);  // Checkpoint 2a

  const b = transformB(a);
  console.log('After transformB:', b);  // Checkpoint 2b

  return mergeResults(a, b);
}
```

**Anti-Pattern**: Commenting out large blocks of code randomly.

### Pattern 3: Rubber Duck Debugging

**When to Use**: Complex bugs where you're stuck

**The Technique:**
```
1. Explain the code line by line to an inanimate object
   (or colleague, but they don't need to respond)

2. Describe what you EXPECT each line to do

3. Often, the act of explaining reveals assumptions
   that don't match reality
```

**Structured Self-Review:**
```typescript
// Bug: User authentication failing for some users

// Explaining to rubber duck:
async function authenticateUser(credentials: Credentials): Promise<User> {
  // "First, I look up the user by email"
  const user = await userRepository.findByEmail(credentials.email);

  // "If user doesn't exist, throw error"
  if (!user) {
    throw new AuthenticationError('User not found');
  }

  // "Then I hash the provided password and compare"
  const hashedPassword = hashPassword(credentials.password);

  // WAIT - "I'm comparing hashes but..."
  // "The stored password uses bcrypt which includes salt"
  // "But hashPassword() doesn't use the same salt!"
  if (user.passwordHash !== hashedPassword) {
    throw new AuthenticationError('Invalid password');
  }

  // Bug found! Need to use bcrypt.compare() instead
  return user;
}

// Fixed version:
async function authenticateUser(credentials: Credentials): Promise<User> {
  const user = await userRepository.findByEmail(credentials.email);

  if (!user) {
    throw new AuthenticationError('User not found');
  }

  // Correctly compare using bcrypt
  const isValid = await bcrypt.compare(
    credentials.password,
    user.passwordHash
  );

  if (!isValid) {
    throw new AuthenticationError('Invalid password');
  }

  return user;
}
```

**Anti-Pattern**: Not actually explaining the code in detail.

### Pattern 4: Delta Debugging

**When to Use**: Large inputs cause failure, need minimal reproduction

**Minimizing Input:**
```typescript
// Bug: Large JSON payload causes parsing error
// Goal: Find minimal input that triggers the bug

async function findMinimalInput(
  fullInput: string,
  isBuggy: (input: string) => Promise<boolean>
): Promise<string> {
  let current = fullInput;

  // Try removing half at a time
  while (current.length > 10) {
    const half = Math.floor(current.length / 2);

    // Try first half
    const firstHalf = current.slice(0, half);
    if (await isBuggy(firstHalf)) {
      current = firstHalf;
      continue;
    }

    // Try second half
    const secondHalf = current.slice(half);
    if (await isBuggy(secondHalf)) {
      current = secondHalf;
      continue;
    }

    // Neither half triggers bug, try smaller chunks
    break;
  }

  // Fine-grained removal
  for (let i = current.length - 1; i >= 0; i--) {
    const without = current.slice(0, i) + current.slice(i + 1);
    if (await isBuggy(without)) {
      current = without;
    }
  }

  return current;
}

// Usage
const minimalInput = await findMinimalInput(
  hugeJsonString,
  async (input) => {
    try {
      JSON.parse(input);
      return false; // No bug
    } catch {
      return true; // Bug triggered
    }
  }
);

console.log('Minimal buggy input:', minimalInput);
// Result: "{"key":"value\\x00"}"
// Bug: Null byte in string not handled
```

**Code Delta Debugging:**
```typescript
// Finding minimal code change that introduces bug
interface CodeChange {
  file: string;
  line: number;
  change: string;
}

async function findMinimalChanges(
  changes: CodeChange[],
  triggersBug: (changes: CodeChange[]) => Promise<boolean>
): Promise<CodeChange[]> {
  // Start with all changes
  if (!(await triggersBug(changes))) {
    return []; // No bug with all changes
  }

  // Binary search to minimize
  let current = [...changes];

  while (current.length > 1) {
    const mid = Math.floor(current.length / 2);
    const firstHalf = current.slice(0, mid);
    const secondHalf = current.slice(mid);

    if (await triggersBug(firstHalf)) {
      current = firstHalf;
    } else if (await triggersBug(secondHalf)) {
      current = secondHalf;
    } else {
      // Bug requires combination from both halves
      // Try removing one change at a time
      for (let i = current.length - 1; i >= 0; i--) {
        const without = [...current.slice(0, i), ...current.slice(i + 1)];
        if (await triggersBug(without)) {
          current = without;
          break;
        }
      }
      break;
    }
  }

  return current;
}
```

**Anti-Pattern**: Working with full complex input instead of minimizing.

### Pattern 5: Logging-Based Debugging

**When to Use**: Production bugs, race conditions, async issues

**Strategic Logging:**
```typescript
// Structured logging for debugging
interface DebugContext {
  requestId: string;
  userId?: string;
  operation: string;
  timestamp: number;
}

class DebugLogger {
  private context: DebugContext;

  constructor(operation: string, requestId?: string) {
    this.context = {
      requestId: requestId || crypto.randomUUID(),
      operation,
      timestamp: Date.now()
    };
  }

  setUser(userId: string): void {
    this.context.userId = userId;
  }

  trace(message: string, data?: Record<string, any>): void {
    console.log(JSON.stringify({
      level: 'trace',
      ...this.context,
      message,
      data,
      elapsed: Date.now() - this.context.timestamp
    }));
  }

  checkpoint(name: string, data?: Record<string, any>): void {
    console.log(JSON.stringify({
      level: 'debug',
      ...this.context,
      checkpoint: name,
      data,
      elapsed: Date.now() - this.context.timestamp
    }));
  }
}

// Usage for debugging async flow
async function processOrder(order: Order): Promise<Result> {
  const debug = new DebugLogger('processOrder', order.requestId);
  debug.setUser(order.userId);

  debug.checkpoint('start', { orderId: order.id });

  const inventory = await checkInventory(order.items);
  debug.checkpoint('inventory_checked', {
    available: inventory.available,
    reserved: inventory.reserved
  });

  if (!inventory.available) {
    debug.trace('order_rejected', { reason: 'out_of_stock' });
    return { status: 'rejected' };
  }

  const payment = await processPayment(order);
  debug.checkpoint('payment_processed', {
    transactionId: payment.transactionId,
    status: payment.status
  });

  if (payment.status !== 'success') {
    debug.trace('payment_failed', { error: payment.error });
    await releaseInventory(inventory.reservationId);
    return { status: 'payment_failed' };
  }

  debug.checkpoint('complete', { orderId: order.id });
  return { status: 'success' };
}
```

**Log Correlation:**
```typescript
// Correlate logs across services
class CorrelatedLogger {
  constructor(
    private serviceName: string,
    private correlationId: string
  ) {}

  log(event: string, data: Record<string, any>): void {
    console.log(JSON.stringify({
      service: this.serviceName,
      correlationId: this.correlationId,
      event,
      timestamp: new Date().toISOString(),
      ...data
    }));
  }

  // Pass correlation ID to downstream services
  getHeaders(): Record<string, string> {
    return {
      'X-Correlation-ID': this.correlationId
    };
  }
}

// Query correlated logs
// grep "correlationId.*abc-123" /var/log/app/*.log | sort -t: -k2
```

**Anti-Pattern**: Adding too many logs without structure, making them hard to analyze.

### Pattern 6: Debugging Tools and Techniques

**When to Use**: Interactive debugging sessions

**Node.js Debugger:**
```typescript
// Add debugger statement
function calculateTotal(items: Item[]): number {
  let total = 0;

  for (const item of items) {
    debugger; // Execution pauses here
    total += item.price * item.quantity;
  }

  return total;
}

// Run with debugger
// node --inspect-brk dist/index.js

// Or with VS Code launch.json:
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Debug",
      "program": "${workspaceFolder}/src/index.ts",
      "preLaunchTask": "tsc: build",
      "outFiles": ["${workspaceFolder}/dist/**/*.js"],
      "sourceMaps": true,
      "console": "integratedTerminal"
    },
    {
      "type": "node",
      "request": "launch",
      "name": "Debug Tests",
      "program": "${workspaceFolder}/node_modules/.bin/jest",
      "args": ["--runInBand", "--no-cache", "${file}"],
      "console": "integratedTerminal"
    }
  ]
}
```

**Conditional Breakpoints:**
```typescript
// VS Code conditional breakpoint
// Break only when condition is true
function processUsers(users: User[]): void {
  for (const user of users) {
    // Set breakpoint with condition: user.id === 'problematic-user-123'
    processUser(user);
  }
}

// Logpoint (logs without stopping)
// Log message: "Processing user: {user.id}, status: {user.status}"
```

**Chrome DevTools for Node:**
```bash
# Start with inspector
node --inspect src/index.js

# Open chrome://inspect in Chrome
# Click "inspect" on your Node process

# Set breakpoints, watch expressions, profile
```

**Error Boundaries and Context:**
```typescript
// Wrap operations with context
class OperationContext {
  private breadcrumbs: string[] = [];

  addBreadcrumb(message: string): void {
    this.breadcrumbs.push(`${new Date().toISOString()}: ${message}`);
  }

  async execute<T>(
    operation: string,
    fn: () => Promise<T>
  ): Promise<T> {
    this.addBreadcrumb(`Starting: ${operation}`);

    try {
      const result = await fn();
      this.addBreadcrumb(`Completed: ${operation}`);
      return result;
    } catch (error) {
      this.addBreadcrumb(`Failed: ${operation}`);

      // Enhance error with context
      const enhancedError = new Error(
        `Operation "${operation}" failed: ${error.message}`
      );
      (enhancedError as any).breadcrumbs = this.breadcrumbs;
      (enhancedError as any).originalError = error;

      throw enhancedError;
    }
  }
}

// Usage
const ctx = new OperationContext();

await ctx.execute('fetch_user', () => fetchUser(userId));
await ctx.execute('validate_permissions', () => checkPermissions(user));
await ctx.execute('process_request', () => handleRequest(user, request));

// On error, breadcrumbs show exactly where it failed
```

**Anti-Pattern**: Using only console.log when debugger would be more effective.

## Checklist

- [ ] Bug is reproducible before debugging
- [ ] Hypothesis formed before making changes
- [ ] Only one variable changed at a time
- [ ] Minimal reproduction case created
- [ ] Root cause identified, not just symptom
- [ ] Fix verified with test
- [ ] Regression test added
- [ ] Debug logging removed after fix
- [ ] Documentation updated if needed
- [ ] Similar code checked for same bug

## References

- [Debugging: The 9 Indispensable Rules](https://www.amazon.com/Debugging-Indispensable-Rules-Finding-Software/dp/0814474578)
- [Why Programs Fail: A Guide to Systematic Debugging](https://www.amazon.com/Why-Programs-Fail-Systematic-Debugging/dp/0123745152)
- [Node.js Debugging Guide](https://nodejs.org/en/docs/guides/debugging-getting-started)
- [VS Code Debugging](https://code.visualstudio.com/docs/editor/debugging)
