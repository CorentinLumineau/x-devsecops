---
title: Feature Flag Implementation Reference
category: delivery
type: reference
version: "1.0.0"
---

# Feature Flag Implementation

> Part of the delivery/feature-flags knowledge skill

## Overview

Feature flags enable controlled rollout of features without code deployments. This reference covers implementation patterns, flag types, and evaluation strategies.

## Quick Reference (80/20)

| Flag Type | Purpose |
|-----------|---------|
| Release | Gradual feature rollout |
| Experiment | A/B testing |
| Ops | Operational controls |
| Permission | Feature access control |
| Kill Switch | Emergency disable |

## Patterns

### Pattern 1: Feature Flag Service

**When to Use**: Centralized flag management

**Example**:
```typescript
// feature-flag.service.ts
interface FeatureFlag {
  key: string;
  enabled: boolean;
  variants?: Record<string, any>;
  targetingRules?: TargetingRule[];
  percentage?: number;
  defaultValue: any;
}

interface TargetingRule {
  attribute: string;
  operator: 'eq' | 'neq' | 'contains' | 'in' | 'gt' | 'lt';
  value: any;
  variant: string;
}

interface EvaluationContext {
  userId?: string;
  email?: string;
  country?: string;
  plan?: string;
  attributes?: Record<string, any>;
}

class FeatureFlagService {
  private flags: Map<string, FeatureFlag> = new Map();
  private cache: Map<string, { value: any; expiry: number }> = new Map();
  private readonly CACHE_TTL = 60000; // 1 minute

  constructor(
    private provider: FeatureFlagProvider,
    private analytics: AnalyticsService
  ) {
    this.startPolling();
  }

  async evaluate<T>(
    flagKey: string,
    context: EvaluationContext,
    defaultValue: T
  ): Promise<T> {
    try {
      const flag = await this.getFlag(flagKey);

      if (!flag) {
        this.analytics.trackFlagEvaluation(flagKey, 'not_found', defaultValue);
        return defaultValue;
      }

      if (!flag.enabled) {
        this.analytics.trackFlagEvaluation(flagKey, 'disabled', defaultValue);
        return defaultValue;
      }

      // Check targeting rules
      const variant = this.evaluateTargeting(flag, context);
      if (variant !== null) {
        this.analytics.trackFlagEvaluation(flagKey, 'targeted', variant);
        return variant as T;
      }

      // Check percentage rollout
      if (flag.percentage !== undefined && context.userId) {
        const bucket = this.hashToBucket(flagKey, context.userId);
        if (bucket > flag.percentage) {
          this.analytics.trackFlagEvaluation(flagKey, 'rollout_excluded', defaultValue);
          return defaultValue;
        }
      }

      const result = flag.variants?.default ?? flag.defaultValue ?? defaultValue;
      this.analytics.trackFlagEvaluation(flagKey, 'enabled', result);
      return result as T;

    } catch (error) {
      console.error(`Flag evaluation error for ${flagKey}:`, error);
      return defaultValue;
    }
  }

  private evaluateTargeting(
    flag: FeatureFlag,
    context: EvaluationContext
  ): any | null {
    if (!flag.targetingRules) return null;

    for (const rule of flag.targetingRules) {
      const contextValue = this.getContextValue(context, rule.attribute);

      if (this.evaluateRule(contextValue, rule)) {
        return flag.variants?.[rule.variant] ?? true;
      }
    }

    return null;
  }

  private evaluateRule(contextValue: any, rule: TargetingRule): boolean {
    switch (rule.operator) {
      case 'eq': return contextValue === rule.value;
      case 'neq': return contextValue !== rule.value;
      case 'contains': return String(contextValue).includes(rule.value);
      case 'in': return Array.isArray(rule.value) && rule.value.includes(contextValue);
      case 'gt': return contextValue > rule.value;
      case 'lt': return contextValue < rule.value;
      default: return false;
    }
  }

  private hashToBucket(flagKey: string, userId: string): number {
    // Deterministic hash for consistent bucketing
    const hash = this.murmurHash3(`${flagKey}-${userId}`);
    return hash % 100;
  }

  private murmurHash3(key: string): number {
    let h = 0;
    for (let i = 0; i < key.length; i++) {
      h = Math.imul(h ^ key.charCodeAt(i), 2654435761);
    }
    return (h ^ (h >>> 16)) >>> 0;
  }

  private getContextValue(context: EvaluationContext, attribute: string): any {
    if (attribute in context) {
      return (context as any)[attribute];
    }
    return context.attributes?.[attribute];
  }

  private async getFlag(key: string): Promise<FeatureFlag | undefined> {
    const cached = this.cache.get(key);
    if (cached && cached.expiry > Date.now()) {
      return this.flags.get(key);
    }

    await this.refreshFlags();
    return this.flags.get(key);
  }

  private async refreshFlags(): Promise<void> {
    const flags = await this.provider.fetchFlags();
    flags.forEach(flag => {
      this.flags.set(flag.key, flag);
      this.cache.set(flag.key, {
        value: flag,
        expiry: Date.now() + this.CACHE_TTL
      });
    });
  }

  private startPolling(): void {
    setInterval(() => this.refreshFlags(), this.CACHE_TTL);
  }
}

// Usage
const flagService = new FeatureFlagService(provider, analytics);

const isNewDashboardEnabled = await flagService.evaluate(
  'new-dashboard',
  { userId: user.id, plan: user.plan },
  false
);

if (isNewDashboardEnabled) {
  return <NewDashboard />;
}
return <LegacyDashboard />;
```

**Anti-Pattern**: Global boolean flags without targeting.

### Pattern 2: React Feature Flag Hook

**When to Use**: React applications with feature flags

**Example**:
```typescript
// use-feature-flag.ts
import { createContext, useContext, useState, useEffect, ReactNode } from 'react';

interface FeatureFlagContextType {
  isEnabled: (key: string) => boolean;
  getVariant: <T>(key: string, defaultValue: T) => T;
  isLoading: boolean;
}

const FeatureFlagContext = createContext<FeatureFlagContextType | null>(null);

interface FeatureFlagProviderProps {
  children: ReactNode;
  userId?: string;
  attributes?: Record<string, any>;
}

export function FeatureFlagProvider({
  children,
  userId,
  attributes
}: FeatureFlagProviderProps) {
  const [flags, setFlags] = useState<Record<string, any>>({});
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchFlags = async () => {
      try {
        const response = await fetch('/api/flags', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ userId, attributes })
        });
        const data = await response.json();
        setFlags(data.flags);
      } catch (error) {
        console.error('Failed to fetch feature flags:', error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchFlags();

    // Set up SSE for real-time updates
    const eventSource = new EventSource(`/api/flags/stream?userId=${userId}`);
    eventSource.onmessage = (event) => {
      const update = JSON.parse(event.data);
      setFlags(prev => ({ ...prev, [update.key]: update.value }));
    };

    return () => eventSource.close();
  }, [userId, attributes]);

  const isEnabled = (key: string): boolean => {
    return Boolean(flags[key]);
  };

  const getVariant = <T,>(key: string, defaultValue: T): T => {
    return flags[key] ?? defaultValue;
  };

  return (
    <FeatureFlagContext.Provider value={{ isEnabled, getVariant, isLoading }}>
      {children}
    </FeatureFlagContext.Provider>
  );
}

export function useFeatureFlag(key: string): boolean {
  const context = useContext(FeatureFlagContext);
  if (!context) {
    throw new Error('useFeatureFlag must be used within FeatureFlagProvider');
  }
  return context.isEnabled(key);
}

export function useFeatureVariant<T>(key: string, defaultValue: T): T {
  const context = useContext(FeatureFlagContext);
  if (!context) {
    throw new Error('useFeatureVariant must be used within FeatureFlagProvider');
  }
  return context.getVariant(key, defaultValue);
}

// Feature component wrapper
interface FeatureProps {
  flag: string;
  children: ReactNode;
  fallback?: ReactNode;
}

export function Feature({ flag, children, fallback = null }: FeatureProps) {
  const isEnabled = useFeatureFlag(flag);
  return <>{isEnabled ? children : fallback}</>;
}

// Usage
function App() {
  return (
    <FeatureFlagProvider userId={user.id} attributes={{ plan: user.plan }}>
      <Feature flag="new-checkout" fallback={<OldCheckout />}>
        <NewCheckout />
      </Feature>

      <ConditionalFeature />
    </FeatureFlagProvider>
  );
}

function ConditionalFeature() {
  const showBanner = useFeatureFlag('promo-banner');
  const bannerConfig = useFeatureVariant('promo-banner-config', {
    text: 'Default',
    color: 'blue'
  });

  if (!showBanner) return null;

  return (
    <Banner color={bannerConfig.color}>
      {bannerConfig.text}
    </Banner>
  );
}
```

**Anti-Pattern**: Fetching flags on every render.

### Pattern 3: Server-Side Flag Evaluation

**When to Use**: Backend services with feature flags

**Example**:
```go
// feature_flags.go
package flags

import (
    "context"
    "crypto/sha256"
    "encoding/binary"
    "sync"
    "time"
)

type Flag struct {
    Key            string            `json:"key"`
    Enabled        bool              `json:"enabled"`
    Percentage     *int              `json:"percentage,omitempty"`
    TargetingRules []TargetingRule   `json:"targetingRules,omitempty"`
    Variants       map[string]any    `json:"variants,omitempty"`
    DefaultValue   any               `json:"defaultValue"`
}

type TargetingRule struct {
    Attribute string `json:"attribute"`
    Operator  string `json:"operator"`
    Value     any    `json:"value"`
    Variant   string `json:"variant"`
}

type EvaluationContext struct {
    UserID     string
    Email      string
    Country    string
    Plan       string
    Attributes map[string]any
}

type FlagClient struct {
    flags    map[string]*Flag
    mu       sync.RWMutex
    provider FlagProvider
    metrics  MetricsClient
}

func NewFlagClient(provider FlagProvider, metrics MetricsClient) *FlagClient {
    client := &FlagClient{
        flags:    make(map[string]*Flag),
        provider: provider,
        metrics:  metrics,
    }

    go client.pollFlags(context.Background())

    return client
}

func (c *FlagClient) Evaluate(ctx context.Context, key string, evalCtx EvaluationContext, defaultValue any) any {
    c.mu.RLock()
    flag, exists := c.flags[key]
    c.mu.RUnlock()

    if !exists {
        c.metrics.IncrementCounter("flag_evaluation", "key", key, "result", "not_found")
        return defaultValue
    }

    if !flag.Enabled {
        c.metrics.IncrementCounter("flag_evaluation", "key", key, "result", "disabled")
        return defaultValue
    }

    // Evaluate targeting rules
    if variant := c.evaluateTargeting(flag, evalCtx); variant != nil {
        c.metrics.IncrementCounter("flag_evaluation", "key", key, "result", "targeted")
        return variant
    }

    // Evaluate percentage rollout
    if flag.Percentage != nil && evalCtx.UserID != "" {
        bucket := c.hashToBucket(key, evalCtx.UserID)
        if bucket > *flag.Percentage {
            c.metrics.IncrementCounter("flag_evaluation", "key", key, "result", "rollout_excluded")
            return defaultValue
        }
    }

    result := flag.DefaultValue
    if result == nil {
        result = defaultValue
    }

    c.metrics.IncrementCounter("flag_evaluation", "key", key, "result", "enabled")
    return result
}

func (c *FlagClient) evaluateTargeting(flag *Flag, ctx EvaluationContext) any {
    for _, rule := range flag.TargetingRules {
        value := c.getContextValue(ctx, rule.Attribute)

        if c.matchesRule(value, rule) {
            if variant, ok := flag.Variants[rule.Variant]; ok {
                return variant
            }
            return true
        }
    }
    return nil
}

func (c *FlagClient) matchesRule(value any, rule TargetingRule) bool {
    switch rule.Operator {
    case "eq":
        return value == rule.Value
    case "neq":
        return value != rule.Value
    case "in":
        if arr, ok := rule.Value.([]any); ok {
            for _, v := range arr {
                if v == value {
                    return true
                }
            }
        }
        return false
    default:
        return false
    }
}

func (c *FlagClient) hashToBucket(key, userID string) int {
    h := sha256.New()
    h.Write([]byte(key + "-" + userID))
    hash := h.Sum(nil)
    return int(binary.BigEndian.Uint32(hash[:4])) % 100
}

func (c *FlagClient) getContextValue(ctx EvaluationContext, attr string) any {
    switch attr {
    case "userId":
        return ctx.UserID
    case "email":
        return ctx.Email
    case "country":
        return ctx.Country
    case "plan":
        return ctx.Plan
    default:
        if ctx.Attributes != nil {
            return ctx.Attributes[attr]
        }
        return nil
    }
}

func (c *FlagClient) pollFlags(ctx context.Context) {
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()

    // Initial fetch
    c.refreshFlags(ctx)

    for {
        select {
        case <-ctx.Done():
            return
        case <-ticker.C:
            c.refreshFlags(ctx)
        }
    }
}

func (c *FlagClient) refreshFlags(ctx context.Context) {
    flags, err := c.provider.FetchFlags(ctx)
    if err != nil {
        c.metrics.IncrementCounter("flag_refresh_error")
        return
    }

    c.mu.Lock()
    for _, flag := range flags {
        c.flags[flag.Key] = flag
    }
    c.mu.Unlock()

    c.metrics.IncrementCounter("flag_refresh_success")
}

// Middleware for HTTP handlers
func (c *FlagClient) Middleware(flagKey string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ctx := r.Context()
            userID := getUserID(r)

            evalCtx := EvaluationContext{UserID: userID}

            if !c.Evaluate(ctx, flagKey, evalCtx, false).(bool) {
                http.Error(w, "Feature not available", http.StatusNotFound)
                return
            }

            next.ServeHTTP(w, r)
        })
    }
}
```

**Anti-Pattern**: Evaluating flags without user context.

### Pattern 4: Kill Switch Pattern

**When to Use**: Emergency feature disable

**Example**:
```typescript
// kill-switch.ts
interface KillSwitch {
  key: string;
  active: boolean;
  reason?: string;
  activatedAt?: Date;
  activatedBy?: string;
}

class KillSwitchService {
  private switches: Map<string, KillSwitch> = new Map();
  private listeners: Map<string, Set<(active: boolean) => void>> = new Map();

  constructor(private redis: RedisClient) {
    this.subscribeToUpdates();
  }

  async isKilled(key: string): Promise<boolean> {
    // Check local cache first
    const cached = this.switches.get(key);
    if (cached !== undefined) {
      return cached.active;
    }

    // Fetch from Redis
    const data = await this.redis.get(`killswitch:${key}`);
    if (!data) return false;

    const killSwitch: KillSwitch = JSON.parse(data);
    this.switches.set(key, killSwitch);
    return killSwitch.active;
  }

  async activate(
    key: string,
    reason: string,
    activatedBy: string
  ): Promise<void> {
    const killSwitch: KillSwitch = {
      key,
      active: true,
      reason,
      activatedAt: new Date(),
      activatedBy
    };

    await this.redis.set(
      `killswitch:${key}`,
      JSON.stringify(killSwitch)
    );

    // Publish to all instances
    await this.redis.publish('killswitch:updates', JSON.stringify({
      type: 'activate',
      ...killSwitch
    }));

    // Send alert
    await this.sendAlert(killSwitch);
  }

  async deactivate(key: string, deactivatedBy: string): Promise<void> {
    const killSwitch: KillSwitch = {
      key,
      active: false
    };

    await this.redis.set(
      `killswitch:${key}`,
      JSON.stringify(killSwitch)
    );

    await this.redis.publish('killswitch:updates', JSON.stringify({
      type: 'deactivate',
      key,
      deactivatedBy,
      deactivatedAt: new Date()
    }));
  }

  onUpdate(key: string, callback: (active: boolean) => void): () => void {
    if (!this.listeners.has(key)) {
      this.listeners.set(key, new Set());
    }
    this.listeners.get(key)!.add(callback);

    return () => this.listeners.get(key)?.delete(callback);
  }

  private subscribeToUpdates(): void {
    this.redis.subscribe('killswitch:updates', (message) => {
      const update = JSON.parse(message);

      this.switches.set(update.key, {
        key: update.key,
        active: update.type === 'activate',
        reason: update.reason,
        activatedAt: update.activatedAt,
        activatedBy: update.activatedBy
      });

      // Notify listeners
      const callbacks = this.listeners.get(update.key);
      if (callbacks) {
        callbacks.forEach(cb => cb(update.type === 'activate'));
      }
    });
  }

  private async sendAlert(killSwitch: KillSwitch): Promise<void> {
    await fetch(process.env.SLACK_WEBHOOK_URL!, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: `:rotating_light: Kill Switch Activated`,
        attachments: [{
          color: 'danger',
          fields: [
            { title: 'Feature', value: killSwitch.key, short: true },
            { title: 'Activated By', value: killSwitch.activatedBy, short: true },
            { title: 'Reason', value: killSwitch.reason }
          ]
        }]
      })
    });
  }
}

// Usage with circuit breaker
class FeatureService {
  constructor(
    private killSwitch: KillSwitchService,
    private flagService: FeatureFlagService
  ) {}

  async isFeatureEnabled(
    key: string,
    context: EvaluationContext
  ): Promise<boolean> {
    // Kill switch takes precedence
    if (await this.killSwitch.isKilled(key)) {
      return false;
    }

    return this.flagService.evaluate(key, context, false);
  }
}

// Express middleware
function killSwitchMiddleware(killSwitch: KillSwitchService, key: string) {
  return async (req: Request, res: Response, next: NextFunction) => {
    if (await killSwitch.isKilled(key)) {
      return res.status(503).json({
        error: 'Service temporarily unavailable',
        code: 'FEATURE_DISABLED'
      });
    }
    next();
  };
}
```

**Anti-Pattern**: Kill switches that require deployment to activate.

### Pattern 5: Percentage Rollout

**When to Use**: Gradual feature rollout

**Example**:
```typescript
// percentage-rollout.ts
interface RolloutConfig {
  flagKey: string;
  percentage: number;
  stages: RolloutStage[];
  currentStage: number;
}

interface RolloutStage {
  percentage: number;
  duration: number; // hours
  healthChecks: HealthCheck[];
}

interface HealthCheck {
  metric: string;
  threshold: number;
  operator: 'lt' | 'gt' | 'eq';
}

class RolloutService {
  constructor(
    private flagProvider: FlagProvider,
    private metrics: MetricsService,
    private scheduler: SchedulerService
  ) {}

  async startRollout(config: RolloutConfig): Promise<void> {
    // Set initial percentage
    await this.setPercentage(config.flagKey, config.stages[0].percentage);

    // Schedule progression
    await this.scheduleNextStage(config, 0);
  }

  private async scheduleNextStage(
    config: RolloutConfig,
    stageIndex: number
  ): Promise<void> {
    const stage = config.stages[stageIndex];

    this.scheduler.schedule(
      `rollout:${config.flagKey}:stage:${stageIndex}`,
      stage.duration * 60 * 60 * 1000, // Convert hours to ms
      async () => {
        // Check health before progressing
        const healthy = await this.checkHealth(stage.healthChecks);

        if (!healthy) {
          await this.rollback(config);
          return;
        }

        const nextStage = stageIndex + 1;
        if (nextStage < config.stages.length) {
          await this.setPercentage(
            config.flagKey,
            config.stages[nextStage].percentage
          );
          await this.scheduleNextStage(config, nextStage);
        } else {
          // Rollout complete
          await this.completeRollout(config);
        }
      }
    );
  }

  private async checkHealth(checks: HealthCheck[]): Promise<boolean> {
    for (const check of checks) {
      const value = await this.metrics.getMetric(check.metric);

      const passed = this.evaluateCheck(value, check);
      if (!passed) {
        console.error(`Health check failed: ${check.metric} = ${value}`);
        return false;
      }
    }
    return true;
  }

  private evaluateCheck(value: number, check: HealthCheck): boolean {
    switch (check.operator) {
      case 'lt': return value < check.threshold;
      case 'gt': return value > check.threshold;
      case 'eq': return value === check.threshold;
      default: return false;
    }
  }

  private async rollback(config: RolloutConfig): Promise<void> {
    await this.setPercentage(config.flagKey, 0);

    await this.notify({
      type: 'rollback',
      flag: config.flagKey,
      reason: 'Health check failed'
    });
  }

  private async completeRollout(config: RolloutConfig): Promise<void> {
    await this.setPercentage(config.flagKey, 100);

    await this.notify({
      type: 'complete',
      flag: config.flagKey
    });
  }

  private async setPercentage(key: string, percentage: number): Promise<void> {
    await this.flagProvider.updateFlag(key, { percentage });
  }

  private async notify(event: any): Promise<void> {
    // Send notification
  }
}

// Usage
const rolloutService = new RolloutService(flagProvider, metrics, scheduler);

await rolloutService.startRollout({
  flagKey: 'new-payment-flow',
  percentage: 0,
  currentStage: 0,
  stages: [
    {
      percentage: 5,
      duration: 1, // 1 hour
      healthChecks: [
        { metric: 'payment.error_rate', threshold: 0.01, operator: 'lt' },
        { metric: 'payment.latency_p99', threshold: 500, operator: 'lt' }
      ]
    },
    {
      percentage: 25,
      duration: 4,
      healthChecks: [
        { metric: 'payment.error_rate', threshold: 0.01, operator: 'lt' }
      ]
    },
    {
      percentage: 50,
      duration: 24,
      healthChecks: [
        { metric: 'payment.error_rate', threshold: 0.01, operator: 'lt' }
      ]
    },
    {
      percentage: 100,
      duration: 0,
      healthChecks: []
    }
  ]
});
```

**Anti-Pattern**: 0-100 rollout without gradual stages.

### Pattern 6: Feature Flag Testing

**When to Use**: Testing flag-dependent code

**Example**:
```typescript
// feature-flag.mock.ts
class MockFeatureFlagService implements FeatureFlagService {
  private overrides: Map<string, any> = new Map();

  setFlag(key: string, value: any): void {
    this.overrides.set(key, value);
  }

  clearFlag(key: string): void {
    this.overrides.delete(key);
  }

  clearAll(): void {
    this.overrides.clear();
  }

  async evaluate<T>(
    flagKey: string,
    context: EvaluationContext,
    defaultValue: T
  ): Promise<T> {
    if (this.overrides.has(flagKey)) {
      return this.overrides.get(flagKey) as T;
    }
    return defaultValue;
  }
}

// Test utilities
function withFeatureFlag(
  flagService: MockFeatureFlagService,
  key: string,
  value: any
) {
  return function(
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function(...args: any[]) {
      flagService.setFlag(key, value);
      try {
        return await originalMethod.apply(this, args);
      } finally {
        flagService.clearFlag(key);
      }
    };

    return descriptor;
  };
}

// Tests
describe('PaymentService', () => {
  let mockFlags: MockFeatureFlagService;
  let paymentService: PaymentService;

  beforeEach(() => {
    mockFlags = new MockFeatureFlagService();
    paymentService = new PaymentService(mockFlags);
  });

  afterEach(() => {
    mockFlags.clearAll();
  });

  describe('when new payment flow is enabled', () => {
    beforeEach(() => {
      mockFlags.setFlag('new-payment-flow', true);
    });

    it('should use new payment processor', async () => {
      const result = await paymentService.processPayment({
        amount: 100,
        currency: 'USD'
      });

      expect(result.processor).toBe('stripe-v2');
    });
  });

  describe('when new payment flow is disabled', () => {
    beforeEach(() => {
      mockFlags.setFlag('new-payment-flow', false);
    });

    it('should use legacy payment processor', async () => {
      const result = await paymentService.processPayment({
        amount: 100,
        currency: 'USD'
      });

      expect(result.processor).toBe('stripe-v1');
    });
  });

  describe('feature flag variants', () => {
    it('should handle variant A', async () => {
      mockFlags.setFlag('checkout-variant', 'A');

      const result = await paymentService.getCheckoutConfig();

      expect(result.layout).toBe('single-page');
    });

    it('should handle variant B', async () => {
      mockFlags.setFlag('checkout-variant', 'B');

      const result = await paymentService.getCheckoutConfig();

      expect(result.layout).toBe('multi-step');
    });
  });
});

// Integration test with flag matrix
describe('Feature Flag Integration', () => {
  const flagCombinations = [
    { 'feature-a': true, 'feature-b': true },
    { 'feature-a': true, 'feature-b': false },
    { 'feature-a': false, 'feature-b': true },
    { 'feature-a': false, 'feature-b': false }
  ];

  flagCombinations.forEach((flags) => {
    describe(`with flags ${JSON.stringify(flags)}`, () => {
      beforeEach(() => {
        Object.entries(flags).forEach(([key, value]) => {
          mockFlags.setFlag(key, value);
        });
      });

      it('should handle the flag combination correctly', async () => {
        const result = await service.process();
        expect(result).toBeDefined();
        // Add specific assertions based on flag combination
      });
    });
  });
});
```

**Anti-Pattern**: Tests that depend on production flag state.

## Checklist

- [ ] Flag evaluation is deterministic per user
- [ ] Default values handle missing flags
- [ ] Kill switches can be activated instantly
- [ ] Flag changes propagate in real-time
- [ ] Analytics track flag evaluations
- [ ] Testing mocks available for flags
- [ ] Percentage rollout uses consistent hashing
- [ ] Targeting rules are ordered by priority
- [ ] Flag data is cached with TTL
- [ ] Error handling returns safe defaults

## References

- [LaunchDarkly Best Practices](https://launchdarkly.com/blog/best-practices-for-feature-flags/)
- [Feature Flags Patterns](https://martinfowler.com/articles/feature-toggles.html)
- [OpenFeature Specification](https://openfeature.dev/)
- [Feature Flag Testing](https://www.split.io/blog/testing-feature-flags/)
