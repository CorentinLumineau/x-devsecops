---
title: Clean Architecture Reference
category: meta
type: reference
version: "1.0.0"
---

# Clean Architecture

> Part of the meta/architecture-patterns knowledge skill

## Overview

Clean Architecture (Robert C. Martin) organizes code into concentric layers with a strict dependency rule: dependencies point inward. The inner layers contain business logic and are independent of frameworks, databases, and UI. This produces systems that are testable, maintainable, and adaptable to technology changes.

## Quick Reference (80/20)

| Layer | Contains | Depends On |
|-------|----------|-----------|
| Entities | Business objects, rules | Nothing |
| Use Cases | Application logic | Entities |
| Interface Adapters | Controllers, presenters, gateways | Use Cases, Entities |
| Frameworks | Web, DB, external services | Everything (outermost) |

## Patterns

### Pattern 1: Layer Structure

**When to Use**: Structuring any application with clean separation

**Example**:
```
project/
├── domain/                    # Entities layer (innermost)
│   ├── entities/
│   │   ├── user.py
│   │   ├── order.py
│   │   └── product.py
│   ├── value_objects/
│   │   ├── email.py
│   │   ├── money.py
│   │   └── address.py
│   └── exceptions.py
│
├── application/               # Use Cases layer
│   ├── use_cases/
│   │   ├── create_order.py
│   │   ├── cancel_order.py
│   │   └── get_order.py
│   ├── ports/                 # Interfaces (abstractions)
│   │   ├── order_repository.py
│   │   ├── payment_gateway.py
│   │   └── notification_service.py
│   └── dtos/
│       ├── order_request.py
│       └── order_response.py
│
├── adapters/                  # Interface Adapters layer
│   ├── api/
│   │   ├── order_controller.py
│   │   └── serializers.py
│   ├── persistence/
│   │   ├── sqlalchemy_order_repo.py
│   │   └── models.py
│   └── external/
│       ├── stripe_payment.py
│       └── sendgrid_notification.py
│
└── infrastructure/            # Frameworks layer (outermost)
    ├── web/
    │   ├── app.py             # FastAPI/Flask setup
    │   └── middleware.py
    ├── database/
    │   ├── connection.py
    │   └── migrations/
    └── config.py
```

**Anti-Pattern**: Domain layer importing from infrastructure (violates dependency rule).

### Pattern 2: Dependency Inversion with Ports and Adapters

**When to Use**: Decoupling business logic from infrastructure

**Example**:
```python
# domain/entities/order.py - Entity (no external dependencies)
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum

class OrderStatus(Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    CANCELLED = "cancelled"

@dataclass
class OrderItem:
    product_id: str
    quantity: int
    unit_price: float

    @property
    def total(self) -> float:
        return self.quantity * self.unit_price

@dataclass
class Order:
    id: str
    customer_id: str
    items: list[OrderItem] = field(default_factory=list)
    status: OrderStatus = OrderStatus.PENDING
    created_at: datetime = field(default_factory=datetime.utcnow)

    @property
    def total_amount(self) -> float:
        return sum(item.total for item in self.items)

    def confirm(self):
        if self.status != OrderStatus.PENDING:
            raise ValueError(f"Cannot confirm order in {self.status} state")
        self.status = OrderStatus.CONFIRMED

    def cancel(self):
        if self.status == OrderStatus.SHIPPED:
            raise ValueError("Cannot cancel shipped order")
        self.status = OrderStatus.CANCELLED
```

```python
# application/ports/order_repository.py - Port (interface)
from abc import ABC, abstractmethod
from domain.entities.order import Order

class OrderRepository(ABC):
    @abstractmethod
    async def save(self, order: Order) -> None: ...

    @abstractmethod
    async def find_by_id(self, order_id: str) -> Order | None: ...

    @abstractmethod
    async def find_by_customer(self, customer_id: str) -> list[Order]: ...
```

```python
# application/use_cases/create_order.py - Use Case
from dataclasses import dataclass
from application.ports.order_repository import OrderRepository
from application.ports.payment_gateway import PaymentGateway
from application.ports.notification_service import NotificationService
from domain.entities.order import Order, OrderItem
import uuid

@dataclass
class CreateOrderRequest:
    customer_id: str
    items: list[dict]  # [{product_id, quantity, unit_price}]

@dataclass
class CreateOrderResponse:
    order_id: str
    total_amount: float
    status: str

class CreateOrderUseCase:
    def __init__(
        self,
        order_repo: OrderRepository,
        payment: PaymentGateway,
        notifications: NotificationService,
    ):
        self.order_repo = order_repo
        self.payment = payment
        self.notifications = notifications

    async def execute(self, request: CreateOrderRequest) -> CreateOrderResponse:
        # Create domain entity
        order = Order(
            id=str(uuid.uuid4()),
            customer_id=request.customer_id,
            items=[
                OrderItem(
                    product_id=i["product_id"],
                    quantity=i["quantity"],
                    unit_price=i["unit_price"],
                )
                for i in request.items
            ],
        )

        # Process payment
        payment_ok = await self.payment.charge(
            customer_id=order.customer_id,
            amount=order.total_amount,
        )

        if not payment_ok:
            raise PaymentFailedError(order.id)

        order.confirm()
        await self.order_repo.save(order)

        # Notify (fire-and-forget)
        await self.notifications.send(
            to=order.customer_id,
            message=f"Order {order.id} confirmed: ${order.total_amount:.2f}",
        )

        return CreateOrderResponse(
            order_id=order.id,
            total_amount=order.total_amount,
            status=order.status.value,
        )
```

```python
# adapters/persistence/sqlalchemy_order_repo.py - Adapter (implementation)
from application.ports.order_repository import OrderRepository
from domain.entities.order import Order, OrderItem, OrderStatus
from sqlalchemy.ext.asyncio import AsyncSession

class SQLAlchemyOrderRepository(OrderRepository):
    def __init__(self, session: AsyncSession):
        self.session = session

    async def save(self, order: Order) -> None:
        model = OrderModel(
            id=order.id,
            customer_id=order.customer_id,
            status=order.status.value,
            created_at=order.created_at,
        )
        model.items = [
            OrderItemModel(
                product_id=item.product_id,
                quantity=item.quantity,
                unit_price=item.unit_price,
            )
            for item in order.items
        ]
        self.session.add(model)
        await self.session.commit()

    async def find_by_id(self, order_id: str) -> Order | None:
        model = await self.session.get(OrderModel, order_id)
        if not model:
            return None
        return self._to_entity(model)

    async def find_by_customer(self, customer_id: str) -> list[Order]:
        result = await self.session.execute(
            select(OrderModel).where(OrderModel.customer_id == customer_id)
        )
        return [self._to_entity(m) for m in result.scalars()]

    def _to_entity(self, model: OrderModel) -> Order:
        return Order(
            id=model.id,
            customer_id=model.customer_id,
            items=[
                OrderItem(
                    product_id=i.product_id,
                    quantity=i.quantity,
                    unit_price=i.unit_price,
                )
                for i in model.items
            ],
            status=OrderStatus(model.status),
            created_at=model.created_at,
        )
```

**Anti-Pattern**: Use cases directly importing SQLAlchemy, requests, or any framework.

### Pattern 3: Dependency Injection Composition Root

**When to Use**: Wiring everything together at application startup

**Example**:
```python
# infrastructure/web/app.py - Composition root
from fastapi import FastAPI, Depends
from infrastructure.database.connection import get_session
from adapters.persistence.sqlalchemy_order_repo import SQLAlchemyOrderRepository
from adapters.external.stripe_payment import StripePaymentGateway
from adapters.external.sendgrid_notification import SendGridNotificationService
from application.use_cases.create_order import CreateOrderUseCase, CreateOrderRequest

app = FastAPI()

# Factory functions for dependency injection
def get_create_order_use_case(session=Depends(get_session)):
    return CreateOrderUseCase(
        order_repo=SQLAlchemyOrderRepository(session),
        payment=StripePaymentGateway(api_key=config.STRIPE_KEY),
        notifications=SendGridNotificationService(api_key=config.SENDGRID_KEY),
    )

@app.post("/api/orders")
async def create_order(
    request: CreateOrderRequest,
    use_case: CreateOrderUseCase = Depends(get_create_order_use_case),
):
    result = await use_case.execute(request)
    return {"order_id": result.order_id, "total": result.total_amount}
```

**Anti-Pattern**: Instantiating dependencies inside use cases (makes testing impossible without mocks).

### Pattern 4: Testing Clean Architecture

**When to Use**: Testing each layer in isolation

**Example**:
```python
# tests/unit/test_order_entity.py - Domain tests (no mocks needed)
def test_order_total():
    order = Order(
        id="1",
        customer_id="cust_1",
        items=[
            OrderItem(product_id="p1", quantity=2, unit_price=10.0),
            OrderItem(product_id="p2", quantity=1, unit_price=25.0),
        ],
    )
    assert order.total_amount == 45.0

def test_cannot_cancel_shipped_order():
    order = Order(id="1", customer_id="c1", status=OrderStatus.SHIPPED)
    with pytest.raises(ValueError, match="Cannot cancel shipped"):
        order.cancel()


# tests/unit/test_create_order.py - Use case tests (with fakes)
class FakeOrderRepo(OrderRepository):
    def __init__(self):
        self.orders = {}

    async def save(self, order):
        self.orders[order.id] = order

    async def find_by_id(self, order_id):
        return self.orders.get(order_id)

    async def find_by_customer(self, customer_id):
        return [o for o in self.orders.values() if o.customer_id == customer_id]

class FakePayment(PaymentGateway):
    def __init__(self, should_succeed=True):
        self.should_succeed = should_succeed

    async def charge(self, customer_id, amount):
        return self.should_succeed

class FakeNotifications(NotificationService):
    def __init__(self):
        self.sent = []

    async def send(self, to, message):
        self.sent.append((to, message))

async def test_create_order_success():
    repo = FakeOrderRepo()
    payment = FakePayment(should_succeed=True)
    notifications = FakeNotifications()

    use_case = CreateOrderUseCase(repo, payment, notifications)
    result = await use_case.execute(CreateOrderRequest(
        customer_id="cust_1",
        items=[{"product_id": "p1", "quantity": 2, "unit_price": 10.0}],
    ))

    assert result.status == "confirmed"
    assert result.total_amount == 20.0
    assert len(repo.orders) == 1
    assert len(notifications.sent) == 1

async def test_create_order_payment_fails():
    repo = FakeOrderRepo()
    payment = FakePayment(should_succeed=False)
    notifications = FakeNotifications()

    use_case = CreateOrderUseCase(repo, payment, notifications)
    with pytest.raises(PaymentFailedError):
        await use_case.execute(CreateOrderRequest(
            customer_id="cust_1",
            items=[{"product_id": "p1", "quantity": 1, "unit_price": 50.0}],
        ))

    assert len(repo.orders) == 0
    assert len(notifications.sent) == 0
```

**Anti-Pattern**: Using mocks for domain entities or overusing mocks when fakes are simpler.

### Pattern 5: Hexagonal Architecture Variant

**When to Use**: Emphasizing ports (driving and driven)

**Example**:
```
                    Driving Side                    Driven Side
                 (Primary/Input)                (Secondary/Output)
                       │                               │
        ┌──────────────┼───────────────┐ ┌─────────────┼──────────────┐
        │              │               │ │             │              │
   ┌────▼────┐   ┌─────▼─────┐        │ │      ┌──────▼──────┐      │
   │  REST   │   │  GraphQL  │        │ │      │  PostgreSQL │      │
   │ Adapter │   │  Adapter  │        │ │      │   Adapter   │      │
   └────┬────┘   └─────┬─────┘        │ │      └──────┬──────┘      │
        │              │               │ │             │              │
   ┌────▼──────────────▼────┐          │ │    ┌────────▼────────┐    │
   │     Input Ports        │          │ │    │  Output Ports   │    │
   │  (Use Case interfaces) │──────────┼─┼───▶│  (Repository,  │    │
   │                        │          │ │    │   Gateway)      │    │
   └───────────┬────────────┘          │ │    └────────┬────────┘    │
               │                       │ │             │             │
        ┌──────▼──────┐                │ │      ┌──────▼──────┐     │
        │   Domain    │                │ │      │   Stripe    │     │
        │   (Core)    │                │ │      │   Adapter   │     │
        └─────────────┘                │ │      └─────────────┘     │
        └──────────────────────────────┘ └──────────────────────────┘
```

**Key distinction from Clean Architecture**: Hexagonal explicitly names "driving" ports (used by external actors to invoke the application) and "driven" ports (used by the application to reach external systems). Clean Architecture focuses on concentric layers. In practice they are very similar.

**Anti-Pattern**: Letting adapters contain business logic instead of delegating to ports/use cases.

## Dependency Rule Summary

```
ALLOWED:
  infrastructure → adapters → application → domain
  (outer)                                   (inner)

FORBIDDEN:
  domain → application (domain knows nothing about use cases)
  domain → adapters    (domain knows nothing about DB/API)
  domain → infrastructure
  application → adapters
  application → infrastructure
```

## Checklist

- [ ] Domain entities have zero framework imports
- [ ] Use cases depend only on ports (interfaces)
- [ ] Adapters implement ports
- [ ] Composition root wires dependencies
- [ ] Domain tests need no mocks
- [ ] Use case tests use fakes, not framework
- [ ] No business logic in controllers or adapters
- [ ] Dependency rule never violated

## References

- Robert C. Martin, "Clean Architecture" (2017)
- Alistair Cockburn, "Hexagonal Architecture" (2005)
- [The Clean Architecture Blog Post](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
