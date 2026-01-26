---
title: Behavioral Design Patterns Reference
category: code
type: reference
version: "1.0.0"
---

# Behavioral Design Patterns

> Part of the code/design-patterns knowledge skill

## Overview

Behavioral patterns characterize the ways objects and classes interact and distribute responsibilities. This reference covers Strategy, Observer, and Command patterns with practical implementations.

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| Strategy | Interchangeable algorithms |
| Observer | Event notification system |
| Command | Encapsulate requests as objects |
| Chain of Responsibility | Pass requests along handlers |
| State | Object behavior changes with state |
| Template Method | Define algorithm skeleton |

## Patterns

### Pattern 1: Strategy

**When to Use**: Multiple algorithms that can be selected at runtime

**Example**:
```typescript
// Strategy interface
interface PricingStrategy {
  calculatePrice(basePrice: number, quantity: number): number;
  getName(): string;
}

// Concrete strategies
class RegularPricing implements PricingStrategy {
  calculatePrice(basePrice: number, quantity: number): number {
    return basePrice * quantity;
  }

  getName(): string {
    return 'Regular';
  }
}

class BulkDiscountPricing implements PricingStrategy {
  constructor(private threshold: number, private discountPercent: number) {}

  calculatePrice(basePrice: number, quantity: number): number {
    if (quantity >= this.threshold) {
      return basePrice * quantity * (1 - this.discountPercent / 100);
    }
    return basePrice * quantity;
  }

  getName(): string {
    return `Bulk (${this.discountPercent}% off for ${this.threshold}+)`;
  }
}

class MembershipPricing implements PricingStrategy {
  constructor(private membershipLevel: 'silver' | 'gold' | 'platinum') {}

  private discounts: Record<string, number> = {
    silver: 5,
    gold: 10,
    platinum: 15
  };

  calculatePrice(basePrice: number, quantity: number): number {
    const discount = this.discounts[this.membershipLevel];
    return basePrice * quantity * (1 - discount / 100);
  }

  getName(): string {
    return `${this.membershipLevel} membership`;
  }
}

class SeasonalPricing implements PricingStrategy {
  constructor(
    private startDate: Date,
    private endDate: Date,
    private discountPercent: number
  ) {}

  calculatePrice(basePrice: number, quantity: number): number {
    const now = new Date();
    if (now >= this.startDate && now <= this.endDate) {
      return basePrice * quantity * (1 - this.discountPercent / 100);
    }
    return basePrice * quantity;
  }

  getName(): string {
    return `Seasonal sale (${this.discountPercent}% off)`;
  }
}

// Context
class ShoppingCart {
  private items: CartItem[] = [];
  private pricingStrategy: PricingStrategy = new RegularPricing();

  setPricingStrategy(strategy: PricingStrategy): void {
    this.pricingStrategy = strategy;
  }

  addItem(item: CartItem): void {
    this.items.push(item);
  }

  getTotal(): { total: number; breakdown: PriceBreakdown[] } {
    const breakdown: PriceBreakdown[] = [];
    let total = 0;

    for (const item of this.items) {
      const itemTotal = this.pricingStrategy.calculatePrice(
        item.price,
        item.quantity
      );
      breakdown.push({
        item: item.name,
        quantity: item.quantity,
        unitPrice: item.price,
        total: itemTotal,
        strategy: this.pricingStrategy.getName()
      });
      total += itemTotal;
    }

    return { total, breakdown };
  }
}

// Strategy factory
class PricingStrategyFactory {
  static create(customer: Customer): PricingStrategy {
    // Chain strategies based on customer profile
    if (customer.membershipLevel === 'platinum') {
      return new MembershipPricing('platinum');
    }

    if (customer.orderCount > 100) {
      return new BulkDiscountPricing(10, 15);
    }

    if (customer.membershipLevel) {
      return new MembershipPricing(customer.membershipLevel);
    }

    return new RegularPricing();
  }
}

// Usage
const cart = new ShoppingCart();
cart.addItem({ name: 'Widget', price: 10, quantity: 5 });

// Apply different strategies
cart.setPricingStrategy(new RegularPricing());
console.log(cart.getTotal()); // 50

cart.setPricingStrategy(new BulkDiscountPricing(3, 10));
console.log(cart.getTotal()); // 45

cart.setPricingStrategy(PricingStrategyFactory.create(customer));
console.log(cart.getTotal());
```

**Anti-Pattern**: Large switch statements instead of strategy objects.

### Pattern 2: Observer

**When to Use**: Objects need to be notified of state changes

**Example**:
```typescript
// Observer interface
interface Observer<T> {
  update(event: T): void;
}

// Subject interface
interface Subject<T> {
  subscribe(observer: Observer<T>): () => void;
  notify(event: T): void;
}

// Generic event emitter
class EventEmitter<T> implements Subject<T> {
  private observers: Set<Observer<T>> = new Set();

  subscribe(observer: Observer<T>): () => void {
    this.observers.add(observer);
    return () => this.observers.delete(observer);
  }

  notify(event: T): void {
    this.observers.forEach(observer => {
      try {
        observer.update(event);
      } catch (error) {
        console.error('Observer error:', error);
      }
    });
  }
}

// Typed event system
interface OrderEvent {
  type: 'created' | 'updated' | 'cancelled' | 'shipped';
  order: Order;
  timestamp: Date;
}

class OrderEventEmitter extends EventEmitter<OrderEvent> {
  createOrder(order: Order): void {
    // Create order logic...
    this.notify({
      type: 'created',
      order,
      timestamp: new Date()
    });
  }

  updateOrder(order: Order): void {
    // Update order logic...
    this.notify({
      type: 'updated',
      order,
      timestamp: new Date()
    });
  }

  shipOrder(order: Order): void {
    // Ship order logic...
    this.notify({
      type: 'shipped',
      order,
      timestamp: new Date()
    });
  }
}

// Concrete observers
class EmailNotificationObserver implements Observer<OrderEvent> {
  constructor(private emailService: EmailService) {}

  update(event: OrderEvent): void {
    switch (event.type) {
      case 'created':
        this.emailService.sendOrderConfirmation(event.order);
        break;
      case 'shipped':
        this.emailService.sendShippingNotification(event.order);
        break;
    }
  }
}

class InventoryObserver implements Observer<OrderEvent> {
  constructor(private inventoryService: InventoryService) {}

  update(event: OrderEvent): void {
    if (event.type === 'created') {
      this.inventoryService.reserveItems(event.order.items);
    }
    if (event.type === 'cancelled') {
      this.inventoryService.releaseItems(event.order.items);
    }
  }
}

class AnalyticsObserver implements Observer<OrderEvent> {
  constructor(private analyticsService: AnalyticsService) {}

  update(event: OrderEvent): void {
    this.analyticsService.trackEvent('order', {
      action: event.type,
      orderId: event.order.id,
      value: event.order.total
    });
  }
}

// Usage
const orderEmitter = new OrderEventEmitter();

// Subscribe observers
const unsubEmail = orderEmitter.subscribe(
  new EmailNotificationObserver(emailService)
);
const unsubInventory = orderEmitter.subscribe(
  new InventoryObserver(inventoryService)
);
const unsubAnalytics = orderEmitter.subscribe(
  new AnalyticsObserver(analyticsService)
);

// Create order - all observers notified
orderEmitter.createOrder(newOrder);

// Unsubscribe when needed
unsubEmail();
```

**Async Observer Pattern**:
```typescript
interface AsyncObserver<T> {
  update(event: T): Promise<void>;
}

class AsyncEventEmitter<T> {
  private observers: Set<AsyncObserver<T>> = new Set();

  subscribe(observer: AsyncObserver<T>): () => void {
    this.observers.add(observer);
    return () => this.observers.delete(observer);
  }

  async notify(event: T): Promise<void> {
    const promises = Array.from(this.observers).map(observer =>
      observer.update(event).catch(error => {
        console.error('Async observer error:', error);
      })
    );
    await Promise.all(promises);
  }

  // Fire and forget version
  notifyAsync(event: T): void {
    this.notify(event);
  }
}
```

**Anti-Pattern**: Tight coupling between subject and observers.

### Pattern 3: Command

**When to Use**: Encapsulating operations with undo/redo support

**Example**:
```typescript
// Command interface
interface Command {
  execute(): Promise<void>;
  undo(): Promise<void>;
  getDescription(): string;
}

// Concrete commands
class AddToCartCommand implements Command {
  private previousQuantity: number = 0;

  constructor(
    private cart: ShoppingCart,
    private productId: string,
    private quantity: number
  ) {}

  async execute(): Promise<void> {
    const item = this.cart.getItem(this.productId);
    this.previousQuantity = item?.quantity || 0;
    await this.cart.addItem(this.productId, this.quantity);
  }

  async undo(): Promise<void> {
    if (this.previousQuantity === 0) {
      await this.cart.removeItem(this.productId);
    } else {
      await this.cart.setItemQuantity(this.productId, this.previousQuantity);
    }
  }

  getDescription(): string {
    return `Add ${this.quantity} of product ${this.productId} to cart`;
  }
}

class RemoveFromCartCommand implements Command {
  private removedItem: CartItem | null = null;

  constructor(
    private cart: ShoppingCart,
    private productId: string
  ) {}

  async execute(): Promise<void> {
    this.removedItem = this.cart.getItem(this.productId);
    await this.cart.removeItem(this.productId);
  }

  async undo(): Promise<void> {
    if (this.removedItem) {
      await this.cart.addItem(this.productId, this.removedItem.quantity);
    }
  }

  getDescription(): string {
    return `Remove product ${this.productId} from cart`;
  }
}

class ApplyCouponCommand implements Command {
  private previousCoupon: string | null = null;

  constructor(
    private cart: ShoppingCart,
    private couponCode: string
  ) {}

  async execute(): Promise<void> {
    this.previousCoupon = this.cart.getAppliedCoupon();
    await this.cart.applyCoupon(this.couponCode);
  }

  async undo(): Promise<void> {
    if (this.previousCoupon) {
      await this.cart.applyCoupon(this.previousCoupon);
    } else {
      await this.cart.removeCoupon();
    }
  }

  getDescription(): string {
    return `Apply coupon ${this.couponCode}`;
  }
}

// Invoker with undo/redo support
class CommandHistory {
  private history: Command[] = [];
  private undoneCommands: Command[] = [];

  async execute(command: Command): Promise<void> {
    await command.execute();
    this.history.push(command);
    this.undoneCommands = []; // Clear redo stack
  }

  async undo(): Promise<Command | null> {
    const command = this.history.pop();
    if (command) {
      await command.undo();
      this.undoneCommands.push(command);
      return command;
    }
    return null;
  }

  async redo(): Promise<Command | null> {
    const command = this.undoneCommands.pop();
    if (command) {
      await command.execute();
      this.history.push(command);
      return command;
    }
    return null;
  }

  canUndo(): boolean {
    return this.history.length > 0;
  }

  canRedo(): boolean {
    return this.undoneCommands.length > 0;
  }

  getHistory(): string[] {
    return this.history.map(cmd => cmd.getDescription());
  }
}

// Macro command (composite)
class MacroCommand implements Command {
  constructor(private commands: Command[]) {}

  async execute(): Promise<void> {
    for (const command of this.commands) {
      await command.execute();
    }
  }

  async undo(): Promise<void> {
    // Undo in reverse order
    for (let i = this.commands.length - 1; i >= 0; i--) {
      await this.commands[i].undo();
    }
  }

  getDescription(): string {
    return `Macro: ${this.commands.map(c => c.getDescription()).join(', ')}`;
  }
}

// Usage
const cart = new ShoppingCart();
const history = new CommandHistory();

// Execute commands
await history.execute(new AddToCartCommand(cart, 'PROD-1', 2));
await history.execute(new AddToCartCommand(cart, 'PROD-2', 1));
await history.execute(new ApplyCouponCommand(cart, 'SAVE10'));

console.log(history.getHistory());

// Undo
await history.undo(); // Remove coupon
await history.undo(); // Remove PROD-2

// Redo
await history.redo(); // Re-add PROD-2

// Macro command
const quickBuy = new MacroCommand([
  new AddToCartCommand(cart, 'BUNDLE-1', 1),
  new ApplyCouponCommand(cart, 'BUNDLE-DISCOUNT')
]);
await history.execute(quickBuy);
```

**Anti-Pattern**: Commands that don't properly implement undo.

### Pattern 4: Chain of Responsibility

**When to Use**: Multiple handlers should process a request

**Example**:
```typescript
// Handler interface
interface RequestHandler {
  setNext(handler: RequestHandler): RequestHandler;
  handle(request: HttpRequest): Promise<HttpResponse | null>;
}

// Base handler
abstract class BaseHandler implements RequestHandler {
  private nextHandler: RequestHandler | null = null;

  setNext(handler: RequestHandler): RequestHandler {
    this.nextHandler = handler;
    return handler;
  }

  async handle(request: HttpRequest): Promise<HttpResponse | null> {
    if (this.nextHandler) {
      return this.nextHandler.handle(request);
    }
    return null;
  }
}

// Concrete handlers
class AuthenticationHandler extends BaseHandler {
  async handle(request: HttpRequest): Promise<HttpResponse | null> {
    const token = request.headers['authorization'];

    if (!token) {
      return {
        status: 401,
        body: { error: 'Authentication required' }
      };
    }

    try {
      request.user = await this.verifyToken(token);
      return super.handle(request);
    } catch (error) {
      return {
        status: 401,
        body: { error: 'Invalid token' }
      };
    }
  }

  private async verifyToken(token: string): Promise<User> {
    // Token verification logic
    return { id: '1', name: 'User' };
  }
}

class RateLimitHandler extends BaseHandler {
  private requests: Map<string, number[]> = new Map();
  private limit = 100;
  private windowMs = 60000;

  async handle(request: HttpRequest): Promise<HttpResponse | null> {
    const key = request.ip;
    const now = Date.now();
    const windowStart = now - this.windowMs;

    let timestamps = this.requests.get(key) || [];
    timestamps = timestamps.filter(t => t > windowStart);

    if (timestamps.length >= this.limit) {
      return {
        status: 429,
        body: { error: 'Rate limit exceeded' },
        headers: { 'Retry-After': '60' }
      };
    }

    timestamps.push(now);
    this.requests.set(key, timestamps);

    return super.handle(request);
  }
}

class ValidationHandler extends BaseHandler {
  constructor(private schema: ValidationSchema) {
    super();
  }

  async handle(request: HttpRequest): Promise<HttpResponse | null> {
    const errors = this.validate(request.body, this.schema);

    if (errors.length > 0) {
      return {
        status: 400,
        body: { errors }
      };
    }

    return super.handle(request);
  }

  private validate(data: any, schema: ValidationSchema): string[] {
    // Validation logic
    return [];
  }
}

class LoggingHandler extends BaseHandler {
  constructor(private logger: Logger) {
    super();
  }

  async handle(request: HttpRequest): Promise<HttpResponse | null> {
    const start = Date.now();
    this.logger.info(`${request.method} ${request.path}`);

    const response = await super.handle(request);

    this.logger.info(`${request.method} ${request.path} - ${response?.status} (${Date.now() - start}ms)`);

    return response;
  }
}

class RouteHandler extends BaseHandler {
  constructor(private routes: Map<string, (req: HttpRequest) => Promise<HttpResponse>>) {
    super();
  }

  async handle(request: HttpRequest): Promise<HttpResponse | null> {
    const routeKey = `${request.method}:${request.path}`;
    const handler = this.routes.get(routeKey);

    if (handler) {
      return handler(request);
    }

    return {
      status: 404,
      body: { error: 'Not found' }
    };
  }
}

// Build chain
const logging = new LoggingHandler(logger);
const rateLimit = new RateLimitHandler();
const auth = new AuthenticationHandler();
const validation = new ValidationHandler(userSchema);
const routes = new RouteHandler(routeMap);

logging
  .setNext(rateLimit)
  .setNext(auth)
  .setNext(validation)
  .setNext(routes);

// Process request through chain
const response = await logging.handle(request);
```

**Anti-Pattern**: Chain that continues after a handler should have stopped it.

### Pattern 5: State

**When to Use**: Object behavior varies based on internal state

**Example**:
```typescript
// State interface
interface OrderState {
  process(order: Order): Promise<void>;
  cancel(order: Order): Promise<void>;
  ship(order: Order): Promise<void>;
  deliver(order: Order): Promise<void>;
  getName(): string;
}

// Concrete states
class PendingState implements OrderState {
  async process(order: Order): Promise<void> {
    // Process payment, reserve inventory
    await order.processPayment();
    await order.reserveInventory();
    order.setState(new ProcessingState());
  }

  async cancel(order: Order): Promise<void> {
    order.setState(new CancelledState());
  }

  async ship(order: Order): Promise<void> {
    throw new Error('Cannot ship pending order');
  }

  async deliver(order: Order): Promise<void> {
    throw new Error('Cannot deliver pending order');
  }

  getName(): string {
    return 'Pending';
  }
}

class ProcessingState implements OrderState {
  async process(order: Order): Promise<void> {
    throw new Error('Order already being processed');
  }

  async cancel(order: Order): Promise<void> {
    await order.refundPayment();
    await order.releaseInventory();
    order.setState(new CancelledState());
  }

  async ship(order: Order): Promise<void> {
    const trackingNumber = await order.createShipment();
    order.setTrackingNumber(trackingNumber);
    order.setState(new ShippedState());
  }

  async deliver(order: Order): Promise<void> {
    throw new Error('Cannot deliver order not yet shipped');
  }

  getName(): string {
    return 'Processing';
  }
}

class ShippedState implements OrderState {
  async process(order: Order): Promise<void> {
    throw new Error('Order already processed');
  }

  async cancel(order: Order): Promise<void> {
    throw new Error('Cannot cancel shipped order');
  }

  async ship(order: Order): Promise<void> {
    throw new Error('Order already shipped');
  }

  async deliver(order: Order): Promise<void> {
    order.setDeliveredAt(new Date());
    order.setState(new DeliveredState());
  }

  getName(): string {
    return 'Shipped';
  }
}

class DeliveredState implements OrderState {
  async process(order: Order): Promise<void> {
    throw new Error('Order already completed');
  }

  async cancel(order: Order): Promise<void> {
    throw new Error('Cannot cancel delivered order');
  }

  async ship(order: Order): Promise<void> {
    throw new Error('Order already delivered');
  }

  async deliver(order: Order): Promise<void> {
    throw new Error('Order already delivered');
  }

  getName(): string {
    return 'Delivered';
  }
}

class CancelledState implements OrderState {
  async process(order: Order): Promise<void> {
    throw new Error('Cannot process cancelled order');
  }

  async cancel(order: Order): Promise<void> {
    throw new Error('Order already cancelled');
  }

  async ship(order: Order): Promise<void> {
    throw new Error('Cannot ship cancelled order');
  }

  async deliver(order: Order): Promise<void> {
    throw new Error('Cannot deliver cancelled order');
  }

  getName(): string {
    return 'Cancelled';
  }
}

// Context
class Order {
  private state: OrderState = new PendingState();

  constructor(
    public readonly id: string,
    public readonly items: OrderItem[]
  ) {}

  setState(state: OrderState): void {
    console.log(`Order ${this.id}: ${this.state.getName()} -> ${state.getName()}`);
    this.state = state;
  }

  getState(): string {
    return this.state.getName();
  }

  // Delegate to current state
  async process(): Promise<void> {
    await this.state.process(this);
  }

  async cancel(): Promise<void> {
    await this.state.cancel(this);
  }

  async ship(): Promise<void> {
    await this.state.ship(this);
  }

  async deliver(): Promise<void> {
    await this.state.deliver(this);
  }

  // Internal methods called by states
  async processPayment(): Promise<void> { /* ... */ }
  async refundPayment(): Promise<void> { /* ... */ }
  async reserveInventory(): Promise<void> { /* ... */ }
  async releaseInventory(): Promise<void> { /* ... */ }
  async createShipment(): Promise<string> { return 'TRACK-123'; }
  setTrackingNumber(num: string): void { /* ... */ }
  setDeliveredAt(date: Date): void { /* ... */ }
}

// Usage
const order = new Order('ORD-1', items);

await order.process();  // Pending -> Processing
await order.ship();     // Processing -> Shipped
await order.deliver();  // Shipped -> Delivered

// Invalid transitions throw errors
try {
  await order.cancel(); // Error: Cannot cancel delivered order
} catch (e) {
  console.log(e.message);
}
```

**Anti-Pattern**: Large switch statements checking state before each operation.

## Checklist

- [ ] Strategy used for interchangeable algorithms
- [ ] Observer used for event-driven communication
- [ ] Command supports undo/redo when needed
- [ ] Chain of Responsibility for request pipelines
- [ ] State eliminates conditional logic
- [ ] Patterns combined appropriately
- [ ] Loose coupling maintained
- [ ] Single responsibility preserved

## References

- [Design Patterns: Elements of Reusable Object-Oriented Software](https://www.amazon.com/Design-Patterns-Elements-Reusable-Object-Oriented/dp/0201633612)
- [Refactoring Guru - Behavioral Patterns](https://refactoring.guru/design-patterns/behavioral-patterns)
- [Game Programming Patterns](https://gameprogrammingpatterns.com/)
