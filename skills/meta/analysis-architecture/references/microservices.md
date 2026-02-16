---
title: Microservices Reference
category: meta
type: reference
version: "1.0.0"
---

# Microservices

> Part of the meta/architecture-patterns knowledge skill

## Overview

Microservices architecture decomposes a system into independently deployable services, each owning its data and business logic. This reference covers decomposition strategies, communication patterns, and operational concerns.

## Quick Reference (80/20)

| Principle | Description |
|-----------|-------------|
| Single Responsibility | One service = one business capability |
| Autonomous | Independent deployment and data |
| Resilient | Failure in one service does not cascade |
| Observable | Every service emits metrics, logs, traces |
| Evolutionary | Services can be replaced independently |

## Patterns

### Pattern 1: Service Decomposition

**When to Use**: Breaking a monolith into services

**Example**:
```
Decomposition by Business Capability:

E-Commerce Domain
├── User Service          → Registration, authentication, profiles
├── Product Catalog       → Product info, categories, search
├── Inventory Service     → Stock levels, reservations
├── Order Service         → Order lifecycle, fulfillment
├── Payment Service       → Payment processing, refunds
├── Notification Service  → Email, SMS, push notifications
└── Analytics Service     → Reporting, dashboards

Each service:
- Owns its database (no shared DB)
- Exposes API (REST/gRPC)
- Publishes domain events
- Has independent CI/CD pipeline
```

```yaml
# Service boundary definition
# service-catalog.yaml
services:
  order-service:
    owner: orders-team
    bounded_context: ordering
    api:
      type: REST
      spec: ./api/order-api.yaml
    database:
      type: PostgreSQL
      name: orders_db
    events:
      publishes:
        - OrderCreated
        - OrderShipped
        - OrderCancelled
      subscribes:
        - PaymentCompleted
        - InventoryReserved
    dependencies:
      sync:
        - product-catalog  # Reads product info
      async:
        - payment-service  # Via events
        - inventory-service  # Via events
        - notification-service  # Via events
    slos:
      availability: 99.95%
      latency_p99: 500ms
```

**Anti-Pattern**: Decomposing by technical layer (UI service, DB service) instead of business capability.

### Pattern 2: Inter-Service Communication

**When to Use**: Choosing how services communicate

**Example**:
```
Synchronous (Request/Response):
┌──────────┐  HTTP/gRPC  ┌──────────────┐
│  Order   │────────────▶│   Product    │
│  Service │◀────────────│   Catalog    │
└──────────┘             └──────────────┘
Use for: Queries, real-time data needs

Asynchronous (Event-Driven):
┌──────────┐  Event  ┌─────────────┐  Event  ┌──────────────┐
│  Order   │────────▶│  Message    │────────▶│  Inventory   │
│  Service │         │  Broker     │────────▶│  Notification│
└──────────┘         └─────────────┘         └──────────────┘
Use for: Commands, eventual consistency, decoupling
```

```python
# API Gateway pattern - single entry point
# gateway.py
from fastapi import FastAPI, Request
import httpx

app = FastAPI()

SERVICE_REGISTRY = {
    "users": "http://user-service:8080",
    "products": "http://product-service:8080",
    "orders": "http://order-service:8080",
}

@app.api_route("/api/{service}/{path:path}", methods=["GET", "POST", "PUT", "DELETE"])
async def route(request: Request, service: str, path: str):
    base_url = SERVICE_REGISTRY.get(service)
    if not base_url:
        return {"error": "Service not found"}, 404

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.request(
            method=request.method,
            url=f"{base_url}/{path}",
            headers={k: v for k, v in request.headers.items()
                     if k.lower() not in ("host",)},
            content=await request.body(),
            params=request.query_params,
        )

    return Response(
        content=response.content,
        status_code=response.status_code,
        media_type=response.headers.get("content-type"),
    )
```

**Anti-Pattern**: Synchronous chains of 5+ service calls creating latency and coupling.

### Pattern 3: Data Management

**When to Use**: Handling data ownership and consistency across services

**Example**:
```
Database per Service:
┌────────────┐    ┌────────────┐    ┌────────────┐
│   Order    │    │  Product   │    │   User     │
│   Service  │    │   Service  │    │   Service  │
└─────┬──────┘    └─────┬──────┘    └─────┬──────┘
      │                 │                 │
┌─────▼──────┐    ┌─────▼──────┐    ┌─────▼──────┐
│  orders_db │    │products_db │    │  users_db  │
│ PostgreSQL │    │   Elastic  │    │ PostgreSQL │
└────────────┘    └────────────┘    └────────────┘

Each service chooses its own DB technology (polyglot persistence)
```

```python
# Saga pattern for distributed transactions
# order_saga.py
from enum import Enum
from dataclasses import dataclass

class SagaState(Enum):
    STARTED = "started"
    INVENTORY_RESERVED = "inventory_reserved"
    PAYMENT_PROCESSED = "payment_processed"
    COMPLETED = "completed"
    COMPENSATING = "compensating"
    FAILED = "failed"

@dataclass
class OrderSaga:
    order_id: str
    state: SagaState = SagaState.STARTED
    steps_completed: list = None

    def __post_init__(self):
        self.steps_completed = []

    async def execute(self):
        try:
            # Step 1: Reserve inventory
            await self._reserve_inventory()
            self.state = SagaState.INVENTORY_RESERVED
            self.steps_completed.append("inventory")

            # Step 2: Process payment
            await self._process_payment()
            self.state = SagaState.PAYMENT_PROCESSED
            self.steps_completed.append("payment")

            # Step 3: Confirm order
            await self._confirm_order()
            self.state = SagaState.COMPLETED

        except Exception as e:
            self.state = SagaState.COMPENSATING
            await self._compensate()
            self.state = SagaState.FAILED
            raise

    async def _compensate(self):
        """Undo completed steps in reverse order."""
        for step in reversed(self.steps_completed):
            if step == "payment":
                await self._refund_payment()
            elif step == "inventory":
                await self._release_inventory()
```

**Anti-Pattern**: Shared database between microservices (defeats the purpose).

### Pattern 4: Service Mesh

**When to Use**: Managing cross-cutting concerns (mTLS, retries, observability)

**Example**:
```yaml
# Istio VirtualService - traffic management
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts:
    - order-service
  http:
    - route:
        - destination:
            host: order-service
            subset: v2
          weight: 90
        - destination:
            host: order-service
            subset: v1
          weight: 10
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: 5xx,connect-failure
      timeout: 10s
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: order-service
spec:
  host: order-service
  trafficPolicy:
    connectionPool:
      http:
        h2UpgradePolicy: DEFAULT
        maxRequestsPerConnection: 100
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 60s
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

**Anti-Pattern**: Implementing retry, circuit breaking, and mTLS in every service instead of using infrastructure.

### Pattern 5: Testing Microservices

**When to Use**: Ensuring service correctness in isolation and integration

**Example**:
```python
# Contract testing with Pact
# test_order_consumer.py
import pytest
from pact import Consumer, Provider

@pytest.fixture
def pact():
    pact = Consumer('OrderService').has_pact_with(
        Provider('ProductService'),
        pact_dir='./pacts',
    )
    pact.start_service()
    yield pact
    pact.stop_service()
    pact.verify()

def test_get_product(pact):
    expected = {
        "id": "prod_001",
        "name": "Widget",
        "price": 29.99,
    }

    (pact
     .given("product prod_001 exists")
     .upon_receiving("a request for product prod_001")
     .with_request("GET", "/api/products/prod_001")
     .will_respond_with(200, body=expected))

    # Test using the pact mock
    result = product_client.get_product("prod_001")
    assert result["name"] == "Widget"
```

**Anti-Pattern**: Only unit testing services without contract or integration tests.

## Checklist

- [ ] Services aligned with business capabilities
- [ ] Each service owns its data
- [ ] API contracts defined and versioned
- [ ] Async communication for commands
- [ ] Saga/compensation for distributed transactions
- [ ] Contract tests between services
- [ ] Service mesh for cross-cutting concerns
- [ ] Centralized logging and tracing
- [ ] Independent CI/CD per service
- [ ] Runbooks per service

## References

- Sam Newman, "Building Microservices" (2nd ed., 2021)
- Chris Richardson, "Microservices Patterns" (2018)
- [microservices.io](https://microservices.io/)
