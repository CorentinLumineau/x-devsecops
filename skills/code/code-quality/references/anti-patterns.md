---
title: Common Anti-Patterns Reference
category: code
type: reference
version: "1.0.0"
---

# Common Anti-Patterns

> Part of the code/code-quality knowledge skill

## Overview

Anti-patterns are common solutions that appear beneficial but create problems in the long run. This reference covers code smells, design anti-patterns, and their solutions.

## Quick Reference (80/20)

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| God Object | Single class does too much | Split by responsibility |
| Spaghetti Code | Complex flow, tangled logic | Refactor to clear structure |
| Magic Numbers | Unexplained constants | Named constants |
| Premature Optimization | Optimizing without data | Profile first, then optimize |
| Copy-Paste | Duplicated code | Extract reusable functions |
| Golden Hammer | Same solution for everything | Choose appropriate tools |

## Patterns

### Anti-Pattern 1: God Object/Class

**Problem**: A single class that knows too much or does too much

**Example of Anti-Pattern**:
```typescript
// BAD: God class that handles everything
class UserManager {
  // User CRUD
  async createUser(data: UserData): Promise<User> { /* ... */ }
  async updateUser(id: string, data: Partial<UserData>): Promise<User> { /* ... */ }
  async deleteUser(id: string): Promise<void> { /* ... */ }
  async getUser(id: string): Promise<User> { /* ... */ }

  // Authentication
  async login(email: string, password: string): Promise<Token> { /* ... */ }
  async logout(token: string): Promise<void> { /* ... */ }
  async refreshToken(token: string): Promise<Token> { /* ... */ }
  async resetPassword(email: string): Promise<void> { /* ... */ }

  // Email notifications
  async sendWelcomeEmail(user: User): Promise<void> { /* ... */ }
  async sendPasswordResetEmail(user: User, token: string): Promise<void> { /* ... */ }
  async sendAccountDeletedEmail(email: string): Promise<void> { /* ... */ }

  // Validation
  validateEmail(email: string): boolean { /* ... */ }
  validatePassword(password: string): ValidationResult { /* ... */ }
  validateUsername(username: string): boolean { /* ... */ }

  // Analytics
  trackUserLogin(userId: string): void { /* ... */ }
  trackUserSignup(userId: string): void { /* ... */ }
  getLoginStats(userId: string): LoginStats { /* ... */ }

  // Permissions
  hasPermission(userId: string, permission: string): Promise<boolean> { /* ... */ }
  assignRole(userId: string, role: string): Promise<void> { /* ... */ }
  getPermissions(userId: string): Promise<string[]> { /* ... */ }
}
```

**Solution**: Split by responsibility following Single Responsibility Principle

```typescript
// GOOD: Split into focused classes

// User repository - data access only
class UserRepository {
  async create(data: UserData): Promise<User> { /* ... */ }
  async update(id: string, data: Partial<UserData>): Promise<User> { /* ... */ }
  async delete(id: string): Promise<void> { /* ... */ }
  async findById(id: string): Promise<User | null> { /* ... */ }
  async findByEmail(email: string): Promise<User | null> { /* ... */ }
}

// Authentication service
class AuthenticationService {
  constructor(
    private userRepo: UserRepository,
    private tokenService: TokenService,
    private passwordService: PasswordService
  ) {}

  async login(email: string, password: string): Promise<Token> { /* ... */ }
  async logout(token: string): Promise<void> { /* ... */ }
  async refreshToken(token: string): Promise<Token> { /* ... */ }
}

// Email service
class UserEmailService {
  constructor(private emailProvider: EmailProvider) {}

  async sendWelcome(user: User): Promise<void> { /* ... */ }
  async sendPasswordReset(user: User, token: string): Promise<void> { /* ... */ }
  async sendAccountDeleted(email: string): Promise<void> { /* ... */ }
}

// Validation service
class UserValidationService {
  validateEmail(email: string): boolean { /* ... */ }
  validatePassword(password: string): ValidationResult { /* ... */ }
  validateUsername(username: string): boolean { /* ... */ }
}

// Analytics service
class UserAnalyticsService {
  constructor(private analytics: AnalyticsProvider) {}

  trackLogin(userId: string): void { /* ... */ }
  trackSignup(userId: string): void { /* ... */ }
  getLoginStats(userId: string): LoginStats { /* ... */ }
}

// Permissions service
class PermissionService {
  constructor(private roleRepo: RoleRepository) {}

  async hasPermission(userId: string, permission: string): Promise<boolean> { /* ... */ }
  async assignRole(userId: string, role: string): Promise<void> { /* ... */ }
  async getPermissions(userId: string): Promise<string[]> { /* ... */ }
}

// Facade for common operations (optional)
class UserService {
  constructor(
    private userRepo: UserRepository,
    private authService: AuthenticationService,
    private emailService: UserEmailService
  ) {}

  async registerUser(data: UserData): Promise<User> {
    const user = await this.userRepo.create(data);
    await this.emailService.sendWelcome(user);
    return user;
  }
}
```

### Anti-Pattern 2: Primitive Obsession

**Problem**: Using primitives instead of small objects for simple tasks

**Example of Anti-Pattern**:
```typescript
// BAD: Primitives everywhere
function createOrder(
  userId: string,
  productIds: string[],
  shippingAddress: string,
  billingAddress: string,
  phoneNumber: string,
  email: string,
  total: number,
  currency: string,
  discountCode: string | null,
  discountPercentage: number
): Order {
  // Validation scattered throughout
  if (!email.includes('@')) throw new Error('Invalid email');
  if (phoneNumber.length < 10) throw new Error('Invalid phone');
  if (!['USD', 'EUR', 'GBP'].includes(currency)) throw new Error('Invalid currency');
  if (discountPercentage < 0 || discountPercentage > 100) throw new Error('Invalid discount');
  // ...
}

// Using the function is error-prone
createOrder(
  'user123',
  ['prod1', 'prod2'],
  '123 Main St',
  '456 Billing Ave', // Easy to swap addresses
  'not-a-phone',     // No validation until runtime
  'invalid-email',   // Same
  100,
  'INVALID',         // Will fail at runtime
  'SAVE10',
  -10                // Negative discount!
);
```

**Solution**: Create value objects that encapsulate validation

```typescript
// GOOD: Value objects with validation

class Email {
  private constructor(private readonly value: string) {}

  static create(email: string): Email {
    if (!email.match(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)) {
      throw new InvalidEmailError(email);
    }
    return new Email(email.toLowerCase());
  }

  toString(): string {
    return this.value;
  }

  equals(other: Email): boolean {
    return this.value === other.value;
  }
}

class PhoneNumber {
  private constructor(private readonly value: string) {}

  static create(phone: string): PhoneNumber {
    const cleaned = phone.replace(/\D/g, '');
    if (cleaned.length < 10 || cleaned.length > 15) {
      throw new InvalidPhoneError(phone);
    }
    return new PhoneNumber(cleaned);
  }

  format(): string {
    // Format based on length/country
    return this.value.replace(/(\d{3})(\d{3})(\d{4})/, '($1) $2-$3');
  }
}

class Money {
  private constructor(
    private readonly amount: number,
    private readonly currency: Currency
  ) {}

  static create(amount: number, currency: string): Money {
    if (amount < 0) {
      throw new InvalidAmountError(amount);
    }
    return new Money(amount, Currency.fromCode(currency));
  }

  add(other: Money): Money {
    if (!this.currency.equals(other.currency)) {
      throw new CurrencyMismatchError();
    }
    return new Money(this.amount + other.amount, this.currency);
  }

  applyDiscount(discount: Discount): Money {
    const discountedAmount = this.amount * (1 - discount.percentage / 100);
    return new Money(discountedAmount, this.currency);
  }
}

class Discount {
  private constructor(
    public readonly code: string,
    public readonly percentage: number
  ) {}

  static create(code: string, percentage: number): Discount {
    if (percentage < 0 || percentage > 100) {
      throw new InvalidDiscountError(percentage);
    }
    return new Discount(code, percentage);
  }
}

class Address {
  constructor(
    public readonly street: string,
    public readonly city: string,
    public readonly state: string,
    public readonly zipCode: string,
    public readonly country: string
  ) {
    this.validate();
  }

  private validate(): void {
    if (!this.street || !this.city || !this.zipCode) {
      throw new InvalidAddressError();
    }
  }
}

// Now the function signature is clear and type-safe
interface CreateOrderInput {
  userId: UserId;
  productIds: ProductId[];
  shippingAddress: Address;
  billingAddress: Address;
  phoneNumber: PhoneNumber;
  email: Email;
  total: Money;
  discount?: Discount;
}

function createOrder(input: CreateOrderInput): Order {
  // No validation needed - types guarantee validity
  const finalTotal = input.discount
    ? input.total.applyDiscount(input.discount)
    : input.total;

  return new Order(input, finalTotal);
}
```

### Anti-Pattern 3: Callback Hell

**Problem**: Deeply nested callbacks making code hard to read and maintain

**Example of Anti-Pattern**:
```typescript
// BAD: Callback hell
function processOrder(orderId: string, callback: (err: Error | null, result?: any) => void) {
  getOrder(orderId, (err, order) => {
    if (err) return callback(err);

    validateInventory(order.items, (err, inventory) => {
      if (err) return callback(err);

      if (!inventory.available) {
        return callback(new Error('Out of stock'));
      }

      processPayment(order.payment, (err, payment) => {
        if (err) return callback(err);

        if (!payment.success) {
          return callback(new Error('Payment failed'));
        }

        reserveInventory(order.items, (err) => {
          if (err) return callback(err);

          sendConfirmationEmail(order.customer, (err) => {
            if (err) {
              // Don't fail the order, just log
              console.error('Failed to send email', err);
            }

            updateOrderStatus(orderId, 'confirmed', (err, updatedOrder) => {
              if (err) return callback(err);

              callback(null, updatedOrder);
            });
          });
        });
      });
    });
  });
}
```

**Solution**: Use async/await with proper error handling

```typescript
// GOOD: Async/await with clear flow
async function processOrder(orderId: string): Promise<Order> {
  const order = await getOrder(orderId);

  const inventory = await validateInventory(order.items);
  if (!inventory.available) {
    throw new OutOfStockError(order.items);
  }

  const payment = await processPayment(order.payment);
  if (!payment.success) {
    throw new PaymentFailedError(payment.error);
  }

  await reserveInventory(order.items);

  // Non-critical operation - don't fail the order
  try {
    await sendConfirmationEmail(order.customer);
  } catch (error) {
    logger.warn('Failed to send confirmation email', { orderId, error });
  }

  return updateOrderStatus(orderId, 'confirmed');
}

// Even better: Extract steps into a pipeline
class OrderProcessor {
  private steps: OrderProcessingStep[] = [
    new ValidateInventoryStep(),
    new ProcessPaymentStep(),
    new ReserveInventoryStep(),
    new SendConfirmationStep({ critical: false }),
    new UpdateStatusStep()
  ];

  async process(orderId: string): Promise<Order> {
    let order = await this.orderRepo.findById(orderId);

    for (const step of this.steps) {
      order = await step.execute(order);
    }

    return order;
  }
}
```

### Anti-Pattern 4: Feature Envy

**Problem**: A method that uses another class's data more than its own

**Example of Anti-Pattern**:
```typescript
// BAD: ReportGenerator is too interested in Order's data
class ReportGenerator {
  generateOrderReport(order: Order): string {
    let report = '';

    // Reaching into order's internals
    report += `Order ID: ${order.id}\n`;
    report += `Customer: ${order.customer.name}\n`;
    report += `Email: ${order.customer.email}\n`;

    report += '\nItems:\n';
    for (const item of order.items) {
      const subtotal = item.price * item.quantity;
      const tax = subtotal * 0.1;
      const discount = item.discountPercentage
        ? subtotal * (item.discountPercentage / 100)
        : 0;
      const total = subtotal + tax - discount;

      report += `  ${item.name}: $${total.toFixed(2)}\n`;
    }

    // More calculation using order's data
    const subtotal = order.items.reduce((sum, item) =>
      sum + item.price * item.quantity, 0);
    const tax = subtotal * 0.1;
    const discount = order.coupon
      ? subtotal * (order.coupon.discountPercentage / 100)
      : 0;
    const shipping = order.shippingMethod === 'express' ? 15 : 5;
    const total = subtotal + tax - discount + shipping;

    report += `\nSubtotal: $${subtotal.toFixed(2)}`;
    report += `\nTax: $${tax.toFixed(2)}`;
    report += `\nDiscount: -$${discount.toFixed(2)}`;
    report += `\nShipping: $${shipping.toFixed(2)}`;
    report += `\nTotal: $${total.toFixed(2)}`;

    return report;
  }
}
```

**Solution**: Move behavior to the class that owns the data

```typescript
// GOOD: Order knows how to calculate its own totals
class Order {
  constructor(
    public readonly id: string,
    public readonly customer: Customer,
    public readonly items: OrderItem[],
    public readonly coupon: Coupon | null,
    public readonly shippingMethod: ShippingMethod
  ) {}

  getSubtotal(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.getTotal()),
      Money.zero(this.currency)
    );
  }

  getTax(): Money {
    return this.getSubtotal().multiply(0.1);
  }

  getDiscount(): Money {
    if (!this.coupon) return Money.zero(this.currency);
    return this.getSubtotal().multiply(this.coupon.percentage / 100);
  }

  getShipping(): Money {
    return Money.create(
      this.shippingMethod === 'express' ? 15 : 5,
      this.currency
    );
  }

  getTotal(): Money {
    return this.getSubtotal()
      .add(this.getTax())
      .subtract(this.getDiscount())
      .add(this.getShipping());
  }

  // Order knows how to format itself
  toReport(): OrderReport {
    return {
      orderId: this.id,
      customer: this.customer.toReportFormat(),
      items: this.items.map(item => item.toReportFormat()),
      subtotal: this.getSubtotal(),
      tax: this.getTax(),
      discount: this.getDiscount(),
      shipping: this.getShipping(),
      total: this.getTotal()
    };
  }
}

class OrderItem {
  getTotal(): Money {
    const subtotal = this.price.multiply(this.quantity);
    const tax = subtotal.multiply(0.1);
    const discount = this.discountPercentage
      ? subtotal.multiply(this.discountPercentage / 100)
      : Money.zero(this.currency);

    return subtotal.add(tax).subtract(discount);
  }

  toReportFormat(): ItemReport {
    return {
      name: this.name,
      quantity: this.quantity,
      unitPrice: this.price,
      total: this.getTotal()
    };
  }
}

// Now ReportGenerator just formats data
class ReportGenerator {
  generateOrderReport(order: Order): string {
    const report = order.toReport();

    return `
Order ID: ${report.orderId}
Customer: ${report.customer.name}
Email: ${report.customer.email}

Items:
${report.items.map(item =>
  `  ${item.name}: ${item.total.format()}`
).join('\n')}

Subtotal: ${report.subtotal.format()}
Tax: ${report.tax.format()}
Discount: -${report.discount.format()}
Shipping: ${report.shipping.format()}
Total: ${report.total.format()}
    `.trim();
  }
}
```

### Anti-Pattern 5: Boolean Parameters

**Problem**: Boolean parameters make function calls hard to understand

**Example of Anti-Pattern**:
```typescript
// BAD: What do these booleans mean?
createUser('john@example.com', 'John', true, false, true);

function createUser(
  email: string,
  name: string,
  sendWelcomeEmail: boolean,
  isAdmin: boolean,
  requireEmailVerification: boolean
): User {
  // ...
}

// Even worse with more booleans
renderButton('Submit', true, false, true, false, true);
```

**Solution**: Use options objects or enums

```typescript
// GOOD: Options object makes intent clear
interface CreateUserOptions {
  email: string;
  name: string;
  sendWelcomeEmail?: boolean;
  role?: UserRole;
  requireEmailVerification?: boolean;
}

function createUser(options: CreateUserOptions): User {
  const {
    email,
    name,
    sendWelcomeEmail = true,
    role = UserRole.USER,
    requireEmailVerification = true
  } = options;
  // ...
}

// Clear at call site
createUser({
  email: 'john@example.com',
  name: 'John',
  sendWelcomeEmail: true,
  requireEmailVerification: true
});

// For button example, use specific types
interface ButtonProps {
  label: string;
  variant: 'primary' | 'secondary' | 'danger';
  size: 'small' | 'medium' | 'large';
  disabled?: boolean;
  loading?: boolean;
  fullWidth?: boolean;
}

renderButton({
  label: 'Submit',
  variant: 'primary',
  size: 'medium',
  loading: true
});

// Or use builder pattern for complex objects
const button = new ButtonBuilder()
  .label('Submit')
  .primary()
  .medium()
  .loading()
  .build();
```

### Anti-Pattern 6: Null Returns

**Problem**: Returning null forces callers to check for null everywhere

**Example of Anti-Pattern**:
```typescript
// BAD: Null returns everywhere
function findUser(id: string): User | null {
  return users.get(id) || null;
}

function getUserEmail(userId: string): string | null {
  const user = findUser(userId);
  if (!user) return null;
  return user.email;
}

function getUserPreferences(userId: string): Preferences | null {
  const user = findUser(userId);
  if (!user) return null;
  return user.preferences || null;
}

// Caller must check null at every step
const email = getUserEmail(userId);
if (email === null) {
  // handle null
}

const prefs = getUserPreferences(userId);
if (prefs === null) {
  // handle null
}
```

**Solution**: Use Option/Maybe pattern or throw meaningful exceptions

```typescript
// GOOD: Option type
class Option<T> {
  private constructor(private readonly value: T | null) {}

  static some<T>(value: T): Option<T> {
    return new Option(value);
  }

  static none<T>(): Option<T> {
    return new Option<T>(null);
  }

  isSome(): boolean {
    return this.value !== null;
  }

  isNone(): boolean {
    return this.value === null;
  }

  map<U>(fn: (value: T) => U): Option<U> {
    if (this.value === null) return Option.none();
    return Option.some(fn(this.value));
  }

  flatMap<U>(fn: (value: T) => Option<U>): Option<U> {
    if (this.value === null) return Option.none();
    return fn(this.value);
  }

  getOrElse(defaultValue: T): T {
    return this.value ?? defaultValue;
  }

  getOrThrow(error: Error): T {
    if (this.value === null) throw error;
    return this.value;
  }
}

// Usage
function findUser(id: string): Option<User> {
  const user = users.get(id);
  return user ? Option.some(user) : Option.none();
}

// Chainable operations
const email = findUser(userId)
  .map(user => user.email)
  .getOrElse('default@example.com');

const city = findUser(userId)
  .flatMap(user => Option.some(user.address))
  .map(address => address.city)
  .getOrElse('Unknown');

// Or throw meaningful errors
function getUser(id: string): User {
  const user = users.get(id);
  if (!user) {
    throw new UserNotFoundError(id);
  }
  return user;
}

// Separate methods for different use cases
class UserRepository {
  // Returns null - use when absence is normal
  findById(id: string): User | null { /* ... */ }

  // Throws - use when absence is unexpected
  getById(id: string): User {
    const user = this.findById(id);
    if (!user) throw new UserNotFoundError(id);
    return user;
  }

  // Returns Option - use for functional style
  find(id: string): Option<User> {
    const user = this.findById(id);
    return user ? Option.some(user) : Option.none();
  }
}
```

## Checklist

- [ ] Classes have single responsibility
- [ ] Value objects used instead of primitives
- [ ] Async/await instead of callbacks
- [ ] Methods use their own class's data
- [ ] Options objects instead of boolean params
- [ ] Null handled appropriately (Option/throw)
- [ ] No magic numbers/strings
- [ ] No copy-paste duplication
- [ ] Clear naming conventions
- [ ] Consistent abstraction levels

## References

- [Refactoring: Improving the Design of Existing Code](https://martinfowler.com/books/refactoring.html)
- [Code Smells](https://refactoring.guru/refactoring/smells)
- [Clean Code](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [AntiPatterns](https://sourcemaking.com/antipatterns)
