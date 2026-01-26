---
title: Creational Design Patterns Reference
category: code
type: reference
version: "1.0.0"
---

# Creational Design Patterns

> Part of the code/design-patterns knowledge skill

## Overview

Creational patterns abstract the instantiation process, making systems independent of how objects are created, composed, and represented. This reference covers Factory, Builder, and Singleton patterns with practical implementations.

## Quick Reference (80/20)

| Pattern | When to Use |
|---------|-------------|
| Factory Method | Delegate instantiation to subclasses |
| Abstract Factory | Create families of related objects |
| Builder | Construct complex objects step by step |
| Singleton | Ensure single instance globally |
| Prototype | Clone existing objects |

## Patterns

### Pattern 1: Factory Method

**When to Use**: When a class cannot anticipate the class of objects it must create

**Example**:
```typescript
// Product interface
interface Logger {
  log(message: string): void;
  error(message: string): void;
}

// Concrete products
class ConsoleLogger implements Logger {
  log(message: string): void {
    console.log(`[LOG] ${message}`);
  }
  error(message: string): void {
    console.error(`[ERROR] ${message}`);
  }
}

class FileLogger implements Logger {
  constructor(private filePath: string) {}

  log(message: string): void {
    fs.appendFileSync(this.filePath, `[LOG] ${message}\n`);
  }
  error(message: string): void {
    fs.appendFileSync(this.filePath, `[ERROR] ${message}\n`);
  }
}

class CloudLogger implements Logger {
  constructor(private endpoint: string, private apiKey: string) {}

  log(message: string): void {
    this.send('info', message);
  }
  error(message: string): void {
    this.send('error', message);
  }
  private send(level: string, message: string): void {
    // Send to cloud logging service
  }
}

// Factory
type LoggerType = 'console' | 'file' | 'cloud';

interface LoggerConfig {
  type: LoggerType;
  filePath?: string;
  endpoint?: string;
  apiKey?: string;
}

class LoggerFactory {
  static create(config: LoggerConfig): Logger {
    switch (config.type) {
      case 'console':
        return new ConsoleLogger();

      case 'file':
        if (!config.filePath) {
          throw new Error('filePath required for file logger');
        }
        return new FileLogger(config.filePath);

      case 'cloud':
        if (!config.endpoint || !config.apiKey) {
          throw new Error('endpoint and apiKey required for cloud logger');
        }
        return new CloudLogger(config.endpoint, config.apiKey);

      default:
        throw new Error(`Unknown logger type: ${config.type}`);
    }
  }
}

// Usage
const logger = LoggerFactory.create({
  type: process.env.NODE_ENV === 'production' ? 'cloud' : 'console',
  endpoint: process.env.LOG_ENDPOINT,
  apiKey: process.env.LOG_API_KEY
});

logger.log('Application started');
```

**Anti-Pattern**: Large switch statements in factories; use registry pattern instead.

```typescript
// Better: Registry-based factory
class LoggerRegistry {
  private static creators: Map<string, (config: any) => Logger> = new Map();

  static register(type: string, creator: (config: any) => Logger): void {
    this.creators.set(type, creator);
  }

  static create(config: LoggerConfig): Logger {
    const creator = this.creators.get(config.type);
    if (!creator) {
      throw new Error(`Unknown logger type: ${config.type}`);
    }
    return creator(config);
  }
}

// Register implementations
LoggerRegistry.register('console', () => new ConsoleLogger());
LoggerRegistry.register('file', (c) => new FileLogger(c.filePath));
LoggerRegistry.register('cloud', (c) => new CloudLogger(c.endpoint, c.apiKey));
```

### Pattern 2: Abstract Factory

**When to Use**: Creating families of related objects without specifying concrete classes

**Example**:
```typescript
// Abstract products
interface Button {
  render(): string;
  onClick(handler: () => void): void;
}

interface Input {
  render(): string;
  getValue(): string;
  setValue(value: string): void;
}

interface Modal {
  render(): string;
  open(): void;
  close(): void;
}

// Abstract factory
interface UIFactory {
  createButton(label: string): Button;
  createInput(placeholder: string): Input;
  createModal(title: string): Modal;
}

// Material Design implementation
class MaterialButton implements Button {
  constructor(private label: string) {}
  render(): string {
    return `<button class="mdc-button">${this.label}</button>`;
  }
  onClick(handler: () => void): void {
    // Material ripple effect + handler
  }
}

class MaterialInput implements Input {
  private value = '';
  constructor(private placeholder: string) {}
  render(): string {
    return `<input class="mdc-text-field" placeholder="${this.placeholder}">`;
  }
  getValue(): string { return this.value; }
  setValue(value: string): void { this.value = value; }
}

class MaterialModal implements Modal {
  constructor(private title: string) {}
  render(): string {
    return `<div class="mdc-dialog"><h2>${this.title}</h2></div>`;
  }
  open(): void { /* Material animation */ }
  close(): void { /* Material animation */ }
}

class MaterialUIFactory implements UIFactory {
  createButton(label: string): Button {
    return new MaterialButton(label);
  }
  createInput(placeholder: string): Input {
    return new MaterialInput(placeholder);
  }
  createModal(title: string): Modal {
    return new MaterialModal(title);
  }
}

// Bootstrap implementation
class BootstrapButton implements Button {
  constructor(private label: string) {}
  render(): string {
    return `<button class="btn btn-primary">${this.label}</button>`;
  }
  onClick(handler: () => void): void { /* Bootstrap handler */ }
}

class BootstrapUIFactory implements UIFactory {
  createButton(label: string): Button {
    return new BootstrapButton(label);
  }
  createInput(placeholder: string): Input {
    return new BootstrapInput(placeholder);
  }
  createModal(title: string): Modal {
    return new BootstrapModal(title);
  }
}

// Usage - Client code works with any UI framework
class LoginForm {
  private button: Button;
  private usernameInput: Input;
  private passwordInput: Input;

  constructor(factory: UIFactory) {
    this.usernameInput = factory.createInput('Username');
    this.passwordInput = factory.createInput('Password');
    this.button = factory.createButton('Login');
  }

  render(): string {
    return `
      <form>
        ${this.usernameInput.render()}
        ${this.passwordInput.render()}
        ${this.button.render()}
      </form>
    `;
  }
}

// Switch UI frameworks without changing LoginForm
const factory = theme === 'material'
  ? new MaterialUIFactory()
  : new BootstrapUIFactory();

const loginForm = new LoginForm(factory);
```

**Anti-Pattern**: Creating objects directly instead of using the factory.

### Pattern 3: Builder

**When to Use**: Constructing complex objects with many optional parameters

**Example**:
```typescript
// Product
interface HttpRequest {
  method: string;
  url: string;
  headers: Record<string, string>;
  body?: any;
  timeout: number;
  retries: number;
  auth?: { type: string; credentials: any };
}

// Builder
class HttpRequestBuilder {
  private request: Partial<HttpRequest> = {
    method: 'GET',
    headers: {},
    timeout: 30000,
    retries: 0
  };

  method(method: string): this {
    this.request.method = method;
    return this;
  }

  url(url: string): this {
    this.request.url = url;
    return this;
  }

  header(key: string, value: string): this {
    this.request.headers![key] = value;
    return this;
  }

  headers(headers: Record<string, string>): this {
    this.request.headers = { ...this.request.headers, ...headers };
    return this;
  }

  body(body: any): this {
    this.request.body = body;
    return this;
  }

  json(data: any): this {
    this.request.body = JSON.stringify(data);
    this.request.headers!['Content-Type'] = 'application/json';
    return this;
  }

  timeout(ms: number): this {
    this.request.timeout = ms;
    return this;
  }

  retries(count: number): this {
    this.request.retries = count;
    return this;
  }

  bearerAuth(token: string): this {
    this.request.auth = { type: 'bearer', credentials: token };
    this.request.headers!['Authorization'] = `Bearer ${token}`;
    return this;
  }

  basicAuth(username: string, password: string): this {
    const credentials = Buffer.from(`${username}:${password}`).toString('base64');
    this.request.auth = { type: 'basic', credentials };
    this.request.headers!['Authorization'] = `Basic ${credentials}`;
    return this;
  }

  build(): HttpRequest {
    if (!this.request.url) {
      throw new Error('URL is required');
    }

    return {
      method: this.request.method!,
      url: this.request.url,
      headers: this.request.headers!,
      body: this.request.body,
      timeout: this.request.timeout!,
      retries: this.request.retries!,
      auth: this.request.auth
    };
  }
}

// Usage
const request = new HttpRequestBuilder()
  .method('POST')
  .url('https://api.example.com/users')
  .json({ name: 'John', email: 'john@example.com' })
  .bearerAuth(token)
  .timeout(5000)
  .retries(3)
  .build();

// Director for common configurations
class HttpRequestDirector {
  static apiRequest(url: string, token: string): HttpRequestBuilder {
    return new HttpRequestBuilder()
      .url(url)
      .bearerAuth(token)
      .header('Accept', 'application/json')
      .timeout(10000)
      .retries(2);
  }

  static fileUpload(url: string, file: Buffer): HttpRequestBuilder {
    return new HttpRequestBuilder()
      .method('POST')
      .url(url)
      .header('Content-Type', 'multipart/form-data')
      .body(file)
      .timeout(60000);
  }
}

// Usage with director
const apiRequest = HttpRequestDirector
  .apiRequest('https://api.example.com/data', token)
  .method('POST')
  .json({ query: 'search term' })
  .build();
```

**Anti-Pattern**: Constructors with many optional parameters (telescoping constructor).

### Pattern 4: Singleton

**When to Use**: Ensuring a single instance with global access point

**Example**:
```typescript
// Classic singleton (not recommended for most cases)
class DatabaseConnection {
  private static instance: DatabaseConnection | null = null;
  private connection: any;

  private constructor() {
    // Private constructor prevents direct instantiation
  }

  static getInstance(): DatabaseConnection {
    if (!DatabaseConnection.instance) {
      DatabaseConnection.instance = new DatabaseConnection();
    }
    return DatabaseConnection.instance;
  }

  async connect(config: DatabaseConfig): Promise<void> {
    this.connection = await createConnection(config);
  }

  async query(sql: string): Promise<any> {
    return this.connection.query(sql);
  }
}

// Better: Module-level singleton (JavaScript/TypeScript)
// database.ts
let connection: Connection | null = null;

export async function getConnection(): Promise<Connection> {
  if (!connection) {
    connection = await createConnection(config);
  }
  return connection;
}

export async function closeConnection(): Promise<void> {
  if (connection) {
    await connection.close();
    connection = null;
  }
}

// Even better: Dependency injection container
class Container {
  private static instances: Map<string, any> = new Map();
  private static factories: Map<string, () => any> = new Map();

  static registerSingleton<T>(token: string, factory: () => T): void {
    this.factories.set(token, factory);
  }

  static get<T>(token: string): T {
    if (!this.instances.has(token)) {
      const factory = this.factories.get(token);
      if (!factory) {
        throw new Error(`No factory registered for ${token}`);
      }
      this.instances.set(token, factory());
    }
    return this.instances.get(token);
  }

  static reset(): void {
    this.instances.clear();
  }
}

// Registration
Container.registerSingleton('database', () => new DatabaseConnection());
Container.registerSingleton('logger', () => new ConsoleLogger());

// Usage
const db = Container.get<DatabaseConnection>('database');
```

**Anti-Pattern**: Using singleton for everything; prefer dependency injection.

### Pattern 5: Prototype

**When to Use**: Creating objects by cloning existing instances

**Example**:
```typescript
interface Prototype<T> {
  clone(): T;
}

// Complex object that's expensive to create
class ReportTemplate implements Prototype<ReportTemplate> {
  private sections: Section[] = [];
  private styles: StyleConfig;
  private headers: HeaderConfig;
  private footers: FooterConfig;

  constructor(
    private name: string,
    private type: 'pdf' | 'excel' | 'html'
  ) {
    // Expensive initialization
    this.styles = this.loadStyles();
    this.headers = this.loadHeaders();
    this.footers = this.loadFooters();
  }

  private loadStyles(): StyleConfig {
    // Expensive operation
    return { /* complex style config */ };
  }

  private loadHeaders(): HeaderConfig {
    return { /* header config */ };
  }

  private loadFooters(): FooterConfig {
    return { /* footer config */ };
  }

  addSection(section: Section): void {
    this.sections.push(section);
  }

  clone(): ReportTemplate {
    // Create shallow copy
    const clone = Object.create(Object.getPrototypeOf(this));

    // Copy primitive properties
    clone.name = `${this.name} (copy)`;
    clone.type = this.type;

    // Deep copy complex properties
    clone.sections = this.sections.map(s => ({ ...s }));
    clone.styles = JSON.parse(JSON.stringify(this.styles));
    clone.headers = { ...this.headers };
    clone.footers = { ...this.footers };

    return clone;
  }
}

// Prototype registry
class ReportTemplateRegistry {
  private templates: Map<string, ReportTemplate> = new Map();

  register(key: string, template: ReportTemplate): void {
    this.templates.set(key, template);
  }

  create(key: string): ReportTemplate {
    const prototype = this.templates.get(key);
    if (!prototype) {
      throw new Error(`Template ${key} not found`);
    }
    return prototype.clone();
  }
}

// Usage
const registry = new ReportTemplateRegistry();

// Create expensive base templates once
const salesReport = new ReportTemplate('Sales Report', 'pdf');
salesReport.addSection({ type: 'chart', data: 'sales' });
salesReport.addSection({ type: 'table', data: 'transactions' });

registry.register('sales', salesReport);

// Clone when needed (fast)
const q1Report = registry.create('sales');
q1Report.addSection({ type: 'summary', data: 'q1' });

const q2Report = registry.create('sales');
q2Report.addSection({ type: 'summary', data: 'q2' });
```

**Anti-Pattern**: Shallow cloning objects with nested references.

### Pattern 6: Factory with Dependency Injection

**When to Use**: Combining factory pattern with DI for testability

**Example**:
```typescript
// Interfaces
interface UserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<void>;
}

interface EmailService {
  send(to: string, subject: string, body: string): Promise<void>;
}

// Service that depends on abstractions
class UserService {
  constructor(
    private userRepo: UserRepository,
    private emailService: EmailService
  ) {}

  async createUser(data: CreateUserData): Promise<User> {
    const user = new User(data);
    await this.userRepo.save(user);
    await this.emailService.send(
      user.email,
      'Welcome!',
      'Thanks for signing up'
    );
    return user;
  }
}

// Factory that wires dependencies
class ServiceFactory {
  private userRepo: UserRepository;
  private emailService: EmailService;

  constructor(config: AppConfig) {
    // Create dependencies based on config
    this.userRepo = config.useDatabase === 'postgres'
      ? new PostgresUserRepository(config.dbUrl)
      : new MongoUserRepository(config.mongoUrl);

    this.emailService = config.emailProvider === 'sendgrid'
      ? new SendGridEmailService(config.sendgridKey)
      : new SESEmailService(config.awsConfig);
  }

  createUserService(): UserService {
    return new UserService(this.userRepo, this.emailService);
  }
}

// Testing with mock factory
class MockServiceFactory {
  userRepo = {
    findById: jest.fn(),
    save: jest.fn()
  };

  emailService = {
    send: jest.fn()
  };

  createUserService(): UserService {
    return new UserService(this.userRepo, this.emailService);
  }
}

// Test
describe('UserService', () => {
  it('should create user and send welcome email', async () => {
    const factory = new MockServiceFactory();
    const service = factory.createUserService();

    await service.createUser({ email: 'test@example.com', name: 'Test' });

    expect(factory.userRepo.save).toHaveBeenCalled();
    expect(factory.emailService.send).toHaveBeenCalledWith(
      'test@example.com',
      'Welcome!',
      expect.any(String)
    );
  });
});
```

**Anti-Pattern**: Factories that create concrete dependencies directly without abstraction.

## Checklist

- [ ] Factory used when object creation logic is complex
- [ ] Builder used for objects with many optional parameters
- [ ] Singleton avoided unless truly necessary
- [ ] Prototype used for expensive-to-create objects
- [ ] Dependencies injected rather than created directly
- [ ] Factories are testable with mock implementations
- [ ] Object creation separated from business logic
- [ ] Registry pattern used for extensible factories

## References

- [Design Patterns: Elements of Reusable Object-Oriented Software](https://www.amazon.com/Design-Patterns-Elements-Reusable-Object-Oriented/dp/0201633612)
- [Refactoring Guru - Creational Patterns](https://refactoring.guru/design-patterns/creational-patterns)
- [TypeScript Design Patterns](https://www.patterns.dev/posts)
