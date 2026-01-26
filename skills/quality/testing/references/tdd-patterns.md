---
title: TDD Patterns Reference
category: quality
type: reference
version: "1.0.0"
---

# Test-Driven Development Patterns

> Part of the quality/testing knowledge skill

## Overview

Test-Driven Development (TDD) is a software development approach where tests are written before the code they test. This reference covers the Red-Green-Refactor cycle, common TDD patterns, and strategies for different testing scenarios.

## 80/20 Quick Reference

**TDD Core Cycle:**

| Phase | Action | Goal |
|-------|--------|------|
| Red | Write failing test | Define expected behavior |
| Green | Write minimal code | Make test pass |
| Refactor | Improve code | Clean without changing behavior |

**TDD Patterns by Use Case:**

| Pattern | When to Use | Benefit |
|---------|-------------|---------|
| Arrange-Act-Assert | All unit tests | Clear structure |
| Given-When-Then | BDD-style tests | Business readable |
| Test Doubles | External dependencies | Isolation |
| Parameterized Tests | Multiple inputs | Coverage |
| Property-Based | Edge cases | Exhaustive testing |

## Patterns

### Pattern 1: Red-Green-Refactor Cycle

**When to Use**: Every TDD implementation

**Red Phase - Write Failing Test:**
```typescript
// Step 1: Write a test that fails
describe('Calculator', () => {
  it('should add two numbers', () => {
    const calculator = new Calculator();

    const result = calculator.add(2, 3);

    expect(result).toBe(5);
  });
});

// This fails because Calculator doesn't exist yet
```

**Green Phase - Make It Pass:**
```typescript
// Step 2: Write minimal code to pass
class Calculator {
  add(a: number, b: number): number {
    return a + b;
  }
}

// Test now passes
```

**Refactor Phase - Improve Code:**
```typescript
// Step 3: Refactor while keeping tests green
class Calculator {
  add(...numbers: number[]): number {
    return numbers.reduce((sum, n) => sum + n, 0);
  }
}

// Enhanced but tests still pass
```

**Anti-Pattern**: Writing production code before tests or skipping the refactor phase.

### Pattern 2: Arrange-Act-Assert (AAA)

**When to Use**: All unit tests for consistent structure

**Implementation:**
```typescript
describe('UserService', () => {
  it('should create a user with valid data', async () => {
    // Arrange - Set up test data and dependencies
    const repository = new InMemoryUserRepository();
    const service = new UserService(repository);
    const userData = {
      email: 'test@example.com',
      name: 'Test User'
    };

    // Act - Execute the behavior being tested
    const result = await service.createUser(userData);

    // Assert - Verify the expected outcome
    expect(result.id).toBeDefined();
    expect(result.email).toBe(userData.email);
    expect(result.name).toBe(userData.name);
    expect(await repository.findById(result.id)).toBeTruthy();
  });
});
```

**With Setup and Teardown:**
```typescript
describe('OrderService', () => {
  let repository: OrderRepository;
  let paymentGateway: MockPaymentGateway;
  let service: OrderService;

  // Shared Arrange for all tests
  beforeEach(() => {
    repository = new InMemoryOrderRepository();
    paymentGateway = new MockPaymentGateway();
    service = new OrderService(repository, paymentGateway);
  });

  afterEach(() => {
    repository.clear();
  });

  it('should process payment when order is placed', async () => {
    // Arrange - Test-specific setup
    const order = createTestOrder({ total: 100 });
    paymentGateway.willSucceed();

    // Act
    const result = await service.placeOrder(order);

    // Assert
    expect(result.status).toBe('CONFIRMED');
    expect(paymentGateway.chargedAmount).toBe(100);
  });

  it('should fail order when payment is declined', async () => {
    // Arrange
    const order = createTestOrder({ total: 100 });
    paymentGateway.willDecline();

    // Act
    const result = await service.placeOrder(order);

    // Assert
    expect(result.status).toBe('PAYMENT_FAILED');
    expect(await repository.findById(order.id)).toBeNull();
  });
});
```

**Anti-Pattern**: Mixing arrange, act, and assert steps or having multiple acts in one test.

### Pattern 3: Given-When-Then (BDD Style)

**When to Use**: Business logic tests, acceptance tests

**Implementation:**
```typescript
describe('ShoppingCart', () => {
  describe('given an empty cart', () => {
    let cart: ShoppingCart;

    beforeEach(() => {
      cart = new ShoppingCart();
    });

    describe('when adding a product', () => {
      beforeEach(() => {
        cart.add(new Product('SKU-001', 'Widget', 10.00));
      });

      it('then the cart should have one item', () => {
        expect(cart.itemCount).toBe(1);
      });

      it('then the total should equal the product price', () => {
        expect(cart.total).toBe(10.00);
      });
    });

    describe('when checking out', () => {
      it('then should throw EmptyCartError', () => {
        expect(() => cart.checkout()).toThrow(EmptyCartError);
      });
    });
  });

  describe('given a cart with items', () => {
    let cart: ShoppingCart;

    beforeEach(() => {
      cart = new ShoppingCart();
      cart.add(new Product('SKU-001', 'Widget', 10.00));
      cart.add(new Product('SKU-002', 'Gadget', 20.00));
    });

    describe('when applying a 10% discount', () => {
      beforeEach(() => {
        cart.applyDiscount(new PercentageDiscount(10));
      });

      it('then the total should be reduced by 10%', () => {
        expect(cart.total).toBe(27.00); // (10 + 20) * 0.9
      });
    });

    describe('when removing a product', () => {
      beforeEach(() => {
        cart.remove('SKU-001');
      });

      it('then the cart should have one less item', () => {
        expect(cart.itemCount).toBe(1);
      });

      it('then the total should be updated', () => {
        expect(cart.total).toBe(20.00);
      });
    });
  });
});
```

**Anti-Pattern**: Overly nested describes or unclear given/when/then transitions.

### Pattern 4: Test Doubles (Mocks, Stubs, Fakes)

**When to Use**: Isolating units from external dependencies

**Stub - Provides Canned Responses:**
```typescript
class StubPricingService implements PricingService {
  getPrice(productId: string): Promise<number> {
    // Always returns fixed price for testing
    return Promise.resolve(10.00);
  }
}

describe('OrderCalculator', () => {
  it('should calculate order total using prices', async () => {
    // Arrange
    const pricingService = new StubPricingService();
    const calculator = new OrderCalculator(pricingService);
    const items = [
      { productId: 'A', quantity: 2 },
      { productId: 'B', quantity: 3 }
    ];

    // Act
    const total = await calculator.calculateTotal(items);

    // Assert - 2*10 + 3*10 = 50
    expect(total).toBe(50.00);
  });
});
```

**Mock - Verifies Interactions:**
```typescript
describe('NotificationService', () => {
  it('should send email when user registers', async () => {
    // Arrange
    const emailSender = {
      send: jest.fn().mockResolvedValue(true)
    };
    const service = new NotificationService(emailSender);
    const user = { email: 'test@example.com', name: 'Test' };

    // Act
    await service.notifyRegistration(user);

    // Assert - Verify the interaction
    expect(emailSender.send).toHaveBeenCalledTimes(1);
    expect(emailSender.send).toHaveBeenCalledWith({
      to: 'test@example.com',
      subject: 'Welcome!',
      template: 'registration',
      data: { name: 'Test' }
    });
  });
});
```

**Fake - Working Implementation:**
```typescript
class FakeUserRepository implements UserRepository {
  private users: Map<string, User> = new Map();

  async save(user: User): Promise<void> {
    this.users.set(user.id, user);
  }

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null;
  }

  async findByEmail(email: string): Promise<User | null> {
    return Array.from(this.users.values())
      .find(u => u.email === email) || null;
  }

  // Test helper methods
  clear(): void {
    this.users.clear();
  }

  seed(users: User[]): void {
    users.forEach(u => this.users.set(u.id, u));
  }
}

describe('UserService', () => {
  it('should prevent duplicate email registration', async () => {
    // Arrange
    const repository = new FakeUserRepository();
    repository.seed([
      { id: '1', email: 'existing@example.com', name: 'Existing' }
    ]);
    const service = new UserService(repository);

    // Act & Assert
    await expect(
      service.register({ email: 'existing@example.com', name: 'New' })
    ).rejects.toThrow(DuplicateEmailError);
  });
});
```

**Anti-Pattern**: Over-mocking leading to tests that pass but don't catch real bugs.

### Pattern 5: Parameterized Tests

**When to Use**: Testing same behavior with different inputs

**Implementation:**
```typescript
describe('PasswordValidator', () => {
  const validator = new PasswordValidator();

  describe.each([
    { password: 'short', expected: false, reason: 'too short' },
    { password: 'nouppercase1!', expected: false, reason: 'no uppercase' },
    { password: 'NOLOWERCASE1!', expected: false, reason: 'no lowercase' },
    { password: 'NoNumbers!', expected: false, reason: 'no numbers' },
    { password: 'NoSpecial123', expected: false, reason: 'no special chars' },
    { password: 'Valid1Password!', expected: true, reason: 'valid' },
    { password: 'Another$ecure2', expected: true, reason: 'valid' }
  ])('validate("$password")', ({ password, expected, reason }) => {
    it(`should return ${expected} because ${reason}`, () => {
      expect(validator.validate(password)).toBe(expected);
    });
  });
});

describe('TaxCalculator', () => {
  const calculator = new TaxCalculator();

  it.each([
    [10000, 0],           // Below threshold
    [20000, 1000],        // 10% bracket
    [50000, 5000],        // 15% bracket
    [100000, 15000],      // 25% bracket
    [500000, 125000],     // 35% bracket
  ])('should calculate tax for income %i as %i', (income, expectedTax) => {
    expect(calculator.calculate(income)).toBe(expectedTax);
  });
});
```

**Table-Driven Tests (Go Style in TypeScript):**
```typescript
interface TestCase<TInput, TOutput> {
  name: string;
  input: TInput;
  expected: TOutput;
}

describe('StringUtils', () => {
  const cases: TestCase<string, string>[] = [
    { name: 'empty string', input: '', expected: '' },
    { name: 'single word', input: 'hello', expected: 'Hello' },
    { name: 'multiple words', input: 'hello world', expected: 'Hello World' },
    { name: 'already capitalized', input: 'Hello', expected: 'Hello' },
    { name: 'mixed case', input: 'hELLO wORLD', expected: 'Hello World' },
  ];

  cases.forEach(({ name, input, expected }) => {
    it(`titleCase: ${name}`, () => {
      expect(StringUtils.titleCase(input)).toBe(expected);
    });
  });
});
```

**Anti-Pattern**: Too many parameters making tests hard to understand.

### Pattern 6: Property-Based Testing

**When to Use**: Finding edge cases, testing invariants

**Implementation with fast-check:**
```typescript
import fc from 'fast-check';

describe('Array.sort', () => {
  it('should return array of same length', () => {
    fc.assert(
      fc.property(fc.array(fc.integer()), (arr) => {
        const sorted = [...arr].sort((a, b) => a - b);
        return sorted.length === arr.length;
      })
    );
  });

  it('should be idempotent', () => {
    fc.assert(
      fc.property(fc.array(fc.integer()), (arr) => {
        const sorted1 = [...arr].sort((a, b) => a - b);
        const sorted2 = [...sorted1].sort((a, b) => a - b);
        return JSON.stringify(sorted1) === JSON.stringify(sorted2);
      })
    );
  });

  it('should produce ordered elements', () => {
    fc.assert(
      fc.property(fc.array(fc.integer()), (arr) => {
        const sorted = [...arr].sort((a, b) => a - b);
        for (let i = 1; i < sorted.length; i++) {
          if (sorted[i] < sorted[i - 1]) return false;
        }
        return true;
      })
    );
  });
});

describe('encode/decode round-trip', () => {
  it('should decode what was encoded', () => {
    fc.assert(
      fc.property(fc.string(), (str) => {
        const encoded = base64Encode(str);
        const decoded = base64Decode(encoded);
        return decoded === str;
      })
    );
  });
});

describe('Money', () => {
  const moneyArb = fc.record({
    amount: fc.integer({ min: 0, max: 1000000 }),
    currency: fc.constantFrom('USD', 'EUR', 'GBP')
  });

  it('adding then subtracting should return original', () => {
    fc.assert(
      fc.property(moneyArb, moneyArb, (m1, m2) => {
        if (m1.currency !== m2.currency) return true; // Skip different currencies

        const result = Money.from(m1).add(m2).subtract(m2);
        return result.amount === m1.amount;
      })
    );
  });
});
```

**Anti-Pattern**: Using property-based tests where example-based tests are clearer.

### Pattern 7: Test Fixture Patterns

**When to Use**: Complex test setup, shared test data

**Builder Pattern for Test Data:**
```typescript
class UserBuilder {
  private user: Partial<User> = {
    id: 'default-id',
    email: 'default@example.com',
    name: 'Default User',
    role: 'user',
    createdAt: new Date()
  };

  withId(id: string): this {
    this.user.id = id;
    return this;
  }

  withEmail(email: string): this {
    this.user.email = email;
    return this;
  }

  withName(name: string): this {
    this.user.name = name;
    return this;
  }

  asAdmin(): this {
    this.user.role = 'admin';
    return this;
  }

  build(): User {
    return this.user as User;
  }
}

// Usage in tests
describe('AdminService', () => {
  it('should allow admin to delete users', async () => {
    const admin = new UserBuilder()
      .withId('admin-1')
      .asAdmin()
      .build();

    const regularUser = new UserBuilder()
      .withId('user-1')
      .build();

    const service = new AdminService(repository);
    await service.deleteUser(admin, regularUser.id);

    expect(await repository.findById(regularUser.id)).toBeNull();
  });
});
```

**Object Mother Pattern:**
```typescript
class TestUsers {
  static admin(): User {
    return {
      id: 'admin-1',
      email: 'admin@example.com',
      name: 'Admin User',
      role: 'admin',
      createdAt: new Date('2024-01-01')
    };
  }

  static regular(): User {
    return {
      id: 'user-1',
      email: 'user@example.com',
      name: 'Regular User',
      role: 'user',
      createdAt: new Date('2024-01-01')
    };
  }

  static withEmail(email: string): User {
    return { ...TestUsers.regular(), email };
  }
}

class TestOrders {
  static pending(overrides?: Partial<Order>): Order {
    return {
      id: 'order-1',
      userId: 'user-1',
      status: 'pending',
      items: [],
      total: 0,
      ...overrides
    };
  }

  static completed(overrides?: Partial<Order>): Order {
    return {
      ...TestOrders.pending(),
      status: 'completed',
      ...overrides
    };
  }
}
```

**Anti-Pattern**: Test data scattered across files or magic values without explanation.

### Pattern 8: Testing Asynchronous Code

**When to Use**: Promises, callbacks, events

**Implementation:**
```typescript
describe('AsyncUserService', () => {
  // Testing Promises
  it('should resolve with user data', async () => {
    const service = new UserService(mockRepository);

    const user = await service.findById('user-1');

    expect(user).toBeDefined();
    expect(user.id).toBe('user-1');
  });

  // Testing rejected promises
  it('should reject when user not found', async () => {
    const service = new UserService(mockRepository);

    await expect(service.findById('non-existent'))
      .rejects
      .toThrow(UserNotFoundError);
  });

  // Testing with timeouts
  it('should timeout if operation takes too long', async () => {
    const slowRepository = {
      findById: () => new Promise(resolve =>
        setTimeout(() => resolve(null), 5000)
      )
    };
    const service = new UserService(slowRepository);

    await expect(service.findByIdWithTimeout('user-1', 100))
      .rejects
      .toThrow(TimeoutError);
  }, 1000);

  // Testing event emitters
  it('should emit user.created event', (done) => {
    const service = new UserService(mockRepository);

    service.on('user.created', (user) => {
      expect(user.email).toBe('test@example.com');
      done();
    });

    service.createUser({ email: 'test@example.com', name: 'Test' });
  });

  // Testing with fake timers
  it('should retry failed operations', async () => {
    jest.useFakeTimers();

    const failThenSucceed = jest.fn()
      .mockRejectedValueOnce(new Error('fail'))
      .mockRejectedValueOnce(new Error('fail'))
      .mockResolvedValueOnce({ id: 'user-1' });

    const service = new RetryingUserService({
      findById: failThenSucceed
    });

    const promise = service.findByIdWithRetry('user-1');

    // Fast-forward through retries
    jest.advanceTimersByTime(2000);

    const result = await promise;
    expect(result.id).toBe('user-1');
    expect(failThenSucceed).toHaveBeenCalledTimes(3);

    jest.useRealTimers();
  });
});
```

**Anti-Pattern**: Not handling async properly leading to flaky tests.

## Checklist

- [ ] Tests written before production code
- [ ] Each test covers single behavior
- [ ] Tests are independent (no shared state)
- [ ] Clear Arrange-Act-Assert structure
- [ ] Test doubles used appropriately
- [ ] Edge cases covered with parameterized tests
- [ ] Async code tested properly
- [ ] Refactoring done with green tests
- [ ] Test names describe expected behavior
- [ ] No test logic (conditionals, loops)

## References

- [Test Driven Development by Kent Beck](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [Growing Object-Oriented Software, Guided by Tests](http://www.growing-object-oriented-software.com/)
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [fast-check Property-Based Testing](https://github.com/dubzzz/fast-check)
