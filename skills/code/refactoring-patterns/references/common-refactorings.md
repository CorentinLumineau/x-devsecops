---
title: Common Refactorings Reference
category: code
type: reference
version: "1.0.0"
---

# Common Refactorings

> Part of the code/refactoring-patterns knowledge skill

## Overview

This reference covers the most frequently used refactorings from Fowler's catalog. Each pattern includes before/after examples and mechanical steps for safe application.

## Quick Reference (80/20)

| Refactoring | Input | Output |
|-------------|-------|--------|
| Extract Method | Long method | Short method + helper |
| Extract Class | Fat class | Two focused classes |
| Move Method | Method in wrong class | Method in right class |
| Rename | Unclear name | Intent-revealing name |
| Replace Temp with Query | Local variable | Method call |
| Introduce Parameter Object | Many params | Single object param |

## Patterns

### Pattern 1: Extract Method

**When to Use**: Method is too long, or a code fragment needs a comment to explain it

**Before**:
```python
def print_invoice(invoice):
    print("=" * 40)
    print(f"Invoice #{invoice.number}")
    print(f"Date: {invoice.date}")
    print("-" * 40)

    total = 0
    for item in invoice.items:
        item_total = item.quantity * item.price
        if item.discount > 0:
            item_total -= item_total * item.discount / 100
        total += item_total
        print(f"  {item.name}: ${item_total:.2f}")

    tax = total * 0.08
    grand_total = total + tax
    print("-" * 40)
    print(f"  Subtotal: ${total:.2f}")
    print(f"  Tax (8%): ${tax:.2f}")
    print(f"  Total:    ${grand_total:.2f}")
    print("=" * 40)
```

**After**:
```python
def print_invoice(invoice):
    print_header(invoice)
    total = print_line_items(invoice.items)
    print_totals(total)

def print_header(invoice):
    print("=" * 40)
    print(f"Invoice #{invoice.number}")
    print(f"Date: {invoice.date}")
    print("-" * 40)

def print_line_items(items) -> float:
    total = 0
    for item in items:
        item_total = calculate_item_total(item)
        total += item_total
        print(f"  {item.name}: ${item_total:.2f}")
    return total

def calculate_item_total(item) -> float:
    item_total = item.quantity * item.price
    if item.discount > 0:
        item_total -= item_total * item.discount / 100
    return item_total

def print_totals(subtotal: float):
    tax = subtotal * 0.08
    grand_total = subtotal + tax
    print("-" * 40)
    print(f"  Subtotal: ${subtotal:.2f}")
    print(f"  Tax (8%): ${tax:.2f}")
    print(f"  Total:    ${grand_total:.2f}")
    print("=" * 40)
```

**Mechanical Steps**:
1. Create a new method with a name that says WHAT, not HOW
2. Copy the extracted code to the new method
3. Identify local variables used - pass as parameters
4. Identify local variables modified - return them
5. Replace original code with method call
6. Run tests

**Anti-Pattern**: Extracting methods that have no meaningful name (e.g., `doStep1`).

### Pattern 2: Extract Class

**When to Use**: A class has too many responsibilities

**Before**:
```typescript
class User {
  name: string;
  email: string;
  street: string;
  city: string;
  state: string;
  zip: string;
  phone: string;
  phoneType: string;

  getFullAddress(): string {
    return `${this.street}, ${this.city}, ${this.state} ${this.zip}`;
  }

  getFormattedPhone(): string {
    return `(${this.phone.slice(0,3)}) ${this.phone.slice(3,6)}-${this.phone.slice(6)}`;
  }

  validateEmail(): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email);
  }

  validatePhone(): boolean {
    return /^\d{10}$/.test(this.phone);
  }

  validateAddress(): boolean {
    return !!(this.street && this.city && this.state && this.zip);
  }
}
```

**After**:
```typescript
class User {
  name: string;
  email: string;
  address: Address;
  phone: PhoneNumber;

  validateEmail(): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email);
  }
}

class Address {
  street: string;
  city: string;
  state: string;
  zip: string;

  getFullAddress(): string {
    return `${this.street}, ${this.city}, ${this.state} ${this.zip}`;
  }

  validate(): boolean {
    return !!(this.street && this.city && this.state && this.zip);
  }
}

class PhoneNumber {
  number: string;
  type: string;

  getFormatted(): string {
    return `(${this.number.slice(0,3)}) ${this.number.slice(3,6)}-${this.number.slice(6)}`;
  }

  validate(): boolean {
    return /^\d{10}$/.test(this.number);
  }
}
```

**Anti-Pattern**: Extracting classes with circular dependencies on the original.

### Pattern 3: Replace Conditional with Polymorphism

**When to Use**: Switch/if chains that select behavior based on type

**Before**:
```python
class Shape:
    def __init__(self, shape_type: str, **kwargs):
        self.shape_type = shape_type
        self.kwargs = kwargs

    def area(self) -> float:
        if self.shape_type == "circle":
            return 3.14159 * self.kwargs["radius"] ** 2
        elif self.shape_type == "rectangle":
            return self.kwargs["width"] * self.kwargs["height"]
        elif self.shape_type == "triangle":
            return 0.5 * self.kwargs["base"] * self.kwargs["height"]
        else:
            raise ValueError(f"Unknown shape: {self.shape_type}")

    def perimeter(self) -> float:
        if self.shape_type == "circle":
            return 2 * 3.14159 * self.kwargs["radius"]
        elif self.shape_type == "rectangle":
            return 2 * (self.kwargs["width"] + self.kwargs["height"])
        elif self.shape_type == "triangle":
            return self.kwargs["a"] + self.kwargs["b"] + self.kwargs["c"]
        else:
            raise ValueError(f"Unknown shape: {self.shape_type}")
```

**After**:
```python
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self) -> float: ...

    @abstractmethod
    def perimeter(self) -> float: ...

class Circle(Shape):
    def __init__(self, radius: float):
        self.radius = radius

    def area(self) -> float:
        return 3.14159 * self.radius ** 2

    def perimeter(self) -> float:
        return 2 * 3.14159 * self.radius

class Rectangle(Shape):
    def __init__(self, width: float, height: float):
        self.width = width
        self.height = height

    def area(self) -> float:
        return self.width * self.height

    def perimeter(self) -> float:
        return 2 * (self.width + self.height)

class Triangle(Shape):
    def __init__(self, base: float, height: float, a: float, b: float, c: float):
        self.base = base
        self.height = height
        self.sides = (a, b, c)

    def area(self) -> float:
        return 0.5 * self.base * self.height

    def perimeter(self) -> float:
        return sum(self.sides)
```

**Anti-Pattern**: Over-applying polymorphism to simple conditionals with only 2 branches.

### Pattern 4: Introduce Parameter Object

**When to Use**: Multiple methods share the same group of parameters

**Before**:
```typescript
function searchProducts(
  query: string,
  minPrice: number,
  maxPrice: number,
  category: string,
  sortBy: string,
  sortOrder: string,
  page: number,
  pageSize: number
): Product[] { /* ... */ }

function countProducts(
  query: string,
  minPrice: number,
  maxPrice: number,
  category: string
): number { /* ... */ }
```

**After**:
```typescript
interface SearchCriteria {
  query: string;
  minPrice: number;
  maxPrice: number;
  category: string;
}

interface PaginationOptions {
  sortBy: string;
  sortOrder: "asc" | "desc";
  page: number;
  pageSize: number;
}

function searchProducts(criteria: SearchCriteria, pagination: PaginationOptions): Product[] {
  /* ... */
}

function countProducts(criteria: SearchCriteria): number {
  /* ... */
}
```

**Anti-Pattern**: Creating parameter objects that are only used by one method.

### Pattern 5: Replace Magic Number with Named Constant

**When to Use**: Literals in code whose meaning is not obvious

**Before**:
```python
def calculate_shipping(weight: float, distance: float) -> float:
    if weight > 50:
        return distance * 0.15 + 25.0
    elif weight > 20:
        return distance * 0.10 + 15.0
    else:
        return distance * 0.05 + 5.0

def is_eligible_for_discount(order_total: float) -> bool:
    return order_total >= 100.0
```

**After**:
```python
HEAVY_WEIGHT_THRESHOLD = 50  # kg
MEDIUM_WEIGHT_THRESHOLD = 20  # kg

HEAVY_RATE_PER_KM = 0.15
MEDIUM_RATE_PER_KM = 0.10
LIGHT_RATE_PER_KM = 0.05

HEAVY_BASE_FEE = 25.0
MEDIUM_BASE_FEE = 15.0
LIGHT_BASE_FEE = 5.0

DISCOUNT_MINIMUM_ORDER = 100.0

def calculate_shipping(weight: float, distance: float) -> float:
    if weight > HEAVY_WEIGHT_THRESHOLD:
        return distance * HEAVY_RATE_PER_KM + HEAVY_BASE_FEE
    elif weight > MEDIUM_WEIGHT_THRESHOLD:
        return distance * MEDIUM_RATE_PER_KM + MEDIUM_BASE_FEE
    else:
        return distance * LIGHT_RATE_PER_KM + LIGHT_BASE_FEE

def is_eligible_for_discount(order_total: float) -> bool:
    return order_total >= DISCOUNT_MINIMUM_ORDER
```

**Anti-Pattern**: Naming constants after values (`FIFTY = 50`) instead of meaning.

## Checklist

- [ ] Tests pass before and after each refactoring
- [ ] One refactoring per commit
- [ ] IDE automated refactoring used when available
- [ ] No behavior changes in refactoring commits
- [ ] Names reveal intent
- [ ] Methods fit on one screen (~20 lines)
- [ ] Classes have single responsibility
- [ ] Parameter lists under 4 parameters

## References

- Martin Fowler, "Refactoring: Improving the Design of Existing Code" (2nd ed.)
- [Refactoring Guru](https://refactoring.guru/refactoring)
- [SourceMaking - Refactoring](https://sourcemaking.com/refactoring)
