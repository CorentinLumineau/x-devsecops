# Testing Pyramid Reference

> Distribution targets and test type guidelines

## Distribution Targets

| Type | Target | When to Use |
|------|--------|-------------|
| **Unit** | 70% | Pure functions, business logic, utilities |
| **Integration** | 20% | API endpoints, database operations, service chains |
| **E2E** | 10% | Critical user flows, happy paths only |

## Test Type Guidelines

### Unit Tests (70%)

Fast, isolated, no external dependencies:
- Test single function/method
- Mock all dependencies
- Cover edge cases
- Run in milliseconds

```typescript
// Example: Business logic test
describe('calculateDiscount', () => {
  it('applies 15% for orders over $100', () => {
    expect(calculateDiscount(150)).toBe(22.5);
  });
});
```

### Integration Tests (20%)

Test component interactions:
- Real database (test instance)
- Real API calls (internal)
- Service-to-service communication

```typescript
// Example: API endpoint test
describe('POST /api/orders', () => {
  it('creates order and updates inventory', async () => {
    const response = await request(app)
      .post('/api/orders')
      .send({ productId: 1, quantity: 2 });
    expect(response.status).toBe(201);
  });
});
```

### E2E Tests (10%)

Critical user journeys only:
- Login → Action → Logout
- Purchase flow
- Core business workflows

```typescript
// Example: Playwright E2E
test('user can complete checkout', async ({ page }) => {
  await page.goto('/products');
  await page.click('[data-testid="add-to-cart"]');
  await page.click('[data-testid="checkout"]');
  await expect(page.locator('.confirmation')).toBeVisible();
});
```

## Iterative Fix Pattern

```
Test Run 1: 45/50 passing
├─ Analyze: 3 JWT errors (same root cause), 2 timing issues
├─ Fix: JWT configuration
└─ Re-run: 48/50 passing

Test Run 2: 48/50 passing
├─ Analyze: 2 async timing issues
├─ Fix: Add await/proper async handling
└─ Re-run: 50/50 passing ✅
```

## Quality Command

```bash
make test:llm
```
