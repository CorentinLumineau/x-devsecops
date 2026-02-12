---
name: authorization
description: Access control strategies for determining user permissions. RBAC, ABAC, ownership.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: security
---

# Authorization

Determines what authenticated users are allowed to do.

## Pattern Selection

| Use Case | Pattern | Complexity |
|----------|---------|------------|
| Simple app (2-3 user types) | RBAC | Low |
| Enterprise (many roles) | RBAC + Permissions | Medium |
| Complex business rules | ABAC | High |
| User-owned resources | Resource-based | Low |
| Multi-tenant SaaS | ABAC + Resource-based | High |

## RBAC (Role-Based Access Control)

**How it works**: Users → Roles → Permissions

```
User: john@example.com
  ↓
Roles: [admin, user]
  ↓
Permissions: [users.read, users.write, posts.delete]
```

### Role Hierarchy
```
admin → [admin, moderator, user]
moderator → [moderator, user]
user → [user]
```

## ABAC (Attribute-Based Access Control)

**How it works**: User attributes + Resource attributes + Environment → Decision

**Policy example**:
```
canEdit(user, resource):
  - Owner can edit
  - Admin can edit
  - Same-department moderator can edit
  - Otherwise deny
```

## Resource-Based Authorization

**Check ownership** before allowing access:
```
if (resource.ownerId !== currentUser.id) {
  return 403 Forbidden
}
```

## Best Practices

| Practice | Description |
|----------|-------------|
| Default deny | Require explicit grants |
| Separate auth layers | Authentication ≠ Authorization |
| Defense in depth | Check at API, service, and DB layers |
| Audit failures | Log all access denials |
| Hide existence | Return 404 instead of 403 for unauthorized resources |

## HTTP Status Codes

| Code | Meaning | When to Use |
|------|---------|-------------|
| 401 | Unauthorized | Not authenticated (missing/invalid token) |
| 403 | Forbidden | Authenticated but lacks permission |
| 404 | Not Found | Hide resource existence from unauthorized users |

## Security Checklist

- [ ] Default deny (explicit permission grants)
- [ ] Enforce at multiple layers (API, service, database)
- [ ] Never trust client-provided roles
- [ ] Validate authorization on every request
- [ ] Log authorization failures
- [ ] Use 404 to hide resource existence when appropriate

## When to Load References

- **For RBAC implementation**: See `references/rbac-patterns.md`
- **For ABAC policies**: See `references/abac-policies.md`
- **For database schema**: See `references/auth-schema.md`

---

## Related Skills

- **[authentication](../authentication/SKILL.md)** - Identity verification before authorization
- **[input-validation](../input-validation/SKILL.md)** - Validate inputs to prevent privilege escalation
- **[compliance](../compliance/SKILL.md)** - Regulatory access control requirements (SOC 2, GDPR)
