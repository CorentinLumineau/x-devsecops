# Accessibility Testing Tools Reference

Tools and techniques for automated and manual accessibility testing.

## axe-core

The most widely used accessibility testing engine.

### Unit/Integration Testing

```typescript
// Jest + axe-core
import { axe, toHaveNoViolations } from 'jest-axe';
import { render } from '@testing-library/react';

expect.extend(toHaveNoViolations);

test('form has no accessibility violations', async () => {
  const { container } = render(<LoginForm />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});

// With specific rules
test('navigation meets WCAG AA', async () => {
  const { container } = render(<Navigation />);
  const results = await axe(container, {
    runOnly: {
      type: 'tag',
      values: ['wcag2a', 'wcag2aa'],
    },
  });
  expect(results).toHaveNoViolations();
});
```

### Playwright Integration

```typescript
import AxeBuilder from '@axe-core/playwright';

test('page is accessible', async ({ page }) => {
  await page.goto('/dashboard');

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .exclude('.third-party-widget')
    .analyze();

  expect(results.violations).toEqual([]);
});

// Check specific component
test('modal dialog is accessible', async ({ page }) => {
  await page.click('[data-testid="open-modal"]');

  const results = await new AxeBuilder({ page })
    .include('.modal-dialog')
    .analyze();

  expect(results.violations).toEqual([]);
});
```

### Cypress Integration

```typescript
// cypress/support/commands.ts
import 'cypress-axe';

// cypress/e2e/accessibility.cy.ts
describe('Accessibility', () => {
  it('home page passes axe', () => {
    cy.visit('/');
    cy.injectAxe();
    cy.checkA11y(null, {
      runOnly: {
        type: 'tag',
        values: ['wcag2a', 'wcag2aa'],
      },
    });
  });

  it('form page passes axe after interaction', () => {
    cy.visit('/form');
    cy.injectAxe();
    cy.get('#email').type('invalid');
    cy.get('form').submit();
    cy.checkA11y(); // Check after validation errors appear
  });
});
```

## Lighthouse Accessibility Audits

### CLI Usage

```bash
# Full accessibility audit
npx lighthouse http://localhost:3000 \
  --only-categories=accessibility \
  --output=json --output-path=./a11y-report.json

# CI-friendly with budget
npx lighthouse http://localhost:3000 \
  --only-categories=accessibility \
  --budget-path=./lighthouse-budget.json
```

### Budget File

```json
[{
  "path": "/*",
  "options": {
    "firstParty": "example.com"
  },
  "timings": [],
  "resourceSizes": [],
  "resourceCounts": [],
  "audits": {
    "accessibility": { "minScore": 0.95 }
  }
}]
```

## pa11y

### CLI and CI

```bash
# Single page test
npx pa11y http://localhost:3000

# With specific standard
npx pa11y --standard WCAG2AA http://localhost:3000

# CI configuration file
npx pa11y-ci
```

### pa11y-ci Configuration

```json
{
  "defaults": {
    "standard": "WCAG2AA",
    "timeout": 10000,
    "wait": 1000,
    "ignore": ["WCAG2AA.Principle1.Guideline1_4.1_4_3.G18.Fail"]
  },
  "urls": [
    "http://localhost:3000/",
    "http://localhost:3000/login",
    {
      "url": "http://localhost:3000/dashboard",
      "actions": [
        "set field #email to user@test.com",
        "set field #password to password",
        "click element #login-btn",
        "wait for url to be http://localhost:3000/dashboard"
      ]
    }
  ]
}
```

## Screen Reader Testing

### NVDA (Windows)

Key commands for testing:
| Action | Shortcut |
|--------|----------|
| Read current element | Insert + Tab |
| Next heading | H |
| Next landmark | D |
| List all headings | Insert + F7 |
| Forms mode | Enter (on form field) |
| Browse mode | Escape |

### VoiceOver (macOS)

Key commands for testing:
| Action | Shortcut |
|--------|----------|
| Toggle VoiceOver | Cmd + F5 |
| Next element | VO + Right |
| Activate | VO + Space |
| Rotor (landmarks, headings) | VO + U |
| Read page | VO + A |

### Manual Testing Checklist

1. **Tab through entire page** — logical order, no traps
2. **Screen reader announces** — all content, form labels, errors
3. **Headings hierarchy** — h1 > h2 > h3, no skipped levels
4. **Landmarks** — main, nav, header, footer, form labels
5. **Images** — meaningful alt text or empty alt for decorative
6. **Forms** — labels associated, errors announced, required indicated
7. **Dynamic content** — live regions announce updates

## CI Integration

### GitHub Actions

```yaml
name: Accessibility
on: [pull_request]

jobs:
  a11y:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4

      - run: npm ci
      - run: npm run build
      - run: npm start &

      - name: axe scan
        run: npx @axe-core/cli http://localhost:3000 --exit

      - name: Lighthouse
        uses: treosh/lighthouse-ci-action@v11
        with:
          urls: http://localhost:3000
          budgetPath: ./lighthouse-budget.json
```

## Tool Comparison

| Tool | Type | Best For | WCAG Coverage |
|------|------|----------|---------------|
| axe-core | Engine | Unit/integration tests | ~57% of WCAG |
| Lighthouse | Audit | CI scoring | Subset of axe |
| pa11y | Runner | Page-level scans | HTML CodeSniffer rules |
| NVDA/VoiceOver | Manual | Real user experience | 100% (human judgment) |

## Common Pitfalls

- **Relying only on automated tools**: They catch ~30-50% of issues; manual testing is essential
- **Testing only the happy path**: Check error states, loading states, empty states
- **Ignoring keyboard navigation**: Tab order, focus management, skip links
- **Not testing with real screen readers**: Automated tools miss announcement quality
- **Running axe only on initial render**: Test after interactions (modals, form validation, dynamic content)
- **Skipping color contrast**: Use browser devtools or dedicated contrast checkers
