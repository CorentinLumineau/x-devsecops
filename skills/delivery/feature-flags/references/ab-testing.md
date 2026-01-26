---
title: A/B Testing Reference
category: delivery
type: reference
version: "1.0.0"
---

# A/B Testing

> Part of the delivery/feature-flags knowledge skill

## Overview

A/B testing enables data-driven decisions by comparing variants with statistical rigor. This reference covers experiment design, statistical analysis, and implementation patterns.

## Quick Reference (80/20)

| Metric | Purpose |
|--------|---------|
| Sample Size | Users needed for significance |
| p-value | Probability of false positive |
| Power | Probability of detecting real effect |
| MDE | Minimum Detectable Effect |
| Confidence | Certainty level (typically 95%) |

## Patterns

### Pattern 1: Experiment Configuration

**When to Use**: Setting up A/B tests

**Example**:
```typescript
// experiment.types.ts
interface Experiment {
  id: string;
  name: string;
  description: string;
  hypothesis: string;
  status: 'draft' | 'running' | 'paused' | 'completed';
  startDate?: Date;
  endDate?: Date;
  variants: Variant[];
  metrics: MetricConfig[];
  targeting: TargetingConfig;
  sampleSize: SampleSizeConfig;
}

interface Variant {
  id: string;
  name: string;
  description: string;
  weight: number; // Percentage allocation (0-100)
  isControl: boolean;
  config: Record<string, any>;
}

interface MetricConfig {
  name: string;
  type: 'conversion' | 'revenue' | 'engagement' | 'custom';
  goal: 'increase' | 'decrease';
  primary: boolean;
  minimumDetectableEffect: number; // Percentage
}

interface TargetingConfig {
  percentage: number; // % of traffic in experiment
  rules: TargetingRule[];
  exclusions: string[]; // Other experiment IDs
}

interface SampleSizeConfig {
  minimumPerVariant: number;
  confidenceLevel: number; // e.g., 0.95
  statisticalPower: number; // e.g., 0.80
}

// experiment.service.ts
class ExperimentService {
  constructor(
    private store: ExperimentStore,
    private analytics: AnalyticsService,
    private cache: CacheService
  ) {}

  async assignVariant(
    experimentId: string,
    userId: string,
    context: UserContext
  ): Promise<VariantAssignment | null> {
    const experiment = await this.getExperiment(experimentId);

    if (!experiment || experiment.status !== 'running') {
      return null;
    }

    // Check if already assigned
    const existingAssignment = await this.getAssignment(experimentId, userId);
    if (existingAssignment) {
      return existingAssignment;
    }

    // Check targeting rules
    if (!this.matchesTargeting(experiment.targeting, context)) {
      return null;
    }

    // Check traffic allocation
    if (!this.isInTrafficAllocation(experimentId, userId, experiment.targeting.percentage)) {
      return null;
    }

    // Check mutual exclusion
    for (const excludedId of experiment.targeting.exclusions) {
      const excluded = await this.getAssignment(excludedId, userId);
      if (excluded) {
        return null;
      }
    }

    // Assign variant based on weights
    const variant = this.selectVariant(experiment.variants, userId, experimentId);

    const assignment: VariantAssignment = {
      experimentId,
      variantId: variant.id,
      userId,
      assignedAt: new Date(),
      context
    };

    await this.store.saveAssignment(assignment);

    this.analytics.track('experiment_assigned', {
      experimentId,
      variantId: variant.id,
      userId
    });

    return assignment;
  }

  private selectVariant(
    variants: Variant[],
    userId: string,
    experimentId: string
  ): Variant {
    // Deterministic assignment using hash
    const hash = this.hashUserExperiment(userId, experimentId);
    const bucket = hash % 100;

    let cumulative = 0;
    for (const variant of variants) {
      cumulative += variant.weight;
      if (bucket < cumulative) {
        return variant;
      }
    }

    // Fallback to control
    return variants.find(v => v.isControl) || variants[0];
  }

  private hashUserExperiment(userId: string, experimentId: string): number {
    const key = `${userId}:${experimentId}`;
    let hash = 0;
    for (let i = 0; i < key.length; i++) {
      const char = key.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash);
  }

  private isInTrafficAllocation(
    experimentId: string,
    userId: string,
    percentage: number
  ): boolean {
    const hash = this.hashUserExperiment(userId, `${experimentId}:traffic`);
    return (hash % 100) < percentage;
  }

  private matchesTargeting(targeting: TargetingConfig, context: UserContext): boolean {
    for (const rule of targeting.rules) {
      const value = context[rule.attribute];
      if (!this.evaluateRule(value, rule)) {
        return false;
      }
    }
    return true;
  }
}

// Usage
const experiment = await experimentService.assignVariant(
  'checkout-redesign',
  user.id,
  { country: user.country, plan: user.plan }
);

if (experiment?.variantId === 'new-checkout') {
  return <NewCheckout />;
}
return <CurrentCheckout />;
```

**Anti-Pattern**: Non-deterministic variant assignment.

### Pattern 2: Statistical Analysis

**When to Use**: Analyzing experiment results

**Example**:
```typescript
// statistics.ts
interface ExperimentResults {
  experiment: Experiment;
  variants: VariantResults[];
  analysis: StatisticalAnalysis;
  recommendation: string;
}

interface VariantResults {
  variantId: string;
  sampleSize: number;
  conversions: number;
  conversionRate: number;
  revenue: number;
  revenuePerUser: number;
}

interface StatisticalAnalysis {
  isSignificant: boolean;
  pValue: number;
  confidenceInterval: [number, number];
  relativeUplift: number;
  absoluteUplift: number;
  statisticalPower: number;
}

class StatisticsService {
  // Two-proportion z-test for conversion rates
  calculateConversionSignificance(
    control: VariantResults,
    treatment: VariantResults,
    confidenceLevel: number = 0.95
  ): StatisticalAnalysis {
    const p1 = control.conversionRate;
    const p2 = treatment.conversionRate;
    const n1 = control.sampleSize;
    const n2 = treatment.sampleSize;

    // Pooled proportion
    const p = (control.conversions + treatment.conversions) / (n1 + n2);

    // Standard error
    const se = Math.sqrt(p * (1 - p) * (1/n1 + 1/n2));

    // Z-score
    const z = (p2 - p1) / se;

    // P-value (two-tailed)
    const pValue = 2 * (1 - this.normalCDF(Math.abs(z)));

    // Confidence interval
    const alpha = 1 - confidenceLevel;
    const zCritical = this.normalInverse(1 - alpha/2);
    const diff = p2 - p1;
    const seDiff = Math.sqrt((p1*(1-p1))/n1 + (p2*(1-p2))/n2);
    const ci: [number, number] = [
      diff - zCritical * seDiff,
      diff + zCritical * seDiff
    ];

    return {
      isSignificant: pValue < alpha,
      pValue,
      confidenceInterval: ci,
      relativeUplift: ((p2 - p1) / p1) * 100,
      absoluteUplift: (p2 - p1) * 100,
      statisticalPower: this.calculatePower(p1, p2, n1, n2, alpha)
    };
  }

  // Welch's t-test for continuous metrics (revenue)
  calculateRevenueSignificance(
    control: { mean: number; variance: number; n: number },
    treatment: { mean: number; variance: number; n: number },
    confidenceLevel: number = 0.95
  ): StatisticalAnalysis {
    const { mean: m1, variance: v1, n: n1 } = control;
    const { mean: m2, variance: v2, n: n2 } = treatment;

    // Welch's t-statistic
    const se = Math.sqrt(v1/n1 + v2/n2);
    const t = (m2 - m1) / se;

    // Welch-Satterthwaite degrees of freedom
    const df = Math.pow(v1/n1 + v2/n2, 2) /
      (Math.pow(v1/n1, 2)/(n1-1) + Math.pow(v2/n2, 2)/(n2-1));

    // P-value using t-distribution
    const pValue = 2 * (1 - this.tCDF(Math.abs(t), df));

    const alpha = 1 - confidenceLevel;
    const tCritical = this.tInverse(1 - alpha/2, df);
    const diff = m2 - m1;
    const ci: [number, number] = [
      diff - tCritical * se,
      diff + tCritical * se
    ];

    return {
      isSignificant: pValue < alpha,
      pValue,
      confidenceInterval: ci,
      relativeUplift: ((m2 - m1) / m1) * 100,
      absoluteUplift: m2 - m1,
      statisticalPower: this.calculatePower(m1, m2, n1, n2, alpha)
    };
  }

  // Sample size calculation
  calculateRequiredSampleSize(
    baselineRate: number,
    minimumDetectableEffect: number, // Relative change (e.g., 0.05 for 5%)
    power: number = 0.80,
    confidenceLevel: number = 0.95
  ): number {
    const alpha = 1 - confidenceLevel;
    const p1 = baselineRate;
    const p2 = p1 * (1 + minimumDetectableEffect);

    const zAlpha = this.normalInverse(1 - alpha/2);
    const zBeta = this.normalInverse(power);

    const pooledP = (p1 + p2) / 2;
    const pooledVariance = 2 * pooledP * (1 - pooledP);
    const individualVariance = p1 * (1 - p1) + p2 * (1 - p2);

    const n = Math.pow(zAlpha * Math.sqrt(pooledVariance) +
                       zBeta * Math.sqrt(individualVariance), 2) /
              Math.pow(p2 - p1, 2);

    return Math.ceil(n);
  }

  // Sequential analysis for early stopping
  calculateSequentialBoundary(
    currentSampleSize: number,
    maxSampleSize: number,
    alpha: number = 0.05
  ): { upperBound: number; lowerBound: number } {
    // O'Brien-Fleming spending function
    const t = currentSampleSize / maxSampleSize;
    const adjustedAlpha = alpha * Math.pow(t, 2);

    const zCritical = this.normalInverse(1 - adjustedAlpha/2);

    return {
      upperBound: zCritical,
      lowerBound: -zCritical
    };
  }

  private normalCDF(z: number): number {
    const a1 =  0.254829592;
    const a2 = -0.284496736;
    const a3 =  1.421413741;
    const a4 = -1.453152027;
    const a5 =  1.061405429;
    const p  =  0.3275911;

    const sign = z < 0 ? -1 : 1;
    z = Math.abs(z) / Math.sqrt(2);

    const t = 1.0 / (1.0 + p * z);
    const y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t*Math.exp(-z*z);

    return 0.5 * (1.0 + sign * y);
  }

  private normalInverse(p: number): number {
    // Approximation of inverse normal CDF
    const a = [
      -3.969683028665376e+01,
       2.209460984245205e+02,
      -2.759285104469687e+02,
       1.383577518672690e+02,
      -3.066479806614716e+01,
       2.506628277459239e+00
    ];
    const b = [
      -5.447609879822406e+01,
       1.615858368580409e+02,
      -1.556989798598866e+02,
       6.680131188771972e+01,
      -1.328068155288572e+01
    ];

    const q = p - 0.5;
    let r, x;

    if (Math.abs(q) <= 0.425) {
      r = 0.180625 - q * q;
      x = q * (((((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+1) /
               (((((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)));
    } else {
      r = q < 0 ? p : 1 - p;
      r = Math.sqrt(-Math.log(r));
      x = (((((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+1) /
           (((((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)));
      if (q < 0) x = -x;
    }

    return x;
  }

  private tCDF(t: number, df: number): number {
    // Approximation for t-distribution CDF
    const x = df / (df + t * t);
    return 1 - 0.5 * this.incompleteBeta(df/2, 0.5, x);
  }

  private tInverse(p: number, df: number): number {
    // Newton-Raphson method for t inverse
    let t = this.normalInverse(p);
    for (let i = 0; i < 10; i++) {
      const cdf = this.tCDF(t, df);
      const pdf = this.tPDF(t, df);
      t = t - (cdf - p) / pdf;
    }
    return t;
  }

  private tPDF(t: number, df: number): number {
    return Math.pow(1 + t*t/df, -(df+1)/2) /
           (Math.sqrt(df) * this.beta(df/2, 0.5));
  }

  private incompleteBeta(a: number, b: number, x: number): number {
    // Simplified approximation
    return Math.pow(x, a) * Math.pow(1-x, b) / (a * this.beta(a, b));
  }

  private beta(a: number, b: number): number {
    return (this.gamma(a) * this.gamma(b)) / this.gamma(a + b);
  }

  private gamma(n: number): number {
    // Stirling's approximation
    if (n < 0.5) {
      return Math.PI / (Math.sin(Math.PI * n) * this.gamma(1 - n));
    }
    n -= 1;
    const g = 7;
    const c = [
      0.99999999999980993,
      676.5203681218851,
      -1259.1392167224028,
      771.32342877765313,
      -176.61502916214059,
      12.507343278686905,
      -0.13857109526572012,
      9.9843695780195716e-6,
      1.5056327351493116e-7
    ];
    let x = c[0];
    for (let i = 1; i < g + 2; i++) {
      x += c[i] / (n + i);
    }
    const t = n + g + 0.5;
    return Math.sqrt(2 * Math.PI) * Math.pow(t, n + 0.5) * Math.exp(-t) * x;
  }

  private calculatePower(
    p1: number,
    p2: number,
    n1: number,
    n2: number,
    alpha: number
  ): number {
    const zAlpha = this.normalInverse(1 - alpha/2);
    const se = Math.sqrt(p1*(1-p1)/n1 + p2*(1-p2)/n2);
    const effect = Math.abs(p2 - p1);
    const zEffect = (effect - zAlpha * se) / se;
    return this.normalCDF(zEffect);
  }
}
```

**Anti-Pattern**: Stopping experiments early without proper statistical methods.

### Pattern 3: Event Tracking

**When to Use**: Collecting experiment metrics

**Example**:
```typescript
// experiment-tracking.ts
interface ExperimentEvent {
  experimentId: string;
  variantId: string;
  userId: string;
  eventType: 'exposure' | 'conversion' | 'revenue' | 'custom';
  eventName: string;
  value?: number;
  properties?: Record<string, any>;
  timestamp: Date;
  sessionId: string;
}

class ExperimentTracker {
  private queue: ExperimentEvent[] = [];
  private flushInterval: NodeJS.Timeout;

  constructor(
    private analyticsEndpoint: string,
    private batchSize: number = 100,
    private flushIntervalMs: number = 5000
  ) {
    this.flushInterval = setInterval(() => this.flush(), flushIntervalMs);
  }

  // Track when user sees experiment variant
  trackExposure(
    experimentId: string,
    variantId: string,
    userId: string,
    sessionId: string
  ): void {
    // Deduplicate exposures per session
    const exposureKey = `${experimentId}:${variantId}:${sessionId}`;
    if (this.hasTracked(exposureKey)) {
      return;
    }
    this.markTracked(exposureKey);

    this.track({
      experimentId,
      variantId,
      userId,
      eventType: 'exposure',
      eventName: 'experiment_exposure',
      timestamp: new Date(),
      sessionId
    });
  }

  // Track conversion event
  trackConversion(
    experimentId: string,
    variantId: string,
    userId: string,
    conversionName: string,
    sessionId: string,
    properties?: Record<string, any>
  ): void {
    this.track({
      experimentId,
      variantId,
      userId,
      eventType: 'conversion',
      eventName: conversionName,
      properties,
      timestamp: new Date(),
      sessionId
    });
  }

  // Track revenue event
  trackRevenue(
    experimentId: string,
    variantId: string,
    userId: string,
    amount: number,
    sessionId: string,
    properties?: Record<string, any>
  ): void {
    this.track({
      experimentId,
      variantId,
      userId,
      eventType: 'revenue',
      eventName: 'purchase',
      value: amount,
      properties,
      timestamp: new Date(),
      sessionId
    });
  }

  // Track custom metric
  trackMetric(
    experimentId: string,
    variantId: string,
    userId: string,
    metricName: string,
    value: number,
    sessionId: string
  ): void {
    this.track({
      experimentId,
      variantId,
      userId,
      eventType: 'custom',
      eventName: metricName,
      value,
      timestamp: new Date(),
      sessionId
    });
  }

  private track(event: ExperimentEvent): void {
    this.queue.push(event);

    if (this.queue.length >= this.batchSize) {
      this.flush();
    }
  }

  private async flush(): Promise<void> {
    if (this.queue.length === 0) return;

    const events = [...this.queue];
    this.queue = [];

    try {
      await fetch(this.analyticsEndpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ events })
      });
    } catch (error) {
      // Re-queue failed events
      this.queue = [...events, ...this.queue];
      console.error('Failed to flush experiment events:', error);
    }
  }

  private trackedExposures = new Set<string>();

  private hasTracked(key: string): boolean {
    return this.trackedExposures.has(key);
  }

  private markTracked(key: string): void {
    this.trackedExposures.add(key);
  }

  destroy(): void {
    clearInterval(this.flushInterval);
    this.flush();
  }
}

// React hook for experiment tracking
function useExperiment(experimentId: string) {
  const { userId, sessionId } = useUser();
  const tracker = useExperimentTracker();
  const [assignment, setAssignment] = useState<VariantAssignment | null>(null);

  useEffect(() => {
    const fetchAssignment = async () => {
      const result = await experimentService.assignVariant(
        experimentId,
        userId,
        getContext()
      );
      setAssignment(result);

      if (result) {
        tracker.trackExposure(
          experimentId,
          result.variantId,
          userId,
          sessionId
        );
      }
    };

    fetchAssignment();
  }, [experimentId, userId]);

  const trackConversion = useCallback((conversionName: string, properties?: Record<string, any>) => {
    if (assignment) {
      tracker.trackConversion(
        experimentId,
        assignment.variantId,
        userId,
        conversionName,
        sessionId,
        properties
      );
    }
  }, [assignment, experimentId, userId, sessionId]);

  const trackRevenue = useCallback((amount: number, properties?: Record<string, any>) => {
    if (assignment) {
      tracker.trackRevenue(
        experimentId,
        assignment.variantId,
        userId,
        amount,
        sessionId,
        properties
      );
    }
  }, [assignment, experimentId, userId, sessionId]);

  return {
    variant: assignment?.variantId ?? null,
    isLoading: assignment === null,
    trackConversion,
    trackRevenue
  };
}

// Usage
function CheckoutPage() {
  const { variant, trackConversion, trackRevenue } = useExperiment('checkout-redesign');

  const handlePurchase = async (order: Order) => {
    await processOrder(order);
    trackConversion('purchase_completed', { orderId: order.id });
    trackRevenue(order.total, { currency: order.currency });
  };

  if (variant === 'new-checkout') {
    return <NewCheckout onPurchase={handlePurchase} />;
  }

  return <CurrentCheckout onPurchase={handlePurchase} />;
}
```

**Anti-Pattern**: Tracking without proper attribution to variants.

### Pattern 4: Multi-Armed Bandit

**When to Use**: Automatic traffic optimization

**Example**:
```typescript
// bandit.ts
interface BanditArm {
  id: string;
  successes: number;
  failures: number;
}

class ThompsonSamplingBandit {
  private arms: Map<string, BanditArm> = new Map();

  constructor(armIds: string[]) {
    armIds.forEach(id => {
      this.arms.set(id, { id, successes: 1, failures: 1 }); // Beta(1,1) prior
    });
  }

  selectArm(): string {
    let bestArm: string | null = null;
    let bestSample = -Infinity;

    for (const [id, arm] of this.arms) {
      // Sample from Beta distribution
      const sample = this.sampleBeta(arm.successes, arm.failures);

      if (sample > bestSample) {
        bestSample = sample;
        bestArm = id;
      }
    }

    return bestArm!;
  }

  updateArm(armId: string, success: boolean): void {
    const arm = this.arms.get(armId);
    if (!arm) return;

    if (success) {
      arm.successes++;
    } else {
      arm.failures++;
    }
  }

  getArmStats(): Record<string, { probability: number; samples: number }> {
    const result: Record<string, { probability: number; samples: number }> = {};

    for (const [id, arm] of this.arms) {
      const total = arm.successes + arm.failures - 2; // Subtract priors
      result[id] = {
        probability: arm.successes / (arm.successes + arm.failures),
        samples: total
      };
    }

    return result;
  }

  // Sample from Beta distribution using Gamma sampling
  private sampleBeta(alpha: number, beta: number): number {
    const gammaAlpha = this.sampleGamma(alpha);
    const gammaBeta = this.sampleGamma(beta);
    return gammaAlpha / (gammaAlpha + gammaBeta);
  }

  // Sample from Gamma distribution using Marsaglia and Tsang's method
  private sampleGamma(shape: number): number {
    if (shape < 1) {
      return this.sampleGamma(shape + 1) * Math.pow(Math.random(), 1 / shape);
    }

    const d = shape - 1/3;
    const c = 1 / Math.sqrt(9 * d);

    while (true) {
      let x: number, v: number;

      do {
        x = this.sampleNormal();
        v = 1 + c * x;
      } while (v <= 0);

      v = v * v * v;
      const u = Math.random();

      if (u < 1 - 0.0331 * (x * x) * (x * x)) {
        return d * v;
      }

      if (Math.log(u) < 0.5 * x * x + d * (1 - v + Math.log(v))) {
        return d * v;
      }
    }
  }

  // Box-Muller transform for normal sampling
  private sampleNormal(): number {
    const u1 = Math.random();
    const u2 = Math.random();
    return Math.sqrt(-2 * Math.log(u1)) * Math.cos(2 * Math.PI * u2);
  }
}

// Contextual bandit for personalization
class ContextualBandit {
  private models: Map<string, LinearModel> = new Map();

  constructor(
    armIds: string[],
    private featureCount: number
  ) {
    armIds.forEach(id => {
      this.models.set(id, new LinearModel(featureCount));
    });
  }

  selectArm(context: number[]): string {
    let bestArm: string | null = null;
    let bestReward = -Infinity;

    for (const [id, model] of this.models) {
      const reward = model.predictWithUCB(context);

      if (reward > bestReward) {
        bestReward = reward;
        bestArm = id;
      }
    }

    return bestArm!;
  }

  updateArm(armId: string, context: number[], reward: number): void {
    const model = this.models.get(armId);
    if (model) {
      model.update(context, reward);
    }
  }
}

class LinearModel {
  private weights: number[];
  private precision: number[][];
  private alpha: number = 1;

  constructor(featureCount: number) {
    this.weights = new Array(featureCount).fill(0);
    this.precision = this.identity(featureCount);
  }

  predictWithUCB(context: number[]): number {
    const mean = this.dotProduct(this.weights, context);
    const variance = this.computeVariance(context);
    const ucb = mean + this.alpha * Math.sqrt(variance);
    return ucb;
  }

  update(context: number[], reward: number): void {
    // Update precision matrix
    for (let i = 0; i < context.length; i++) {
      for (let j = 0; j < context.length; j++) {
        this.precision[i][j] += context[i] * context[j];
      }
    }

    // Update weights using ridge regression
    const inverse = this.inverse(this.precision);
    for (let i = 0; i < this.weights.length; i++) {
      let sum = 0;
      for (let j = 0; j < context.length; j++) {
        sum += inverse[i][j] * context[j] * reward;
      }
      this.weights[i] += sum;
    }
  }

  private computeVariance(context: number[]): number {
    const inverse = this.inverse(this.precision);
    let variance = 0;
    for (let i = 0; i < context.length; i++) {
      for (let j = 0; j < context.length; j++) {
        variance += context[i] * inverse[i][j] * context[j];
      }
    }
    return variance;
  }

  private dotProduct(a: number[], b: number[]): number {
    return a.reduce((sum, val, i) => sum + val * b[i], 0);
  }

  private identity(n: number): number[][] {
    return Array(n).fill(null).map((_, i) =>
      Array(n).fill(0).map((_, j) => i === j ? 1 : 0)
    );
  }

  private inverse(matrix: number[][]): number[][] {
    // Simplified inverse for small matrices
    // Use proper linear algebra library in production
    const n = matrix.length;
    const result = this.identity(n);
    const m = matrix.map(row => [...row]);

    for (let i = 0; i < n; i++) {
      const pivot = m[i][i];
      for (let j = 0; j < n; j++) {
        m[i][j] /= pivot;
        result[i][j] /= pivot;
      }
      for (let k = 0; k < n; k++) {
        if (k !== i) {
          const factor = m[k][i];
          for (let j = 0; j < n; j++) {
            m[k][j] -= factor * m[i][j];
            result[k][j] -= factor * result[i][j];
          }
        }
      }
    }

    return result;
  }
}

// Usage
const bandit = new ThompsonSamplingBandit(['variant-a', 'variant-b', 'variant-c']);

// On each request
const selectedVariant = bandit.selectArm();

// After observing outcome
bandit.updateArm(selectedVariant, userConverted);

// Get current statistics
const stats = bandit.getArmStats();
console.log(`Variant A win rate: ${(stats['variant-a'].probability * 100).toFixed(1)}%`);
```

**Anti-Pattern**: Using bandits when proper A/B testing is required.

### Pattern 5: Guardrail Metrics

**When to Use**: Protecting against negative effects

**Example**:
```typescript
// guardrails.ts
interface GuardrailConfig {
  metric: string;
  threshold: number;
  direction: 'increase' | 'decrease';
  severity: 'warning' | 'critical';
  action: 'alert' | 'pause' | 'stop';
}

interface GuardrailResult {
  metric: string;
  baseline: number;
  current: number;
  change: number;
  changePercent: number;
  violated: boolean;
  severity: 'warning' | 'critical';
}

class GuardrailService {
  constructor(
    private metricsService: MetricsService,
    private alertService: AlertService,
    private experimentService: ExperimentService
  ) {}

  async checkGuardrails(
    experimentId: string,
    guardrails: GuardrailConfig[]
  ): Promise<GuardrailResult[]> {
    const results: GuardrailResult[] = [];

    for (const guardrail of guardrails) {
      const result = await this.checkGuardrail(experimentId, guardrail);
      results.push(result);

      if (result.violated) {
        await this.handleViolation(experimentId, guardrail, result);
      }
    }

    return results;
  }

  private async checkGuardrail(
    experimentId: string,
    guardrail: GuardrailConfig
  ): Promise<GuardrailResult> {
    const [baseline, current] = await Promise.all([
      this.metricsService.getMetricForControl(experimentId, guardrail.metric),
      this.metricsService.getMetricForTreatment(experimentId, guardrail.metric)
    ]);

    const change = current - baseline;
    const changePercent = (change / baseline) * 100;

    let violated = false;
    if (guardrail.direction === 'increase') {
      violated = changePercent > guardrail.threshold;
    } else {
      violated = changePercent < -guardrail.threshold;
    }

    return {
      metric: guardrail.metric,
      baseline,
      current,
      change,
      changePercent,
      violated,
      severity: guardrail.severity
    };
  }

  private async handleViolation(
    experimentId: string,
    guardrail: GuardrailConfig,
    result: GuardrailResult
  ): Promise<void> {
    const alert = {
      experimentId,
      metric: guardrail.metric,
      message: `Guardrail violated: ${result.metric} changed by ${result.changePercent.toFixed(2)}%`,
      severity: guardrail.severity,
      timestamp: new Date()
    };

    await this.alertService.send(alert);

    switch (guardrail.action) {
      case 'pause':
        await this.experimentService.pauseExperiment(experimentId);
        break;
      case 'stop':
        await this.experimentService.stopExperiment(experimentId);
        break;
      case 'alert':
        // Alert already sent
        break;
    }
  }
}

// Define guardrails
const guardrails: GuardrailConfig[] = [
  {
    metric: 'error_rate',
    threshold: 10, // 10% increase
    direction: 'increase',
    severity: 'critical',
    action: 'pause'
  },
  {
    metric: 'page_load_time',
    threshold: 20, // 20% increase
    direction: 'increase',
    severity: 'warning',
    action: 'alert'
  },
  {
    metric: 'revenue_per_user',
    threshold: 5, // 5% decrease
    direction: 'decrease',
    severity: 'critical',
    action: 'stop'
  },
  {
    metric: 'crash_rate',
    threshold: 0, // Any increase
    direction: 'increase',
    severity: 'critical',
    action: 'stop'
  }
];

// Scheduled check
const scheduler = new Scheduler();

scheduler.every('15 minutes', async () => {
  const runningExperiments = await experimentService.getRunningExperiments();

  for (const experiment of runningExperiments) {
    const results = await guardrailService.checkGuardrails(
      experiment.id,
      experiment.guardrails ?? guardrails
    );

    const violations = results.filter(r => r.violated);
    if (violations.length > 0) {
      console.log(`Guardrail violations for ${experiment.name}:`, violations);
    }
  }
});
```

**Anti-Pattern**: Running experiments without safety guardrails.

## Checklist

- [ ] Hypothesis documented before experiment
- [ ] Sample size calculated for desired power
- [ ] Primary metric defined clearly
- [ ] Guardrail metrics configured
- [ ] Statistical test selected appropriately
- [ ] Exposure tracking implemented
- [ ] Conversion attribution correct
- [ ] Sequential testing boundaries set
- [ ] Documentation for experiment results
- [ ] Winner implementation planned

## References

- [A/B Testing Statistics](https://www.evanmiller.org/ab-testing/)
- [Sample Size Calculator](https://www.optimizely.com/sample-size-calculator/)
- [Multi-Armed Bandits](https://www.microsoft.com/en-us/research/publication/a-contextual-bandit-approach-to-personalized-news-article-recommendation/)
- [Trustworthy Online Experiments](https://www.amazon.com/Trustworthy-Online-Controlled-Experiments-Practical/dp/1108724264)
