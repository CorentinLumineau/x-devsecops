---
name: accessibility-wcag
description: WCAG 2.1/2.2 compliance and accessibility best practices.
license: Apache-2.0
compatibility: Works with Claude Code, Cursor, Cline, and any skills.sh agent.
allowed-tools: Read Grep Glob
user-invocable: false
metadata:
  author: ccsetup contributors
  version: "1.0.0"
  category: quality
---

# Accessibility (WCAG)

Web Content Accessibility Guidelines compliance and best practices.

## 80/20 Focus

Master these (covers 80% of accessibility issues):

| Area | Impact | Common Issues |
|------|--------|---------------|
| Keyboard navigation | Critical | Missing focus, trap, order |
| Color contrast | High | Low contrast text, color-only info |
| Alt text | High | Missing/poor image descriptions |
| Form labels | High | Missing/incorrect associations |

## WCAG Conformance Levels

| Level | Requirement | Examples |
|-------|-------------|----------|
| A | Minimum | Alt text, keyboard access, no seizure triggers |
| AA | Standard | Contrast 4.5:1, resize text, focus visible |
| AAA | Enhanced | Contrast 7:1, sign language, extended audio |

**Target**: AA for most applications

## Core Principles (POUR)

### Perceivable
- Text alternatives for non-text content
- Captions for audio/video
- Sufficient color contrast
- Content readable without styles

### Operable
- All functionality keyboard-accessible
- No keyboard traps
- Skip navigation links
- Focus management

### Understandable
- Readable text (language declared)
- Predictable navigation
- Input assistance (labels, errors)

### Robust
- Valid HTML
- ARIA used correctly
- Works with assistive tech

## Keyboard Navigation

### Essential Patterns
```jsx
// Focus management after route change
useEffect(() => {
  const main = document.getElementById('main-content');
  main?.focus();
}, [location]);

// Skip link
<a href="#main-content" className="skip-link">
  Skip to main content
</a>
```

### Focus Order
```
Tab: Next focusable element
Shift+Tab: Previous element
Enter/Space: Activate
Arrow keys: Within components
Escape: Close/cancel
```

### Common Issues
- Focus not visible
- Illogical tab order
- Focus trapped in modals
- Missing skip links

## ARIA Patterns

### Roles
```html
<!-- Landmarks -->
<nav role="navigation">
<main role="main">
<aside role="complementary">
<footer role="contentinfo">

<!-- Widgets -->
<button aria-expanded="false" aria-controls="menu">
<div role="dialog" aria-modal="true" aria-labelledby="title">
```

### States
```html
aria-expanded="true|false"
aria-selected="true|false"
aria-disabled="true|false"
aria-hidden="true|false"
aria-current="page|step|location"
```

### Properties
```html
aria-label="Description"
aria-labelledby="element-id"
aria-describedby="element-id"
aria-live="polite|assertive"
aria-controls="element-id"
```

### First Rule of ARIA
> Don't use ARIA if native HTML provides the same functionality

```html
<!-- Bad: ARIA on div -->
<div role="button" tabindex="0" aria-pressed="false">Click</div>

<!-- Good: Native button -->
<button aria-pressed="false">Click</button>
```

## Color Contrast

### Requirements (AA)

| Text Type | Minimum Ratio |
|-----------|---------------|
| Normal text | 4.5:1 |
| Large text (18pt+) | 3:1 |
| UI components | 3:1 |
| Graphical objects | 3:1 |

### Testing
```bash
# Chrome DevTools
# Elements > Accessibility > Contrast

# CLI tools
npm install -g pa11y
pa11y https://example.com
```

## Form Accessibility

### Labels
```html
<!-- Explicit association -->
<label for="email">Email</label>
<input id="email" type="email" />

<!-- Implicit association -->
<label>
  Email
  <input type="email" />
</label>
```

### Error Handling
```html
<input
  id="email"
  type="email"
  aria-invalid="true"
  aria-describedby="email-error"
/>
<span id="email-error" role="alert">
  Please enter a valid email
</span>
```

### Required Fields
```html
<input id="name" required aria-required="true" />
<span aria-hidden="true">*</span>
```

## Testing Tools

| Tool | Type | Use For |
|------|------|---------|
| axe-core | Automated | CI integration |
| WAVE | Browser | Quick scan |
| Lighthouse | Browser | Audit score |
| NVDA/VoiceOver | Manual | Screen reader |
| Keyboard | Manual | Focus testing |

### Automated Testing
```javascript
// Jest + axe
import { axe } from 'jest-axe';

test('accessible', async () => {
  const { container } = render(<MyComponent />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

## Checklist

### Minimum (Level A)
- [ ] All images have alt text
- [ ] All form inputs have labels
- [ ] All functionality keyboard-accessible
- [ ] No keyboard traps
- [ ] Language declared
- [ ] No auto-playing media

### Standard (Level AA)
- [ ] Color contrast 4.5:1 minimum
- [ ] Text resizable to 200%
- [ ] Focus visible
- [ ] Consistent navigation
- [ ] Error suggestions
- [ ] Multiple ways to find content

## When to Load References

- **For ARIA patterns**: See `references/aria-patterns.md`
- **For testing setup**: See `references/testing-tools.md`
- **For component patterns**: See `references/component-patterns.md`
