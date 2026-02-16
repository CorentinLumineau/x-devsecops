---
title: Authorization Database Schema Reference
category: security
type: reference
version: "1.0.0"
---

# Authorization Database Schema Patterns

> Part of the security/authorization knowledge skill

## Overview

Proper database schema design is crucial for implementing secure and performant authorization systems. This reference covers schema patterns for RBAC, ABAC, multi-tenancy, and resource-level permissions.

## 80/20 Quick Reference

**Essential tables for authorization:**

| Table | Purpose | When Required |
|-------|---------|---------------|
| users | Identity storage | Always |
| roles | Role definitions | RBAC |
| permissions | Permission definitions | Fine-grained RBAC |
| user_roles | User-role assignments | RBAC |
| role_permissions | Role-permission mapping | Fine-grained RBAC |
| resource_access | Resource-level sharing | Collaborative apps |
| audit_log | Authorization decisions | Compliance |

## Patterns

### Pattern 1: Core RBAC Schema

**When to Use**: Standard role-based access control

**Implementation**:
```sql
-- Users table with security fields
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  email_verified BOOLEAN DEFAULT FALSE,
  password_hash VARCHAR(255),

  -- MFA
  mfa_enabled BOOLEAN DEFAULT FALSE,
  mfa_secret_encrypted BYTEA,

  -- Account status
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'locked', 'deleted')),
  failed_login_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMP,

  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  last_login_at TIMESTAMP,
  password_changed_at TIMESTAMP
);

-- Roles table
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  is_system_role BOOLEAN DEFAULT FALSE,  -- Prevent deletion of system roles
  created_at TIMESTAMP DEFAULT NOW()
);

-- Permissions table
CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  resource VARCHAR(100) NOT NULL,  -- e.g., 'users', 'documents', 'api'
  action VARCHAR(50) NOT NULL,      -- e.g., 'read', 'write', 'delete', 'admin'
  description TEXT,
  UNIQUE(resource, action)
);

-- User-Role junction table
CREATE TABLE user_roles (
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID REFERENCES roles(id) ON DELETE CASCADE,

  -- Assignment metadata
  granted_by UUID REFERENCES users(id),
  granted_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP,  -- Time-limited roles

  PRIMARY KEY (user_id, role_id)
);

-- Role-Permission junction table
CREATE TABLE role_permissions (
  role_id UUID REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID REFERENCES permissions(id) ON DELETE CASCADE,

  -- Optional: conditions for permission
  conditions JSONB,  -- e.g., {"max_records": 100, "allowed_fields": ["name", "email"]}

  PRIMARY KEY (role_id, permission_id)
);

-- Indexes for performance
CREATE INDEX idx_user_roles_user ON user_roles(user_id);
CREATE INDEX idx_user_roles_role ON user_roles(role_id);
CREATE INDEX idx_user_roles_expires ON user_roles(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_role_permissions_role ON role_permissions(role_id);
CREATE INDEX idx_permissions_resource ON permissions(resource);
```

**Query: Get user permissions**
```sql
SELECT DISTINCT p.resource, p.action, rp.conditions
FROM users u
JOIN user_roles ur ON u.id = ur.user_id
JOIN roles r ON ur.role_id = r.id
JOIN role_permissions rp ON r.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id
WHERE u.id = $1
  AND u.status = 'active'
  AND (ur.expires_at IS NULL OR ur.expires_at > NOW());
```

**Anti-Pattern**: Storing roles as array in users table
```sql
-- BAD - no referential integrity, hard to query
CREATE TABLE users (
  id UUID PRIMARY KEY,
  roles TEXT[]  -- ['admin', 'user']
);
```

### Pattern 2: Hierarchical Roles

**When to Use**: When roles should inherit permissions from parent roles

**Implementation**:
```sql
-- Add parent reference to roles
ALTER TABLE roles ADD COLUMN parent_role_id UUID REFERENCES roles(id);

-- Prevent circular references
CREATE OR REPLACE FUNCTION check_role_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
  ancestor UUID;
BEGIN
  IF NEW.parent_role_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Check for cycles
  WITH RECURSIVE ancestors AS (
    SELECT id, parent_role_id FROM roles WHERE id = NEW.parent_role_id
    UNION ALL
    SELECT r.id, r.parent_role_id
    FROM roles r
    JOIN ancestors a ON r.id = a.parent_role_id
  )
  SELECT id INTO ancestor FROM ancestors WHERE id = NEW.id;

  IF FOUND THEN
    RAISE EXCEPTION 'Circular role hierarchy detected';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_role_hierarchy_trigger
BEFORE INSERT OR UPDATE ON roles
FOR EACH ROW EXECUTE FUNCTION check_role_hierarchy();

-- Query: Get all permissions including inherited
WITH RECURSIVE role_tree AS (
  -- Base: direct roles
  SELECT r.id, r.parent_role_id, 0 as depth
  FROM user_roles ur
  JOIN roles r ON ur.role_id = r.id
  WHERE ur.user_id = $1
    AND (ur.expires_at IS NULL OR ur.expires_at > NOW())

  UNION ALL

  -- Recursive: parent roles
  SELECT r.id, r.parent_role_id, rt.depth + 1
  FROM roles r
  JOIN role_tree rt ON r.id = rt.parent_role_id
  WHERE rt.depth < 10  -- Prevent infinite loops
)
SELECT DISTINCT p.resource, p.action
FROM role_tree rt
JOIN role_permissions rp ON rt.id = rp.role_id
JOIN permissions p ON rp.permission_id = p.id;
```

### Pattern 3: Resource-Level Permissions

**When to Use**: Collaborative applications with sharing capabilities

**Implementation**:
```sql
-- Resource ownership and sharing
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title VARCHAR(255) NOT NULL,
  content TEXT,
  owner_id UUID REFERENCES users(id) NOT NULL,

  -- Classification for ABAC
  classification VARCHAR(20) DEFAULT 'internal'
    CHECK (classification IN ('public', 'internal', 'confidential', 'restricted')),
  department VARCHAR(100),

  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Resource access grants
CREATE TABLE document_access (
  document_id UUID REFERENCES documents(id) ON DELETE CASCADE,

  -- Grantee can be user or role
  grantee_type VARCHAR(10) NOT NULL CHECK (grantee_type IN ('user', 'role', 'group')),
  grantee_id UUID NOT NULL,

  -- Permission level
  permission VARCHAR(20) NOT NULL CHECK (permission IN ('view', 'comment', 'edit', 'admin')),

  -- Metadata
  granted_by UUID REFERENCES users(id),
  granted_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP,

  PRIMARY KEY (document_id, grantee_type, grantee_id)
);

-- Index for finding what a user can access
CREATE INDEX idx_document_access_user ON document_access(grantee_id, grantee_type);
CREATE INDEX idx_document_access_doc ON document_access(document_id);

-- Query: Check if user can access document
SELECT EXISTS(
  SELECT 1 FROM documents d
  WHERE d.id = $1 AND (
    -- Owner has full access
    d.owner_id = $2
    OR
    -- Direct user grant
    EXISTS(
      SELECT 1 FROM document_access da
      WHERE da.document_id = d.id
        AND da.grantee_type = 'user'
        AND da.grantee_id = $2
        AND da.permission IN ('view', 'comment', 'edit', 'admin')
        AND (da.expires_at IS NULL OR da.expires_at > NOW())
    )
    OR
    -- Role-based grant
    EXISTS(
      SELECT 1 FROM document_access da
      JOIN user_roles ur ON da.grantee_id = ur.role_id
      WHERE da.document_id = d.id
        AND da.grantee_type = 'role'
        AND ur.user_id = $2
        AND da.permission IN ('view', 'comment', 'edit', 'admin')
        AND (da.expires_at IS NULL OR da.expires_at > NOW())
        AND (ur.expires_at IS NULL OR ur.expires_at > NOW())
    )
  )
) as can_access;
```

### Pattern 4: Multi-Tenant Authorization

**When to Use**: SaaS applications with organization-level isolation

**Implementation**:
```sql
-- Organizations (tenants)
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) UNIQUE NOT NULL,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Organization membership
CREATE TABLE organization_members (
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  role VARCHAR(50) NOT NULL DEFAULT 'member'
    CHECK (role IN ('owner', 'admin', 'member', 'guest')),
  invited_by UUID REFERENCES users(id),
  joined_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (organization_id, user_id)
);

-- Tenant-scoped resources
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE NOT NULL,
  name VARCHAR(255) NOT NULL,
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Row Level Security for automatic tenant isolation
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their organization's projects
CREATE POLICY projects_tenant_isolation ON projects
  FOR ALL
  USING (
    organization_id IN (
      SELECT organization_id FROM organization_members
      WHERE user_id = current_setting('app.current_user_id')::UUID
    )
  );

-- Set current user in session
CREATE OR REPLACE FUNCTION set_current_user(user_id UUID)
RETURNS VOID AS $$
BEGIN
  PERFORM set_config('app.current_user_id', user_id::TEXT, FALSE);
END;
$$ LANGUAGE plpgsql;

-- Query with RLS active
SET app.current_user_id = '123e4567-e89b-12d3-a456-426614174000';
SELECT * FROM projects;  -- Only shows user's organization's projects
```

### Pattern 5: Audit Log Schema

**When to Use**: Compliance requirements, security monitoring

**Implementation**:
```sql
-- Audit log table (append-only)
CREATE TABLE authorization_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Who
  user_id UUID REFERENCES users(id),
  user_email VARCHAR(255),  -- Denormalized for historical accuracy
  session_id UUID,

  -- What
  action VARCHAR(100) NOT NULL,  -- e.g., 'document:read', 'user:delete'
  resource_type VARCHAR(100),
  resource_id UUID,

  -- Decision
  decision VARCHAR(10) NOT NULL CHECK (decision IN ('permit', 'deny')),
  policy_id VARCHAR(100),  -- Which policy made the decision
  reason TEXT,

  -- Context
  request_path VARCHAR(500),
  request_method VARCHAR(10),
  ip_address INET,
  user_agent TEXT,

  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),

  -- Additional context as JSON
  context JSONB
);

-- Partition by month for performance
CREATE TABLE authorization_audit_log_2024_01 PARTITION OF authorization_audit_log
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Indexes for common queries
CREATE INDEX idx_audit_user ON authorization_audit_log(user_id, created_at DESC);
CREATE INDEX idx_audit_resource ON authorization_audit_log(resource_type, resource_id);
CREATE INDEX idx_audit_decision ON authorization_audit_log(decision, created_at DESC);
CREATE INDEX idx_audit_denied ON authorization_audit_log(created_at DESC) WHERE decision = 'deny';

-- Prevent updates/deletes on audit log
CREATE RULE no_update_audit AS ON UPDATE TO authorization_audit_log DO INSTEAD NOTHING;
CREATE RULE no_delete_audit AS ON DELETE TO authorization_audit_log DO INSTEAD NOTHING;
```

## Checklist

- [ ] Foreign key constraints maintain referential integrity
- [ ] Indexes exist for authorization query patterns
- [ ] Time-limited role assignments supported (expires_at)
- [ ] Audit logging captures all authorization decisions
- [ ] Row Level Security enforces tenant isolation
- [ ] Cascading deletes clean up orphaned records
- [ ] Circular references prevented in hierarchies
- [ ] Permission conditions stored as JSONB for flexibility
- [ ] Soft deletes preserve audit trail
- [ ] Regular cleanup of expired assignments

## References

- [PostgreSQL Row Level Security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Database Schema Best Practices](https://www.postgresql.org/docs/current/ddl.html)
- [Multi-Tenant Data Architecture](https://docs.microsoft.com/en-us/azure/architecture/patterns/multi-tenant)
