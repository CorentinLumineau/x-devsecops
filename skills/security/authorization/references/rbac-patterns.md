---
title: RBAC Patterns Reference
category: security
type: reference
version: "1.0.0"
---

# Role-Based Access Control Patterns

> Part of the security/authorization knowledge skill

## Overview

Role-Based Access Control (RBAC) assigns permissions to roles rather than individual users, simplifying access management. Users are assigned roles, and roles contain permissions. This reference covers implementation patterns from simple to hierarchical RBAC.

## 80/20 Quick Reference

**RBAC implementation priorities:**

| Priority | Pattern | Impact |
|----------|---------|--------|
| 1 | Deny by default | Prevents unauthorized access |
| 2 | Role middleware | Centralizes authorization |
| 3 | Hierarchical roles | Reduces duplication |
| 4 | Permission caching | Improves performance |
| 5 | Audit logging | Enables compliance |

## Patterns

### Pattern 1: Simple Role Check Middleware

**When to Use**: Applications with 2-5 distinct user types

**Implementation**:
```typescript
// Role definitions
enum Role {
  USER = 'user',
  MODERATOR = 'moderator',
  ADMIN = 'admin',
  SUPER_ADMIN = 'super_admin'
}

interface User {
  id: string;
  email: string;
  roles: Role[];
}

// Middleware factory
function requireRole(...allowedRoles: Role[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    // Must be authenticated first
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    // Check if user has any of the allowed roles
    const hasRole = req.user.roles.some(role => allowedRoles.includes(role));

    if (!hasRole) {
      // Log authorization failure
      auditLog.warn({
        event: 'AUTHORIZATION_DENIED',
        userId: req.user.id,
        resource: req.path,
        method: req.method,
        requiredRoles: allowedRoles,
        userRoles: req.user.roles
      });

      return res.status(403).json({
        error: 'Forbidden',
        message: 'Insufficient permissions'
      });
    }

    next();
  };
}

// Usage
app.get('/api/users', requireAuth, requireRole(Role.ADMIN), listUsers);
app.delete('/api/users/:id', requireAuth, requireRole(Role.SUPER_ADMIN), deleteUser);
app.post('/api/posts', requireAuth, requireRole(Role.USER, Role.MODERATOR, Role.ADMIN), createPost);
```

**Anti-Pattern**: Checking roles in business logic
```typescript
// BAD - scattered authorization checks
async function deleteUser(userId: string, currentUser: User) {
  if (currentUser.role !== 'admin') { // Inconsistent checks
    throw new Error('Not allowed');
  }
  // ...
}
```

### Pattern 2: Hierarchical Roles

**When to Use**: When higher roles should inherit lower role permissions

**Implementation**:
```typescript
// Role hierarchy definition
const roleHierarchy: Record<Role, Role[]> = {
  [Role.SUPER_ADMIN]: [Role.SUPER_ADMIN, Role.ADMIN, Role.MODERATOR, Role.USER],
  [Role.ADMIN]: [Role.ADMIN, Role.MODERATOR, Role.USER],
  [Role.MODERATOR]: [Role.MODERATOR, Role.USER],
  [Role.USER]: [Role.USER]
};

// Get all effective roles (including inherited)
function getEffectiveRoles(userRoles: Role[]): Role[] {
  const effectiveRoles = new Set<Role>();

  for (const role of userRoles) {
    const inherited = roleHierarchy[role] || [role];
    inherited.forEach(r => effectiveRoles.add(r));
  }

  return Array.from(effectiveRoles);
}

// Enhanced middleware with hierarchy
function requireRole(...allowedRoles: Role[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const effectiveRoles = getEffectiveRoles(req.user.roles);
    const hasRole = effectiveRoles.some(role => allowedRoles.includes(role));

    if (!hasRole) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Attach effective roles for downstream use
    req.user.effectiveRoles = effectiveRoles;
    next();
  };
}

// Usage: Admin can access user routes automatically
app.get('/api/profile', requireAuth, requireRole(Role.USER), getProfile);
// Admin has USER role via hierarchy, so this works
```

**Anti-Pattern**: Flat role checks without inheritance
```typescript
// TEDIOUS - must list every role
app.get('/api/posts', requireRole('user', 'moderator', 'admin', 'super_admin'));
```

### Pattern 3: Role-Permission Mapping

**When to Use**: Fine-grained permissions beyond simple roles

**Implementation**:
```typescript
// Permission definitions
enum Permission {
  USER_READ = 'user:read',
  USER_WRITE = 'user:write',
  USER_DELETE = 'user:delete',
  POST_READ = 'post:read',
  POST_WRITE = 'post:write',
  POST_DELETE = 'post:delete',
  COMMENT_MODERATE = 'comment:moderate',
  SYSTEM_ADMIN = 'system:admin'
}

// Role to permission mapping
const rolePermissions: Record<Role, Permission[]> = {
  [Role.USER]: [
    Permission.USER_READ,
    Permission.POST_READ,
    Permission.POST_WRITE
  ],
  [Role.MODERATOR]: [
    Permission.USER_READ,
    Permission.POST_READ,
    Permission.POST_WRITE,
    Permission.POST_DELETE,
    Permission.COMMENT_MODERATE
  ],
  [Role.ADMIN]: [
    Permission.USER_READ,
    Permission.USER_WRITE,
    Permission.POST_READ,
    Permission.POST_WRITE,
    Permission.POST_DELETE,
    Permission.COMMENT_MODERATE
  ],
  [Role.SUPER_ADMIN]: [
    Permission.USER_READ,
    Permission.USER_WRITE,
    Permission.USER_DELETE,
    Permission.POST_READ,
    Permission.POST_WRITE,
    Permission.POST_DELETE,
    Permission.COMMENT_MODERATE,
    Permission.SYSTEM_ADMIN
  ]
};

// Get user permissions from roles
function getUserPermissions(roles: Role[]): Permission[] {
  const permissions = new Set<Permission>();

  for (const role of roles) {
    const rolePerms = rolePermissions[role] || [];
    rolePerms.forEach(p => permissions.add(p));
  }

  return Array.from(permissions);
}

// Permission-based middleware
function requirePermission(...requiredPermissions: Permission[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({ error: 'Authentication required' });
    }

    const userPermissions = getUserPermissions(req.user.roles);
    const hasPermission = requiredPermissions.every(
      p => userPermissions.includes(p)
    );

    if (!hasPermission) {
      return res.status(403).json({
        error: 'Forbidden',
        required: requiredPermissions,
        missing: requiredPermissions.filter(p => !userPermissions.includes(p))
      });
    }

    next();
  };
}

// Usage
app.delete('/api/users/:id',
  requireAuth,
  requirePermission(Permission.USER_DELETE),
  deleteUser
);
```

### Pattern 4: Database-Backed RBAC

**When to Use**: Dynamic role/permission management, enterprise applications

**Implementation**:
```sql
-- Database schema
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  parent_role_id UUID REFERENCES roles(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource VARCHAR(100) NOT NULL,
  action VARCHAR(50) NOT NULL,
  description TEXT,
  UNIQUE(resource, action)
);

CREATE TABLE role_permissions (
  role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE user_roles (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
  granted_by UUID REFERENCES users(id),
  granted_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP,
  PRIMARY KEY (user_id, role_id)
);

-- Recursive query for role hierarchy
WITH RECURSIVE role_tree AS (
  SELECT id, name, parent_role_id, 0 as depth
  FROM roles
  WHERE id = $1  -- Starting role
  UNION ALL
  SELECT r.id, r.name, r.parent_role_id, rt.depth + 1
  FROM roles r
  JOIN role_tree rt ON r.id = rt.parent_role_id
  WHERE rt.depth < 10  -- Prevent infinite loops
)
SELECT DISTINCT p.*
FROM role_tree rt
JOIN role_permissions rp ON rt.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id;
```

```typescript
// Repository with caching
class RBACService {
  private cache: Map<string, CachedPermissions> = new Map();
  private readonly CACHE_TTL = 5 * 60 * 1000; // 5 minutes

  async getUserPermissions(userId: string): Promise<Permission[]> {
    // Check cache
    const cached = this.cache.get(userId);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.permissions;
    }

    // Query database
    const permissions = await this.db.query(`
      SELECT DISTINCT p.resource, p.action
      FROM user_roles ur
      JOIN role_permissions rp ON ur.role_id = rp.role_id
      JOIN permissions p ON rp.permission_id = p.id
      WHERE ur.user_id = $1
        AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
    `, [userId]);

    // Cache result
    this.cache.set(userId, {
      permissions,
      expiresAt: Date.now() + this.CACHE_TTL
    });

    return permissions;
  }

  invalidateCache(userId: string) {
    this.cache.delete(userId);
  }
}
```

**Anti-Pattern**: Not caching permissions
```typescript
// SLOW - queries database on every request
async function checkPermission(userId: string, permission: string) {
  const result = await db.query(/* complex join */);
  return result.length > 0;
}
```

## Checklist

- [ ] Default deny - no access without explicit grant
- [ ] Roles assigned via database, not hardcoded
- [ ] Role hierarchy prevents permission duplication
- [ ] Permissions cached with appropriate TTL
- [ ] Cache invalidated on role changes
- [ ] Authorization failures logged with context
- [ ] Separation of authentication and authorization middleware
- [ ] Time-limited role assignments supported
- [ ] Role assignment requires elevated permissions
- [ ] Regular audit of role assignments

## References

- [NIST RBAC Model](https://csrc.nist.gov/projects/role-based-access-control)
- [OWASP Authorization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
