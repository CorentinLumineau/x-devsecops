---
title: Test Coverage Strategies Reference
category: quality
type: reference
version: "1.0.0"
---

# Test Coverage Strategies

> Part of the quality/testing knowledge skill

## Overview

Test coverage measures how much of your code is executed during testing. This reference covers coverage metrics, strategies for meaningful coverage, and tools for measuring and improving coverage.

## 80/20 Quick Reference

**Coverage Types:**

| Metric | Description | Target |
|--------|-------------|--------|
| Line Coverage | Lines executed | 80%+ |
| Branch Coverage | Decision paths taken | 75%+ |
| Function Coverage | Functions called | 90%+ |
| Statement Coverage | Statements executed | 80%+ |
| Mutation Coverage | Tests catch code changes | 60%+ |

**Coverage Strategy by Code Type:**

| Code Type | Priority | Target Coverage |
|-----------|----------|-----------------|
| Business Logic | Critical | 90%+ |
| API Handlers | High | 85%+ |
| Utilities | High | 95%+ |
| Data Access | Medium | 80%+ |
| Configuration | Low | 60%+ |
| Generated Code | Skip | Exclude |

## Patterns

### Pattern 1: Coverage Configuration

**When to Use**: Setting up coverage measurement

**Jest Configuration:**
```javascript
// jest.config.js
module.exports = {
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html', 'json-summary'],

  // Coverage thresholds
  coverageThreshold: {
    global: {
      branches: 75,
      functions: 80,
      lines: 80,
      statements: 80
    },
    // Per-path thresholds for critical code
    './src/core/**/*.ts': {
      branches: 90,
      functions: 95,
      lines: 90,
      statements: 90
    },
    './src/utils/**/*.ts': {
      branches: 85,
      functions: 90,
      lines: 85,
      statements: 85
    }
  },

  // Files to collect coverage from
  collectCoverageFrom: [
    'src/**/*.{js,ts}',
    '!src/**/*.d.ts',
    '!src/**/*.test.{js,ts}',
    '!src/**/*.spec.{js,ts}',
    '!src/**/index.{js,ts}',
    '!src/types/**/*',
    '!src/generated/**/*',
    '!src/**/__mocks__/**/*'
  ],

  // Path patterns to ignore
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/__tests__/',
    '/coverage/'
  ]
};
```

**Vitest Configuration:**
```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: {
      provider: 'v8', // or 'istanbul'
      reporter: ['text', 'json', 'html', 'lcov'],
      reportsDirectory: './coverage',

      // Thresholds
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 75,
        statements: 80
      },

      // Include/exclude
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'src/**/*.d.ts',
        'src/**/*.test.{ts,tsx}',
        'src/**/index.ts',
        'src/types/**',
        'src/generated/**'
      ],

      // Report all files even without tests
      all: true,

      // Fail on threshold breach
      checkCoverage: true
    }
  }
});
```

**NYC (Istanbul) Configuration:**
```json
{
  "nyc": {
    "extends": "@istanbuljs/nyc-config-typescript",
    "all": true,
    "check-coverage": true,
    "branches": 75,
    "lines": 80,
    "functions": 80,
    "statements": 80,
    "reporter": ["text", "lcov", "html"],
    "include": ["src/**/*.ts"],
    "exclude": [
      "**/*.d.ts",
      "**/*.test.ts",
      "**/index.ts",
      "src/types/**",
      "src/generated/**"
    ],
    "report-dir": "coverage"
  }
}
```

**Anti-Pattern**: No coverage thresholds or thresholds set too low/high.

### Pattern 2: Branch Coverage Strategy

**When to Use**: Ensuring all code paths are tested

**Identify Branches:**
```typescript
// This function has 8 branches (2^3 combinations)
function processOrder(order: Order): Result {
  // Branch 1: valid vs invalid order
  if (!isValidOrder(order)) {
    return { status: 'INVALID' };
  }

  // Branch 2: express vs standard shipping
  if (order.isExpress) {
    applyExpressShipping(order);
  }

  // Branch 3: discount vs no discount
  if (order.couponCode) {
    applyDiscount(order, order.couponCode);
  }

  return { status: 'PROCESSED', order };
}
```

**Test All Branches:**
```typescript
describe('processOrder', () => {
  // Branch: Invalid order
  it('should return INVALID for invalid order', () => {
    const order = createOrder({ valid: false });
    expect(processOrder(order).status).toBe('INVALID');
  });

  // Branch: Valid, no express, no discount
  it('should process standard order without discount', () => {
    const order = createOrder({
      valid: true,
      isExpress: false,
      couponCode: null
    });
    const result = processOrder(order);
    expect(result.status).toBe('PROCESSED');
  });

  // Branch: Valid, express, no discount
  it('should apply express shipping', () => {
    const order = createOrder({
      valid: true,
      isExpress: true,
      couponCode: null
    });
    const result = processOrder(order);
    expect(result.order.shippingMethod).toBe('EXPRESS');
  });

  // Branch: Valid, no express, with discount
  it('should apply discount coupon', () => {
    const order = createOrder({
      valid: true,
      isExpress: false,
      couponCode: 'SAVE10'
    });
    const result = processOrder(order);
    expect(result.order.discount).toBeGreaterThan(0);
  });

  // Branch: Valid, express, with discount
  it('should apply both express and discount', () => {
    const order = createOrder({
      valid: true,
      isExpress: true,
      couponCode: 'SAVE10'
    });
    const result = processOrder(order);
    expect(result.order.shippingMethod).toBe('EXPRESS');
    expect(result.order.discount).toBeGreaterThan(0);
  });
});
```

**Coverage for Complex Conditions:**
```typescript
// Complex condition with short-circuit evaluation
function canAccessResource(user: User, resource: Resource): boolean {
  // 4 branches: each || and && creates branches
  return user.isAdmin ||
         (user.role === resource.requiredRole && resource.isPublic) ||
         user.permissions.includes(resource.id);
}

describe('canAccessResource', () => {
  // Branch 1: Admin user (short-circuits)
  it('should allow admin access', () => {
    const user = { isAdmin: true, role: 'user', permissions: [] };
    const resource = { requiredRole: 'editor', isPublic: false, id: 'r1' };
    expect(canAccessResource(user, resource)).toBe(true);
  });

  // Branch 2: Matching role + public resource
  it('should allow matching role for public resource', () => {
    const user = { isAdmin: false, role: 'editor', permissions: [] };
    const resource = { requiredRole: 'editor', isPublic: true, id: 'r1' };
    expect(canAccessResource(user, resource)).toBe(true);
  });

  // Branch 3: Matching role but private resource
  it('should deny matching role for private resource', () => {
    const user = { isAdmin: false, role: 'editor', permissions: [] };
    const resource = { requiredRole: 'editor', isPublic: false, id: 'r1' };
    expect(canAccessResource(user, resource)).toBe(false);
  });

  // Branch 4: Permission-based access
  it('should allow permission-based access', () => {
    const user = { isAdmin: false, role: 'user', permissions: ['r1'] };
    const resource = { requiredRole: 'editor', isPublic: false, id: 'r1' };
    expect(canAccessResource(user, resource)).toBe(true);
  });

  // Branch 5: No access
  it('should deny access when no criteria met', () => {
    const user = { isAdmin: false, role: 'user', permissions: [] };
    const resource = { requiredRole: 'editor', isPublic: false, id: 'r1' };
    expect(canAccessResource(user, resource)).toBe(false);
  });
});
```

**Anti-Pattern**: Only testing the happy path, ignoring error branches.

### Pattern 3: Mutation Testing

**When to Use**: Verifying test quality, not just quantity

**Stryker Configuration:**
```javascript
// stryker.conf.js
module.exports = {
  packageManager: 'npm',
  reporters: ['html', 'progress', 'dashboard'],
  testRunner: 'jest',
  coverageAnalysis: 'perTest',

  mutate: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/*.test.ts',
    '!src/**/index.ts'
  ],

  // Mutators to apply
  mutator: {
    excludedMutations: [
      'StringLiteral', // Skip string mutations
      'ArrayDeclaration' // Skip array mutations
    ]
  },

  // Thresholds
  thresholds: {
    high: 80,
    low: 60,
    break: 50 // Fail if below 50%
  },

  // Performance
  concurrency: 4,
  timeoutMS: 10000
};
```

**Understanding Mutation Results:**
```typescript
// Original code
function calculateDiscount(price: number, percentage: number): number {
  if (percentage < 0 || percentage > 100) {
    throw new Error('Invalid percentage');
  }
  return price * (percentage / 100);
}

// Mutation: Changed < to <=
// Survives if no test checks percentage === 0
function calculateDiscount(price: number, percentage: number): number {
  if (percentage <= 0 || percentage > 100) {  // Mutated!
    throw new Error('Invalid percentage');
  }
  return price * (percentage / 100);
}

// Test that kills the mutant
it('should allow 0% discount', () => {
  expect(calculateDiscount(100, 0)).toBe(0);
});
```

**Interpreting Mutation Score:**
```
Mutation Score: 75%
- 100 mutants generated
- 75 killed (detected by tests)
- 20 survived (tests didn't catch)
- 5 timeout (infinite loops, etc.)

Survived Mutants (investigate these):
1. Line 15: Changed === to !== (equality mutation)
2. Line 23: Removed return statement
3. Line 31: Changed + to - (arithmetic mutation)
```

**Anti-Pattern**: Chasing 100% mutation score on non-critical code.

### Pattern 4: Coverage-Driven Development

**When to Use**: Systematically improving coverage

**Identify Coverage Gaps:**
```bash
# Generate coverage report
npm test -- --coverage

# Analyze uncovered lines
npx jest --coverage --coverageReporters=text |
  grep -E "^(File|---|src/)" |
  awk -F'|' '$5 ~ /[0-9]/ && $5 < 80 {print $1, $5}'
```

**Coverage Gap Analysis Script:**
```typescript
// scripts/coverage-analysis.ts
import * as fs from 'fs';

interface CoverageData {
  [file: string]: {
    lines: { [line: string]: number };
    branches: { [branch: string]: number };
    functions: { [func: string]: number };
  };
}

function analyzeGaps(coverageFile: string): void {
  const coverage: CoverageData = JSON.parse(
    fs.readFileSync(coverageFile, 'utf8')
  );

  const gaps: Array<{ file: string; type: string; location: string }> = [];

  for (const [file, data] of Object.entries(coverage)) {
    // Find uncovered lines
    for (const [line, hits] of Object.entries(data.lines)) {
      if (hits === 0) {
        gaps.push({ file, type: 'line', location: `L${line}` });
      }
    }

    // Find uncovered branches
    for (const [branch, hits] of Object.entries(data.branches)) {
      if (hits === 0) {
        gaps.push({ file, type: 'branch', location: `B${branch}` });
      }
    }

    // Find uncovered functions
    for (const [func, hits] of Object.entries(data.functions)) {
      if (hits === 0) {
        gaps.push({ file, type: 'function', location: func });
      }
    }
  }

  // Group by file and prioritize
  const byFile = gaps.reduce((acc, gap) => {
    acc[gap.file] = acc[gap.file] || [];
    acc[gap.file].push(gap);
    return acc;
  }, {} as Record<string, typeof gaps>);

  // Output prioritized list
  console.log('Coverage Gaps (prioritized by impact):');
  for (const [file, fileGaps] of Object.entries(byFile)) {
    console.log(`\n${file} (${fileGaps.length} gaps):`);
    fileGaps.slice(0, 10).forEach(g =>
      console.log(`  - ${g.type}: ${g.location}`)
    );
  }
}

analyzeGaps('coverage/coverage-final.json');
```

**Incremental Coverage Improvement:**
```yaml
# .github/workflows/coverage.yml
name: Coverage Check

on: [pull_request]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get base coverage
        run: |
          git checkout ${{ github.base_ref }}
          npm ci
          npm test -- --coverage --coverageReporters=json-summary
          mv coverage/coverage-summary.json base-coverage.json

      - name: Get PR coverage
        run: |
          git checkout ${{ github.head_ref }}
          npm ci
          npm test -- --coverage --coverageReporters=json-summary
          mv coverage/coverage-summary.json pr-coverage.json

      - name: Compare coverage
        run: |
          node scripts/compare-coverage.js base-coverage.json pr-coverage.json
```

**Compare Coverage Script:**
```javascript
// scripts/compare-coverage.js
const fs = require('fs');

const [,, baseFile, prFile] = process.argv;
const base = JSON.parse(fs.readFileSync(baseFile)).total;
const pr = JSON.parse(fs.readFileSync(prFile)).total;

const metrics = ['lines', 'branches', 'functions', 'statements'];
let hasRegression = false;

console.log('Coverage Comparison:');
console.log('===================');

for (const metric of metrics) {
  const basePct = base[metric].pct;
  const prPct = pr[metric].pct;
  const diff = (prPct - basePct).toFixed(2);
  const symbol = diff >= 0 ? '+' : '';

  console.log(`${metric}: ${basePct}% -> ${prPct}% (${symbol}${diff}%)`);

  if (prPct < basePct - 1) { // Allow 1% tolerance
    hasRegression = true;
  }
}

if (hasRegression) {
  console.error('\nCoverage regression detected!');
  process.exit(1);
}

console.log('\nCoverage check passed!');
```

**Anti-Pattern**: Adding tests just to hit coverage numbers without testing behavior.

### Pattern 5: Strategic Coverage Exclusions

**When to Use**: Excluding code that doesn't need coverage

**Istanbul Ignore Comments:**
```typescript
// Ignore specific line
const debug = process.env.DEBUG; /* istanbul ignore next */

// Ignore block
/* istanbul ignore if */
if (process.env.NODE_ENV === 'development') {
  enableDevTools();
}

// Ignore else branch
if (config.isProduction) {
  initializeProduction();
} /* istanbul ignore else */ else {
  initializeDevelopment();
}

// Ignore entire function
/* istanbul ignore next */
function debugLog(message: string): void {
  if (process.env.DEBUG) {
    console.log(message);
  }
}

// Ignore catch block (for type narrowing)
try {
  return JSON.parse(input);
} catch (e) {
  /* istanbul ignore next */
  throw new ParseError('Invalid JSON');
}
```

**V8/Vitest Coverage Exclusions:**
```typescript
// c8 ignore patterns
/* c8 ignore start */
function devOnlyFunction(): void {
  // Development-only code
}
/* c8 ignore stop */

// Ignore next line
/* c8 ignore next */
const unusedExport = 'for backwards compatibility';

// Ignore next N lines
/* c8 ignore next 3 */
if (extremelyRareCondition) {
  handleRareCase();
}
```

**When to Exclude:**
```typescript
// GOOD: Exclude generated code
/* istanbul ignore file */
// This file is auto-generated by protobuf

// GOOD: Exclude type guards (TypeScript-only, no runtime behavior)
/* istanbul ignore next */
function isError(value: unknown): value is Error {
  return value instanceof Error;
}

// GOOD: Exclude defensive programming
class SafeMap<K, V> {
  get(key: K): V | undefined {
    const value = this.map.get(key);
    /* istanbul ignore if - defensive check */
    if (value === undefined && !this.map.has(key)) {
      return undefined;
    }
    return value;
  }
}

// BAD: Don't exclude business logic
/* istanbul ignore next */ // DON'T DO THIS
function calculatePrice(item: Item): number {
  return item.basePrice * item.quantity * (1 - item.discount);
}
```

**Anti-Pattern**: Excluding code to artificially inflate coverage percentages.

### Pattern 6: Coverage for Different Test Types

**When to Use**: Understanding coverage from unit vs integration tests

**Separate Coverage Reports:**
```json
{
  "scripts": {
    "test:unit": "jest --testPathPattern='.unit.test.ts$' --coverage --coverageDirectory=coverage/unit",
    "test:integration": "jest --testPathPattern='.integration.test.ts$' --coverage --coverageDirectory=coverage/integration",
    "test:e2e": "jest --testPathPattern='.e2e.test.ts$' --coverage --coverageDirectory=coverage/e2e",
    "coverage:merge": "istanbul-merge --out coverage/merged/coverage.json coverage/*/coverage-final.json && istanbul report --dir coverage/merged html"
  }
}
```

**Coverage Merge Script:**
```typescript
// scripts/merge-coverage.ts
import * as fs from 'fs';
import * as path from 'path';

interface CoverageMap {
  [file: string]: {
    path: string;
    statementMap: Record<string, any>;
    s: Record<string, number>;
    branchMap: Record<string, any>;
    b: Record<string, number[]>;
    fnMap: Record<string, any>;
    f: Record<string, number>;
  };
}

function mergeCoverage(coverageFiles: string[]): CoverageMap {
  const merged: CoverageMap = {};

  for (const file of coverageFiles) {
    const coverage: CoverageMap = JSON.parse(fs.readFileSync(file, 'utf8'));

    for (const [filePath, data] of Object.entries(coverage)) {
      if (!merged[filePath]) {
        merged[filePath] = JSON.parse(JSON.stringify(data));
        continue;
      }

      // Merge statement counts
      for (const [key, count] of Object.entries(data.s)) {
        merged[filePath].s[key] = (merged[filePath].s[key] || 0) + count;
      }

      // Merge branch counts
      for (const [key, counts] of Object.entries(data.b)) {
        if (!merged[filePath].b[key]) {
          merged[filePath].b[key] = [...counts];
        } else {
          merged[filePath].b[key] = merged[filePath].b[key].map(
            (c, i) => c + (counts[i] || 0)
          );
        }
      }

      // Merge function counts
      for (const [key, count] of Object.entries(data.f)) {
        merged[filePath].f[key] = (merged[filePath].f[key] || 0) + count;
      }
    }
  }

  return merged;
}

// Find all coverage files
const coverageDir = 'coverage';
const coverageFiles = fs.readdirSync(coverageDir)
  .filter(dir => fs.statSync(path.join(coverageDir, dir)).isDirectory())
  .map(dir => path.join(coverageDir, dir, 'coverage-final.json'))
  .filter(file => fs.existsSync(file));

const merged = mergeCoverage(coverageFiles);
fs.writeFileSync(
  path.join(coverageDir, 'merged-coverage.json'),
  JSON.stringify(merged, null, 2)
);
```

**Anti-Pattern**: Counting the same coverage multiple times from different test types.

## Checklist

- [ ] Coverage thresholds configured in CI
- [ ] Line and branch coverage both measured
- [ ] Critical paths have 90%+ coverage
- [ ] Coverage reports generated on every PR
- [ ] No coverage regressions allowed
- [ ] Mutation testing for critical code
- [ ] Strategic exclusions documented
- [ ] Coverage trends tracked over time
- [ ] Test quality verified, not just quantity
- [ ] Coverage gaps regularly reviewed

## References

- [Istanbul JS Coverage Tool](https://istanbul.js.org/)
- [Jest Coverage Configuration](https://jestjs.io/docs/configuration#collectcoverage-boolean)
- [Stryker Mutation Testing](https://stryker-mutator.io/)
- [Code Coverage Best Practices](https://testing.googleblog.com/2020/08/code-coverage-best-practices.html)
