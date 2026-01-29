---
title: Large-Scale Refactoring Reference
category: code
type: reference
version: "1.0.0"
---

# Large-Scale Refactoring

> Part of the code/refactoring-patterns knowledge skill

## Overview

Large-scale refactoring involves restructuring significant portions of a codebase. Unlike small refactorings that take minutes, these span days to months and require careful planning, incremental delivery, and coordination across teams.

## Quick Reference (80/20)

| Strategy | Duration | Risk | Best For |
|----------|----------|------|----------|
| Strangler Fig | Months | Low | Monolith decomposition |
| Branch by Abstraction | Weeks | Low-medium | Swapping implementations |
| Parallel Run | Weeks | Low | Verifying replacement correctness |
| Feature Toggle Migration | Days-weeks | Low | Gradual rollout |
| Big Bang Rewrite | Months | Very high | Almost never recommended |

## Patterns

### Pattern 1: Strangler Fig

**When to Use**: Incrementally replacing a legacy system

**Example**:
```
Phase 1: Intercept
┌─────────────────────────────────────┐
│         API Gateway / Proxy          │
│  ┌─────────┐       ┌─────────────┐  │
│  │ /users  │──────▶│ Legacy App  │  │
│  │ /orders │──────▶│             │  │
│  │ /items  │──────▶│             │  │
│  └─────────┘       └─────────────┘  │
└─────────────────────────────────────┘

Phase 2: Migrate incrementally
┌─────────────────────────────────────┐
│         API Gateway / Proxy          │
│  ┌─────────┐       ┌─────────────┐  │
│  │ /users  │──────▶│ New Service │  │
│  │ /orders │──────▶│ Legacy App  │  │
│  │ /items  │──────▶│ Legacy App  │  │
│  └─────────┘       └─────────────┘  │
└─────────────────────────────────────┘

Phase 3: Complete
┌─────────────────────────────────────┐
│         API Gateway / Proxy          │
│  ┌─────────┐       ┌─────────────┐  │
│  │ /users  │──────▶│ User Svc    │  │
│  │ /orders │──────▶│ Order Svc   │  │
│  │ /items  │──────▶│ Item Svc    │  │
│  └─────────┘       └─────────────┘  │
└─────────────────────────────────────┘
```

```python
# strangler_proxy.py - Routing between old and new implementations
from fastapi import FastAPI, Request
from fastapi.responses import Response
import httpx

app = FastAPI()

ROUTE_CONFIG = {
    # path_prefix: (target_service, migrated)
    "/api/users": ("http://new-user-service:8080", True),
    "/api/orders": ("http://legacy-app:3000", False),
    "/api/items": ("http://legacy-app:3000", False),
}

@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH"])
async def proxy(request: Request, path: str):
    target_service = None
    for prefix, (service, migrated) in ROUTE_CONFIG.items():
        if f"/{path}".startswith(prefix):
            target_service = service
            break

    if not target_service:
        target_service = "http://legacy-app:3000"  # Default to legacy

    # Forward request
    async with httpx.AsyncClient() as client:
        response = await client.request(
            method=request.method,
            url=f"{target_service}/{path}",
            headers=dict(request.headers),
            content=await request.body(),
            params=request.query_params,
        )

    return Response(
        content=response.content,
        status_code=response.status_code,
        headers=dict(response.headers),
    )
```

**Anti-Pattern**: Trying to migrate everything at once instead of route by route.

### Pattern 2: Branch by Abstraction

**When to Use**: Replacing an internal component while keeping the system running

**Example**:
```python
# Step 1: Introduce abstraction layer
from abc import ABC, abstractmethod

class NotificationSender(ABC):
    @abstractmethod
    def send(self, recipient: str, message: str) -> bool: ...

# Step 2: Wrap existing implementation
class LegacyEmailSender(NotificationSender):
    def __init__(self):
        self.legacy = OldEmailLibrary()

    def send(self, recipient: str, message: str) -> bool:
        return self.legacy.send_email(recipient, "Notification", message)

# Step 3: Build new implementation
class ModernEmailSender(NotificationSender):
    def __init__(self, api_key: str):
        self.client = SendGridClient(api_key)

    def send(self, recipient: str, message: str) -> bool:
        return self.client.send(
            to=recipient,
            subject="Notification",
            body=message,
        )

# Step 4: Toggle between implementations
class NotificationFactory:
    @staticmethod
    def create(use_modern: bool = False) -> NotificationSender:
        if use_modern:
            return ModernEmailSender(api_key=config.SENDGRID_KEY)
        return LegacyEmailSender()

# Step 5: All callers use abstraction
class OrderService:
    def __init__(self, notifier: NotificationSender):
        self.notifier = notifier

    def complete_order(self, order: Order):
        order.status = "completed"
        self.notifier.send(order.customer_email, f"Order {order.id} completed")

# Step 6: After validation, remove legacy
# Delete LegacyEmailSender, simplify factory
```

**Anti-Pattern**: Skipping the abstraction layer and doing a direct swap.

### Pattern 3: Parallel Run

**When to Use**: Verifying a replacement produces identical results

**Example**:
```python
# parallel_run.py
import logging
from typing import Any, Callable
import json

logger = logging.getLogger("parallel_run")

class ParallelRunner:
    """Run old and new implementations, compare results, return old."""

    def __init__(self, name: str):
        self.name = name
        self.mismatch_count = 0
        self.total_count = 0

    def run(
        self,
        old_fn: Callable[..., Any],
        new_fn: Callable[..., Any],
        *args,
        **kwargs,
    ) -> Any:
        self.total_count += 1

        # Always run old (source of truth)
        old_result = old_fn(*args, **kwargs)

        # Run new, catch any errors
        try:
            new_result = new_fn(*args, **kwargs)
        except Exception as e:
            self.mismatch_count += 1
            logger.error(
                f"[{self.name}] New implementation raised: {e}",
                extra={"args": str(args)},
            )
            return old_result

        # Compare
        if not self._results_match(old_result, new_result):
            self.mismatch_count += 1
            logger.warning(
                f"[{self.name}] Mismatch detected",
                extra={
                    "old_result": json.dumps(old_result, default=str),
                    "new_result": json.dumps(new_result, default=str),
                    "args": str(args),
                },
            )

        return old_result  # Always return old result

    def _results_match(self, old: Any, new: Any) -> bool:
        return json.dumps(old, sort_keys=True, default=str) == \
               json.dumps(new, sort_keys=True, default=str)

    @property
    def mismatch_rate(self) -> float:
        if self.total_count == 0:
            return 0.0
        return self.mismatch_count / self.total_count

# Usage
pricing_runner = ParallelRunner("pricing")

def get_price(product_id: str) -> float:
    return pricing_runner.run(
        old_fn=legacy_pricing.calculate,
        new_fn=new_pricing.calculate,
        product_id,
    )
```

**Anti-Pattern**: Running parallel implementations without monitoring or comparison metrics.

### Pattern 4: Modularization of a Monolith

**When to Use**: Breaking a monolith into modules before extracting services

**Example**:
```
Step 1: Identify boundaries (domain analysis)
┌──────────────────────────────────┐
│            Monolith               │
│  Users + Orders + Inventory +    │
│  Payments + Notifications        │
└──────────────────────────────────┘

Step 2: Create internal module boundaries
┌──────────────────────────────────┐
│            Monolith               │
│  ┌───────┐ ┌────────┐ ┌───────┐ │
│  │ Users │ │ Orders │ │ Inv.  │ │
│  └───┬───┘ └───┬────┘ └───┬───┘ │
│      │         │           │     │
│      └─────────┼───────────┘     │
│          Internal APIs           │
└──────────────────────────────────┘

Step 3: Enforce boundaries (no cross-module DB access)
- Each module owns its tables
- Communication through defined interfaces
- Shared kernel for common types

Step 4: Extract modules to services when justified
```

```python
# Module boundary enforcement example
# project/modules/__init__.py

# Each module exposes ONLY its public API
# Direct imports of internal classes are forbidden

# orders/api.py (public)
from orders.service import OrderService

def create_order(user_id: str, items: list[dict]) -> Order:
    return OrderService().create(user_id, items)

def get_order(order_id: str) -> Order:
    return OrderService().get(order_id)

# orders/service.py (internal - do not import from outside)
class OrderService:
    def __init__(self):
        # Uses UserModule API, NOT direct DB access
        from users.api import get_user  # Module boundary
        self.get_user = get_user

    def create(self, user_id: str, items: list[dict]) -> Order:
        user = self.get_user(user_id)  # Through API, not direct query
        # ...
```

```python
# Architectural fitness function to enforce boundaries
# tests/test_architecture.py
import ast
import os

MODULES = ["users", "orders", "inventory", "payments", "notifications"]

def test_no_cross_module_internal_imports():
    """Ensure modules only import from other modules' api.py."""
    violations = []

    for module in MODULES:
        module_path = f"project/modules/{module}"
        for root, _, files in os.walk(module_path):
            for f in files:
                if not f.endswith(".py"):
                    continue
                filepath = os.path.join(root, f)
                tree = ast.parse(open(filepath).read())

                for node in ast.walk(tree):
                    if isinstance(node, (ast.Import, ast.ImportFrom)):
                        import_path = getattr(node, "module", "") or ""
                        for other in MODULES:
                            if other == module:
                                continue
                            # Only api imports allowed
                            if other in import_path and f"{other}.api" not in import_path:
                                violations.append(
                                    f"{filepath}: imports {import_path} (should use {other}.api)"
                                )

    assert not violations, f"Cross-module violations:\n" + "\n".join(violations)
```

**Anti-Pattern**: Extracting microservices before establishing clean module boundaries.

### Pattern 5: Database Schema Migration

**When to Use**: Evolving database schema alongside code changes

**Example**:
```sql
-- Expand-Contract pattern for zero-downtime schema migration

-- Phase 1: EXPAND - Add new column (backward compatible)
ALTER TABLE users ADD COLUMN full_name VARCHAR(255);

-- Phase 2: MIGRATE - Backfill data
UPDATE users SET full_name = first_name || ' ' || last_name
WHERE full_name IS NULL;

-- Phase 3: Code deploys using both old AND new columns
-- Application writes to both, reads from new

-- Phase 4: CONTRACT - Remove old columns (after all code uses new)
ALTER TABLE users DROP COLUMN first_name;
ALTER TABLE users DROP COLUMN last_name;
ALTER TABLE users ALTER COLUMN full_name SET NOT NULL;
```

**Anti-Pattern**: Destructive schema changes (DROP COLUMN) in the same deploy as code changes.

## Planning Large Refactoring

| Step | Action | Output |
|------|--------|--------|
| 1 | Map dependencies | Dependency graph |
| 2 | Identify seams | Natural boundaries |
| 3 | Write characterization tests | Safety net |
| 4 | Plan incremental steps | Migration roadmap |
| 5 | Execute step by step | Working software at each step |
| 6 | Measure progress | Metrics dashboard |

## Checklist

- [ ] Characterization tests written before starting
- [ ] Incremental migration plan documented
- [ ] Rollback strategy for each phase
- [ ] Feature flags for gradual traffic shifting
- [ ] Monitoring for behavior differences
- [ ] Team communication plan
- [ ] No big-bang rewrites
- [ ] Each step delivers working software
- [ ] Old code removed after migration complete
- [ ] Post-migration performance validation

## References

- Martin Fowler, "Strangler Fig Application" (2004)
- Sam Newman, "Monolith to Microservices" (2019)
- [Branch by Abstraction](https://www.branchbyabstraction.com/)
- Michael Feathers, "Working Effectively with Legacy Code" (2004)
