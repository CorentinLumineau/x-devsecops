---
title: ABAC Policies Reference
category: security
type: reference
version: "1.0.0"
---

# Attribute-Based Access Control Policies

> Part of the security/authorization knowledge skill

## Overview

Attribute-Based Access Control (ABAC) makes authorization decisions based on attributes of the subject (user), object (resource), action, and environment. This enables dynamic, fine-grained policies without pre-defined roles.

## 80/20 Quick Reference

**ABAC components:**

| Component | Description | Examples |
|-----------|-------------|----------|
| Subject | Who is requesting | department, clearance, location |
| Object | What is being accessed | owner, classification, type |
| Action | Operation requested | read, write, delete, approve |
| Environment | Contextual conditions | time, IP, device |

**When to use ABAC over RBAC:**
- Complex business rules spanning multiple attributes
- Multi-tenant applications
- Dynamic policies that change frequently
- Healthcare, finance, government compliance

## Patterns

### Pattern 1: Policy Engine Architecture

**When to Use**: Applications requiring flexible, maintainable policies

**Implementation**:
```typescript
// Policy context contains all decision inputs
interface PolicyContext {
  subject: {
    id: string;
    roles: string[];
    department: string;
    clearanceLevel: number;
    location: string;
    attributes: Record<string, any>;
  };
  object: {
    type: string;
    id: string;
    ownerId: string;
    classification: string;
    department: string;
    attributes: Record<string, any>;
  };
  action: string;
  environment: {
    timestamp: Date;
    ipAddress: string;
    userAgent: string;
    requestId: string;
  };
}

// Policy definition
interface Policy {
  id: string;
  name: string;
  description: string;
  target: PolicyTarget;      // When policy applies
  condition: PolicyCondition; // The actual rule
  effect: 'permit' | 'deny';
  priority: number;
}

interface PolicyTarget {
  subjects?: Record<string, any>;
  objects?: Record<string, any>;
  actions?: string[];
}

// Policy engine
class PolicyEngine {
  private policies: Policy[] = [];

  addPolicy(policy: Policy) {
    this.policies.push(policy);
    // Sort by priority (higher = evaluated first)
    this.policies.sort((a, b) => b.priority - a.priority);
  }

  evaluate(context: PolicyContext): PolicyDecision {
    const applicablePolicies = this.policies.filter(p =>
      this.matchesTarget(p.target, context)
    );

    if (applicablePolicies.length === 0) {
      return { decision: 'deny', reason: 'No applicable policies' };
    }

    for (const policy of applicablePolicies) {
      const result = this.evaluateCondition(policy.condition, context);

      if (result) {
        return {
          decision: policy.effect,
          policyId: policy.id,
          reason: policy.name
        };
      }
    }

    // Default deny
    return { decision: 'deny', reason: 'No matching conditions' };
  }

  private matchesTarget(target: PolicyTarget, context: PolicyContext): boolean {
    if (target.actions && !target.actions.includes(context.action)) {
      return false;
    }

    if (target.objects) {
      for (const [key, value] of Object.entries(target.objects)) {
        if (context.object[key] !== value && context.object.attributes?.[key] !== value) {
          return false;
        }
      }
    }

    if (target.subjects) {
      for (const [key, value] of Object.entries(target.subjects)) {
        if (context.subject[key] !== value && context.subject.attributes?.[key] !== value) {
          return false;
        }
      }
    }

    return true;
  }
}
```

**Anti-Pattern**: Embedding policies in code
```typescript
// BAD - policies hardcoded in application
if (user.department === 'finance' && document.type === 'budget') {
  // allow
}
```

### Pattern 2: Common ABAC Policies

**When to Use**: Standard enterprise authorization scenarios

**Implementation**:
```typescript
// Policy: Owner can manage their own resources
const ownerPolicy: Policy = {
  id: 'owner-full-access',
  name: 'Resource Owner Full Access',
  description: 'Resource owners have full control',
  target: {
    actions: ['read', 'write', 'delete', 'share']
  },
  condition: {
    type: 'equals',
    left: { type: 'subject', path: 'id' },
    right: { type: 'object', path: 'ownerId' }
  },
  effect: 'permit',
  priority: 100
};

// Policy: Same department can view
const departmentViewPolicy: Policy = {
  id: 'department-view',
  name: 'Department Members Can View',
  description: 'Users can view resources in their department',
  target: {
    actions: ['read']
  },
  condition: {
    type: 'and',
    conditions: [
      {
        type: 'equals',
        left: { type: 'subject', path: 'department' },
        right: { type: 'object', path: 'department' }
      },
      {
        type: 'in',
        left: { type: 'object', path: 'classification' },
        right: { type: 'literal', value: ['public', 'internal'] }
      }
    ]
  },
  effect: 'permit',
  priority: 50
};

// Policy: Time-based access
const businessHoursPolicy: Policy = {
  id: 'business-hours-only',
  name: 'Sensitive Access During Business Hours',
  description: 'Classified documents only accessible during business hours',
  target: {
    objects: { classification: 'confidential' },
    actions: ['read', 'write']
  },
  condition: {
    type: 'and',
    conditions: [
      {
        type: 'gte',
        left: { type: 'environment', path: 'timestamp', transform: 'hour' },
        right: { type: 'literal', value: 9 }
      },
      {
        type: 'lte',
        left: { type: 'environment', path: 'timestamp', transform: 'hour' },
        right: { type: 'literal', value: 17 }
      },
      {
        type: 'in',
        left: { type: 'environment', path: 'timestamp', transform: 'dayOfWeek' },
        right: { type: 'literal', value: [1, 2, 3, 4, 5] } // Mon-Fri
      }
    ]
  },
  effect: 'permit',
  priority: 75
};

// Policy: Clearance level requirement
const clearanceLevelPolicy: Policy = {
  id: 'clearance-required',
  name: 'Clearance Level Requirement',
  description: 'User clearance must meet or exceed resource classification',
  target: {
    actions: ['read', 'write']
  },
  condition: {
    type: 'gte',
    left: { type: 'subject', path: 'clearanceLevel' },
    right: { type: 'object', path: 'attributes.requiredClearance' }
  },
  effect: 'permit',
  priority: 90
};
```

### Pattern 3: Express Middleware Integration

**When to Use**: Integrating ABAC into web applications

**Implementation**:
```typescript
class ABACMiddleware {
  constructor(private policyEngine: PolicyEngine) {}

  // Generic authorization middleware
  authorize(action: string, getResource?: (req: Request) => Promise<any>) {
    return async (req: Request, res: Response, next: NextFunction) => {
      if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
      }

      // Build context
      const context: PolicyContext = {
        subject: {
          id: req.user.id,
          roles: req.user.roles,
          department: req.user.department,
          clearanceLevel: req.user.clearanceLevel,
          location: req.user.location,
          attributes: req.user.attributes || {}
        },
        object: getResource
          ? await this.buildObjectContext(await getResource(req))
          : { type: 'endpoint', id: req.path, ownerId: '', classification: 'public', department: '', attributes: {} },
        action,
        environment: {
          timestamp: new Date(),
          ipAddress: req.ip,
          userAgent: req.headers['user-agent'] || '',
          requestId: req.headers['x-request-id'] as string || ''
        }
      };

      const decision = this.policyEngine.evaluate(context);

      // Log decision
      await this.auditLog.log({
        userId: req.user.id,
        action,
        resource: context.object,
        decision: decision.decision,
        policyId: decision.policyId,
        timestamp: new Date()
      });

      if (decision.decision === 'deny') {
        return res.status(403).json({
          error: 'Access denied',
          reason: decision.reason
        });
      }

      // Attach context for downstream use
      req.authContext = context;
      next();
    };
  }

  private buildObjectContext(resource: any) {
    return {
      type: resource.type || resource.constructor.name,
      id: resource.id,
      ownerId: resource.ownerId || resource.owner_id,
      classification: resource.classification || 'internal',
      department: resource.department,
      attributes: resource.attributes || resource
    };
  }
}

// Usage
const abac = new ABACMiddleware(policyEngine);

app.get('/api/documents/:id',
  requireAuth,
  abac.authorize('read', async (req) => {
    return documentService.findById(req.params.id);
  }),
  getDocument
);

app.put('/api/documents/:id',
  requireAuth,
  abac.authorize('write', async (req) => {
    return documentService.findById(req.params.id);
  }),
  updateDocument
);
```

### Pattern 4: Policy Condition DSL

**When to Use**: Complex policy conditions that need to be readable

**Implementation**:
```typescript
// Condition evaluator
class ConditionEvaluator {
  evaluate(condition: PolicyCondition, context: PolicyContext): boolean {
    switch (condition.type) {
      case 'equals':
        return this.getValue(condition.left, context) ===
               this.getValue(condition.right, context);

      case 'notEquals':
        return this.getValue(condition.left, context) !==
               this.getValue(condition.right, context);

      case 'gte':
        return this.getValue(condition.left, context) >=
               this.getValue(condition.right, context);

      case 'lte':
        return this.getValue(condition.left, context) <=
               this.getValue(condition.right, context);

      case 'in':
        const value = this.getValue(condition.left, context);
        const list = this.getValue(condition.right, context);
        return Array.isArray(list) && list.includes(value);

      case 'contains':
        const arr = this.getValue(condition.left, context);
        const item = this.getValue(condition.right, context);
        return Array.isArray(arr) && arr.includes(item);

      case 'matches':
        const str = this.getValue(condition.left, context);
        const pattern = this.getValue(condition.right, context);
        return new RegExp(pattern).test(str);

      case 'and':
        return condition.conditions.every(c => this.evaluate(c, context));

      case 'or':
        return condition.conditions.some(c => this.evaluate(c, context));

      case 'not':
        return !this.evaluate(condition.condition, context);

      default:
        throw new Error(`Unknown condition type: ${condition.type}`);
    }
  }

  private getValue(ref: ValueReference, context: PolicyContext): any {
    if (ref.type === 'literal') {
      return ref.value;
    }

    let value: any;
    switch (ref.type) {
      case 'subject':
        value = this.getPath(context.subject, ref.path);
        break;
      case 'object':
        value = this.getPath(context.object, ref.path);
        break;
      case 'environment':
        value = this.getPath(context.environment, ref.path);
        break;
    }

    if (ref.transform) {
      value = this.transform(value, ref.transform);
    }

    return value;
  }

  private getPath(obj: any, path: string): any {
    return path.split('.').reduce((o, k) => o?.[k], obj);
  }

  private transform(value: any, transform: string): any {
    switch (transform) {
      case 'hour':
        return new Date(value).getHours();
      case 'dayOfWeek':
        return new Date(value).getDay();
      case 'lowercase':
        return String(value).toLowerCase();
      case 'length':
        return Array.isArray(value) ? value.length : String(value).length;
      default:
        return value;
    }
  }
}
```

## Checklist

- [ ] Policy engine separates policy logic from application code
- [ ] All policy decisions are logged for audit
- [ ] Default deny when no policies match
- [ ] Policies are tested independently
- [ ] Policy changes don't require code deployment
- [ ] Context includes all relevant attributes
- [ ] Environment factors (time, location) considered
- [ ] Policy conflicts resolved by priority
- [ ] Regular policy review and cleanup
- [ ] Performance testing with realistic policy sets

## References

- [NIST ABAC Guide](https://csrc.nist.gov/publications/detail/sp/800-162/final)
- [XACML Standard](http://docs.oasis-open.org/xacml/3.0/xacml-3.0-core-spec-os-en.html)
- [Open Policy Agent (OPA)](https://www.openpolicyagent.org/)
- [AWS Cedar Policy Language](https://www.cedarpolicy.com/)
