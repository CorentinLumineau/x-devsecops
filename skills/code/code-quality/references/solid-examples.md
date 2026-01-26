# SOLID Examples

Detailed examples for each SOLID principle.

## Single Responsibility Principle (SRP)

### Bad: Multiple Responsibilities

```typescript
class UserManager {
  validateUser(user: User): boolean { /* validation */ }
  saveUser(user: User): Promise<void> { /* database */ }
  sendWelcomeEmail(user: User): Promise<void> { /* email */ }
}
```

### Good: Single Responsibility Each

```typescript
class UserValidator {
  validate(user: User): boolean { /* validation only */ }
}

class UserRepository {
  save(user: User): Promise<void> { /* database only */ }
}

class EmailService {
  sendWelcome(user: User): Promise<void> { /* email only */ }
}
```

## Open/Closed Principle (OCP)

### Bad: Must Modify to Extend

```typescript
class ReportGenerator {
  generate(type: string, data: any): string {
    if (type === 'PDF') return this.generatePDF(data)
    else if (type === 'Excel') return this.generateExcel(data)
    // Must add new else-if for every new type
  }
}
```

### Good: Extend Without Modification

```typescript
interface ReportGenerator {
  generate(data: any): string
}

class PDFReportGenerator implements ReportGenerator {
  generate(data: any): string { /* PDF logic */ }
}

class ExcelReportGenerator implements ReportGenerator {
  generate(data: any): string { /* Excel logic */ }
}

// Add new generators without touching existing code
class CSVReportGenerator implements ReportGenerator {
  generate(data: any): string { /* CSV logic */ }
}
```

## Liskov Substitution Principle (LSP)

### Bad: Subtype Breaks Expectations

```
Rectangle.setWidth(5)
Rectangle.setHeight(10)
Expected area: 50

Square (extends Rectangle):
Square.setWidth(5)  → sets BOTH to 5
Square.setHeight(10) → sets BOTH to 10
Area: 100 (WRONG!)
```

### Good: Use Common Interface

```typescript
interface Shape {
  getArea(): number
}

class Rectangle implements Shape {
  constructor(private width: number, private height: number) {}
  getArea(): number { return this.width * this.height }
}

class Square implements Shape {
  constructor(private size: number) {}
  getArea(): number { return this.size * this.size }
}
```

## Interface Segregation Principle (ISP)

### Bad: Fat Interface

```typescript
interface Worker {
  work(): void
  eat(): void
  sleep(): void
}

class Robot implements Worker {
  work() { /* OK */ }
  eat() { throw new Error('Robots don\'t eat') }  // Forced!
  sleep() { throw new Error('Robots don\'t sleep') }  // Forced!
}
```

### Good: Segregated Interfaces

```typescript
interface Workable { work(): void }
interface Eatable { eat(): void }
interface Sleepable { sleep(): void }

class Human implements Workable, Eatable, Sleepable {
  work() { /* ... */ }
  eat() { /* ... */ }
  sleep() { /* ... */ }
}

class Robot implements Workable {
  work() { /* ... */ }
  // Only implements what it needs
}
```

## Dependency Inversion Principle (DIP)

### Bad: High-Level Depends on Low-Level

```typescript
class UserService {
  private repo = new MySQLUserRepository()  // Direct dependency!

  async createUser(data: CreateUserData): Promise<User> {
    const user = new User(data)
    await this.repo.save(user)
    return user
  }
}
```

### Good: Both Depend on Abstraction

```typescript
interface IUserRepository {
  save(user: User): Promise<void>
}

class MySQLUserRepository implements IUserRepository { /* MySQL */ }
class PostgresUserRepository implements IUserRepository { /* Postgres */ }

class UserService {
  constructor(private repo: IUserRepository) {}  // Depends on abstraction

  async createUser(data: CreateUserData): Promise<User> {
    const user = new User(data)
    await this.repo.save(user)
    return user
  }
}

// Usage with dependency injection
const repo = new MySQLUserRepository()
const service = new UserService(repo)
```
