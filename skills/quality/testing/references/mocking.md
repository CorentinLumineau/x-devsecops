---
title: Mocking Patterns Reference
category: quality
type: reference
version: "1.0.0"
---

# Mocking Patterns

> Part of the quality/testing knowledge skill

## Overview

Mocking allows isolation of the unit under test by replacing dependencies with controlled substitutes. This reference covers test doubles (mocks, stubs, spies, fakes), when to use each, and patterns for effective mocking.

## 80/20 Quick Reference

**Test Double Types:**

| Type | Purpose | Verifies Behavior? |
|------|---------|-------------------|
| Stub | Return canned values | No |
| Mock | Verify interactions | Yes |
| Spy | Record calls, use real impl | Yes |
| Fake | Working simplified impl | No |
| Dummy | Fill parameter slots | No |

**Mocking Decision Matrix:**

| Scenario | Recommended Double |
|----------|-------------------|
| External API calls | Stub/Mock |
| Database access | Fake (in-memory) |
| Time-dependent code | Stub (fake timers) |
| Event verification | Mock/Spy |
| Complex collaborator | Fake |
| Unused parameter | Dummy |

## Patterns

### Pattern 1: Stubs - Controlling Indirect Inputs

**When to Use**: Isolating from external dependencies, controlling test scenarios

**Basic Stub Implementation:**
```typescript
// Interface to stub
interface PricingService {
  getPrice(productId: string): Promise<number>;
  getDiscount(customerId: string): Promise<number>;
}

// Stub with canned values
class StubPricingService implements PricingService {
  private prices: Map<string, number> = new Map();
  private discounts: Map<string, number> = new Map();

  // Setup methods for tests
  setPrice(productId: string, price: number): void {
    this.prices.set(productId, price);
  }

  setDiscount(customerId: string, discount: number): void {
    this.discounts.set(customerId, discount);
  }

  // Interface implementation
  async getPrice(productId: string): Promise<number> {
    return this.prices.get(productId) ?? 0;
  }

  async getDiscount(customerId: string): Promise<number> {
    return this.discounts.get(customerId) ?? 0;
  }
}

// Usage in tests
describe('OrderService', () => {
  it('should calculate total with product prices', async () => {
    // Arrange
    const pricingService = new StubPricingService();
    pricingService.setPrice('PROD-001', 100);
    pricingService.setPrice('PROD-002', 50);

    const orderService = new OrderService(pricingService);
    const items = [
      { productId: 'PROD-001', quantity: 2 },
      { productId: 'PROD-002', quantity: 3 }
    ];

    // Act
    const total = await orderService.calculateTotal(items);

    // Assert
    expect(total).toBe(350); // (100*2) + (50*3)
  });

  it('should apply customer discount', async () => {
    // Arrange
    const pricingService = new StubPricingService();
    pricingService.setPrice('PROD-001', 100);
    pricingService.setDiscount('CUSTOMER-VIP', 0.1);

    const orderService = new OrderService(pricingService);

    // Act
    const total = await orderService.calculateTotalWithDiscount(
      [{ productId: 'PROD-001', quantity: 1 }],
      'CUSTOMER-VIP'
    );

    // Assert
    expect(total).toBe(90); // 100 * (1 - 0.1)
  });
});
```

**Jest Stub Patterns:**
```typescript
describe('UserService', () => {
  // Stub with jest.fn()
  it('should use stubbed repository', async () => {
    const repository = {
      findById: jest.fn().mockResolvedValue({
        id: 'user-1',
        name: 'Test User',
        email: 'test@example.com'
      }),
      save: jest.fn().mockResolvedValue(undefined)
    };

    const service = new UserService(repository);
    const user = await service.getUser('user-1');

    expect(user.name).toBe('Test User');
  });

  // Stub with different return values
  it('should handle sequential calls', async () => {
    const api = {
      fetch: jest.fn()
        .mockResolvedValueOnce({ status: 'pending' })
        .mockResolvedValueOnce({ status: 'processing' })
        .mockResolvedValueOnce({ status: 'complete' })
    };

    const service = new PollingService(api);
    const result = await service.waitForCompletion('job-1');

    expect(result.status).toBe('complete');
    expect(api.fetch).toHaveBeenCalledTimes(3);
  });

  // Stub with implementation
  it('should use custom stub implementation', async () => {
    const cache = {
      get: jest.fn().mockImplementation((key: string) => {
        if (key === 'cached-user') {
          return Promise.resolve({ id: 'cached', name: 'Cached User' });
        }
        return Promise.resolve(null);
      })
    };

    const service = new CachingUserService(cache, repository);

    const cachedUser = await service.getUser('cached-user');
    expect(cachedUser.name).toBe('Cached User');

    const uncachedUser = await service.getUser('other-user');
    // Will fall through to repository
  });
});
```

**Anti-Pattern**: Stubs that are too smart or contain production logic.

### Pattern 2: Mocks - Verifying Indirect Outputs

**When to Use**: Verifying interactions with collaborators

**Mock Verification Patterns:**
```typescript
describe('NotificationService', () => {
  let emailSender: jest.Mocked<EmailSender>;
  let smsSender: jest.Mocked<SMSSender>;
  let service: NotificationService;

  beforeEach(() => {
    emailSender = {
      send: jest.fn().mockResolvedValue({ messageId: 'msg-1' })
    };
    smsSender = {
      send: jest.fn().mockResolvedValue({ messageId: 'sms-1' })
    };
    service = new NotificationService(emailSender, smsSender);
  });

  it('should send email with correct parameters', async () => {
    const user = { email: 'test@example.com', name: 'Test' };

    await service.sendWelcomeEmail(user);

    // Verify the mock was called correctly
    expect(emailSender.send).toHaveBeenCalledTimes(1);
    expect(emailSender.send).toHaveBeenCalledWith({
      to: 'test@example.com',
      subject: 'Welcome!',
      template: 'welcome',
      data: { name: 'Test' }
    });
  });

  it('should not send SMS when user has no phone', async () => {
    const user = { email: 'test@example.com', name: 'Test' };

    await service.notifyUser(user, 'message');

    expect(emailSender.send).toHaveBeenCalled();
    expect(smsSender.send).not.toHaveBeenCalled();
  });

  it('should send both email and SMS when user has phone', async () => {
    const user = {
      email: 'test@example.com',
      phone: '+1234567890',
      name: 'Test'
    };

    await service.notifyUser(user, 'message');

    expect(emailSender.send).toHaveBeenCalled();
    expect(smsSender.send).toHaveBeenCalledWith({
      to: '+1234567890',
      message: 'message'
    });
  });

  it('should verify call order', async () => {
    const user = { email: 'test@example.com', name: 'Test' };

    await service.sendWelcomeSequence(user);

    // Verify order of calls
    const emailCalls = emailSender.send.mock.invocationCallOrder;
    expect(emailCalls[0]).toBeLessThan(emailCalls[1]);
  });
});
```

**Strict Mock Verification:**
```typescript
describe('PaymentProcessor', () => {
  it('should call payment gateway exactly once', async () => {
    const gateway = {
      charge: jest.fn().mockResolvedValue({ transactionId: 'tx-1' }),
      refund: jest.fn()
    };

    const processor = new PaymentProcessor(gateway);
    await processor.processPayment({ amount: 100, customerId: 'c-1' });

    // Strict verification - only charge was called
    expect(gateway.charge).toHaveBeenCalledTimes(1);
    expect(gateway.refund).not.toHaveBeenCalled();
  });

  it('should pass correct amount to gateway', async () => {
    const gateway = {
      charge: jest.fn().mockResolvedValue({ transactionId: 'tx-1' })
    };

    const processor = new PaymentProcessor(gateway);
    await processor.processPaymentWithTax({ amount: 100, taxRate: 0.1 });

    // Verify exact argument
    expect(gateway.charge).toHaveBeenCalledWith(
      expect.objectContaining({
        amount: 110, // 100 + 10% tax
        currency: 'USD'
      })
    );
  });
});
```

**Anti-Pattern**: Over-specifying mock expectations, making tests brittle.

### Pattern 3: Spies - Observing Real Behavior

**When to Use**: Need real behavior but want to verify calls

**Jest Spy Patterns:**
```typescript
describe('Logger', () => {
  it('should log to console in development', () => {
    // Spy on real method
    const consoleSpy = jest.spyOn(console, 'log').mockImplementation();

    const logger = new Logger({ environment: 'development' });
    logger.info('Test message');

    expect(consoleSpy).toHaveBeenCalledWith(
      expect.stringContaining('Test message')
    );

    // Restore original
    consoleSpy.mockRestore();
  });

  it('should track method calls while using real implementation', () => {
    const calculator = new Calculator();
    const addSpy = jest.spyOn(calculator, 'add');

    const result = calculator.sumArray([1, 2, 3, 4, 5]);

    // Real implementation was used
    expect(result).toBe(15);

    // But we can verify how many times add was called
    expect(addSpy).toHaveBeenCalledTimes(5);
  });
});

describe('EventEmitter', () => {
  it('should call all listeners', () => {
    const emitter = new EventEmitter();
    const listener1 = jest.fn();
    const listener2 = jest.fn();

    emitter.on('event', listener1);
    emitter.on('event', listener2);

    emitter.emit('event', { data: 'test' });

    expect(listener1).toHaveBeenCalledWith({ data: 'test' });
    expect(listener2).toHaveBeenCalledWith({ data: 'test' });
  });
});
```

**Module Spying:**
```typescript
import * as dateUtils from './dateUtils';

describe('ScheduleService', () => {
  it('should use current date', () => {
    const mockDate = new Date('2024-06-15T12:00:00Z');
    jest.spyOn(dateUtils, 'getCurrentDate').mockReturnValue(mockDate);

    const service = new ScheduleService();
    const schedule = service.createWeeklySchedule();

    expect(schedule.startDate).toEqual(mockDate);

    // Restore
    jest.restoreAllMocks();
  });
});
```

**Anti-Pattern**: Using spies when stubs would be clearer and simpler.

### Pattern 4: Fakes - Simplified Working Implementations

**When to Use**: Complex dependencies where stubs are insufficient

**In-Memory Repository Fake:**
```typescript
class FakeUserRepository implements UserRepository {
  private users: Map<string, User> = new Map();
  private emailIndex: Map<string, string> = new Map();

  async save(user: User): Promise<void> {
    this.users.set(user.id, { ...user });
    this.emailIndex.set(user.email.toLowerCase(), user.id);
  }

  async findById(id: string): Promise<User | null> {
    const user = this.users.get(id);
    return user ? { ...user } : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const id = this.emailIndex.get(email.toLowerCase());
    return id ? this.findById(id) : null;
  }

  async delete(id: string): Promise<boolean> {
    const user = this.users.get(id);
    if (!user) return false;

    this.emailIndex.delete(user.email.toLowerCase());
    return this.users.delete(id);
  }

  async findAll(filter?: UserFilter): Promise<User[]> {
    let users = Array.from(this.users.values());

    if (filter?.role) {
      users = users.filter(u => u.role === filter.role);
    }
    if (filter?.createdAfter) {
      users = users.filter(u => u.createdAt > filter.createdAfter!);
    }

    return users.map(u => ({ ...u }));
  }

  // Test helpers
  clear(): void {
    this.users.clear();
    this.emailIndex.clear();
  }

  seed(users: User[]): void {
    users.forEach(u => {
      this.users.set(u.id, u);
      this.emailIndex.set(u.email.toLowerCase(), u.id);
    });
  }

  getAll(): User[] {
    return Array.from(this.users.values());
  }
}

// Usage
describe('UserService with fake repository', () => {
  let repository: FakeUserRepository;
  let service: UserService;

  beforeEach(() => {
    repository = new FakeUserRepository();
    service = new UserService(repository);
  });

  afterEach(() => {
    repository.clear();
  });

  it('should create user and find by email', async () => {
    await service.createUser({
      email: 'test@example.com',
      name: 'Test User'
    });

    const found = await service.findByEmail('test@example.com');
    expect(found).toBeDefined();
    expect(found!.name).toBe('Test User');
  });

  it('should prevent duplicate emails', async () => {
    repository.seed([{
      id: 'existing',
      email: 'taken@example.com',
      name: 'Existing',
      role: 'user',
      createdAt: new Date()
    }]);

    await expect(
      service.createUser({ email: 'taken@example.com', name: 'New' })
    ).rejects.toThrow(DuplicateEmailError);
  });
});
```

**Fake HTTP Client:**
```typescript
interface HttpResponse<T> {
  status: number;
  data: T;
  headers: Record<string, string>;
}

class FakeHttpClient implements HttpClient {
  private responses: Map<string, HttpResponse<any>> = new Map();
  private errors: Map<string, Error> = new Map();
  private requestLog: Array<{ method: string; url: string; body?: any }> = [];

  // Setup methods
  onGet<T>(url: string, response: HttpResponse<T>): void {
    this.responses.set(`GET:${url}`, response);
  }

  onPost<T>(url: string, response: HttpResponse<T>): void {
    this.responses.set(`POST:${url}`, response);
  }

  onError(method: string, url: string, error: Error): void {
    this.errors.set(`${method}:${url}`, error);
  }

  // Implementation
  async get<T>(url: string): Promise<HttpResponse<T>> {
    this.requestLog.push({ method: 'GET', url });

    const error = this.errors.get(`GET:${url}`);
    if (error) throw error;

    const response = this.responses.get(`GET:${url}`);
    if (!response) {
      throw new Error(`No fake response configured for GET ${url}`);
    }
    return response;
  }

  async post<T>(url: string, body: any): Promise<HttpResponse<T>> {
    this.requestLog.push({ method: 'POST', url, body });

    const error = this.errors.get(`POST:${url}`);
    if (error) throw error;

    const response = this.responses.get(`POST:${url}`);
    if (!response) {
      throw new Error(`No fake response configured for POST ${url}`);
    }
    return response;
  }

  // Test helpers
  getRequests(): typeof this.requestLog {
    return [...this.requestLog];
  }

  clear(): void {
    this.responses.clear();
    this.errors.clear();
    this.requestLog = [];
  }
}

// Usage
describe('ApiClient', () => {
  let http: FakeHttpClient;
  let client: ApiClient;

  beforeEach(() => {
    http = new FakeHttpClient();
    client = new ApiClient(http);
  });

  it('should fetch user from API', async () => {
    http.onGet('/api/users/1', {
      status: 200,
      data: { id: '1', name: 'Test User' },
      headers: {}
    });

    const user = await client.getUser('1');
    expect(user.name).toBe('Test User');
  });

  it('should handle API errors', async () => {
    http.onError('GET', '/api/users/999', new Error('Not Found'));

    await expect(client.getUser('999')).rejects.toThrow('Not Found');
  });
});
```

**Anti-Pattern**: Fakes that replicate too much production logic.

### Pattern 5: Mocking Modules and Dependencies

**When to Use**: External libraries, Node.js modules

**Jest Module Mocking:**
```typescript
// Mock entire module
jest.mock('axios');
import axios from 'axios';

const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('ApiService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should call axios with correct config', async () => {
    mockedAxios.get.mockResolvedValue({
      data: { users: [] },
      status: 200
    });

    const service = new ApiService();
    await service.getUsers();

    expect(mockedAxios.get).toHaveBeenCalledWith(
      '/api/users',
      expect.objectContaining({
        headers: { 'Authorization': expect.any(String) }
      })
    );
  });
});

// Mock with factory
jest.mock('./database', () => ({
  query: jest.fn(),
  connect: jest.fn().mockResolvedValue(true),
  disconnect: jest.fn().mockResolvedValue(true)
}));

// Partial mock
jest.mock('./utils', () => ({
  ...jest.requireActual('./utils'),
  fetchData: jest.fn() // Only mock this one
}));
```

**Manual Mocks:**
```typescript
// __mocks__/fs.ts
const fs = jest.createMockFromModule('fs') as any;

let mockFiles: Record<string, string> = {};

fs.__setMockFiles = (files: Record<string, string>) => {
  mockFiles = { ...files };
};

fs.readFileSync = (path: string): string => {
  if (mockFiles[path]) {
    return mockFiles[path];
  }
  throw new Error(`ENOENT: no such file or directory, open '${path}'`);
};

fs.existsSync = (path: string): boolean => {
  return path in mockFiles;
};

fs.writeFileSync = (path: string, content: string): void => {
  mockFiles[path] = content;
};

export default fs;

// Usage
import fs from 'fs';
jest.mock('fs');

const mockedFs = fs as jest.Mocked<typeof fs> & {
  __setMockFiles: (files: Record<string, string>) => void;
};

describe('ConfigLoader', () => {
  beforeEach(() => {
    mockedFs.__setMockFiles({
      '/app/config.json': JSON.stringify({ port: 3000 }),
      '/app/config.prod.json': JSON.stringify({ port: 80 })
    });
  });

  it('should load config file', () => {
    const loader = new ConfigLoader('/app');
    const config = loader.load('config.json');
    expect(config.port).toBe(3000);
  });
});
```

**Anti-Pattern**: Mocking modules when a fake would be more maintainable.

### Pattern 6: Time and Date Mocking

**When to Use**: Time-dependent behavior, scheduled tasks

**Jest Fake Timers:**
```typescript
describe('Scheduler', () => {
  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('should execute callback after delay', () => {
    const callback = jest.fn();
    const scheduler = new Scheduler();

    scheduler.scheduleIn(1000, callback);

    expect(callback).not.toHaveBeenCalled();

    jest.advanceTimersByTime(1000);

    expect(callback).toHaveBeenCalledTimes(1);
  });

  it('should execute recurring task', () => {
    const task = jest.fn();
    const scheduler = new Scheduler();

    scheduler.scheduleRecurring(100, task);

    jest.advanceTimersByTime(350);

    expect(task).toHaveBeenCalledTimes(3);
  });

  it('should cancel scheduled task', () => {
    const task = jest.fn();
    const scheduler = new Scheduler();

    const taskId = scheduler.scheduleIn(1000, task);
    scheduler.cancel(taskId);

    jest.advanceTimersByTime(2000);

    expect(task).not.toHaveBeenCalled();
  });
});

describe('TokenService', () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2024-01-15T12:00:00Z'));
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('should generate token with correct expiry', () => {
    const service = new TokenService();
    const token = service.generateToken({ userId: 'user-1' }, '1h');

    expect(token.expiresAt).toEqual(new Date('2024-01-15T13:00:00Z'));
  });

  it('should detect expired token', () => {
    const service = new TokenService();
    const token = service.generateToken({ userId: 'user-1' }, '1h');

    // Token valid now
    expect(service.isValid(token)).toBe(true);

    // Advance time past expiry
    jest.advanceTimersByTime(61 * 60 * 1000);

    expect(service.isValid(token)).toBe(false);
  });
});
```

**Date Mocking:**
```typescript
describe('BillingService', () => {
  const RealDate = Date;

  beforeEach(() => {
    // Mock Date constructor
    global.Date = class extends RealDate {
      constructor(...args: any[]) {
        if (args.length === 0) {
          super('2024-01-15T12:00:00Z');
        } else {
          super(...args);
        }
      }

      static now() {
        return new RealDate('2024-01-15T12:00:00Z').getTime();
      }
    } as any;
  });

  afterEach(() => {
    global.Date = RealDate;
  });

  it('should calculate billing period', () => {
    const service = new BillingService();
    const period = service.getCurrentBillingPeriod();

    expect(period.start).toEqual(new Date('2024-01-01'));
    expect(period.end).toEqual(new Date('2024-01-31'));
  });
});
```

**Anti-Pattern**: Using real time in tests, causing flaky tests.

## Checklist

- [ ] Test doubles chosen appropriately (stub vs mock vs fake)
- [ ] Mocks verify behavior, not implementation
- [ ] Stubs return realistic data
- [ ] Fakes are simple but complete
- [ ] Module mocks are restored after tests
- [ ] Time mocking used for time-dependent code
- [ ] No over-mocking (testing mocks, not code)
- [ ] Mocks don't replicate production logic
- [ ] Clear naming distinguishes double types
- [ ] Integration tests verify real integrations

## References

- [Martin Fowler - Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html)
- [Jest Mock Functions](https://jestjs.io/docs/mock-functions)
- [xUnit Test Patterns](http://xunitpatterns.com/Test%20Double.html)
- [Testing Without Mocks](https://www.jamesshore.com/v2/projects/testing-without-mocks)
