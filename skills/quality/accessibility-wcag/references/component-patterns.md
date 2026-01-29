# Accessible Component Patterns Reference

Production patterns for common UI components meeting WCAG 2.1 AA.

## Accessible Forms

```html
<!-- Label association -->
<label for="email">Email address</label>
<input id="email" type="email" aria-required="true" autocomplete="email" />

<!-- Group related fields -->
<fieldset>
  <legend>Shipping Address</legend>
  <label for="street">Street</label>
  <input id="street" type="text" autocomplete="street-address" />
  <label for="city">City</label>
  <input id="city" type="text" autocomplete="address-level2" />
</fieldset>

<!-- Error handling -->
<label for="password">Password</label>
<input
  id="password"
  type="password"
  aria-invalid="true"
  aria-describedby="pw-error pw-hint"
  aria-required="true"
/>
<span id="pw-error" role="alert">Password must be at least 8 characters</span>
<span id="pw-hint">Use letters, numbers, and symbols</span>
```

### Form Validation Pattern

```typescript
function validateForm(form: HTMLFormElement): void {
  const errors: Map<string, string> = new Map();

  // Validate fields
  for (const field of form.elements) {
    if (field instanceof HTMLInputElement) {
      const error = validateField(field);
      if (error) {
        errors.set(field.id, error);
        field.setAttribute('aria-invalid', 'true');
        field.setAttribute('aria-describedby', `${field.id}-error`);
      } else {
        field.removeAttribute('aria-invalid');
      }
    }
  }

  // Announce error summary
  if (errors.size > 0) {
    const summary = document.getElementById('error-summary')!;
    summary.textContent = `${errors.size} errors found. Please correct them.`;
    summary.focus(); // Move focus to summary
  }
}
```

## Modal / Dialog

```html
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="dialog-title"
  aria-describedby="dialog-desc"
>
  <h2 id="dialog-title">Confirm Delete</h2>
  <p id="dialog-desc">This action cannot be undone.</p>
  <button>Cancel</button>
  <button>Delete</button>
</div>
```

```typescript
class AccessibleModal {
  private previousFocus: HTMLElement | null = null;
  private focusableElements: HTMLElement[] = [];

  open(modal: HTMLElement): void {
    this.previousFocus = document.activeElement as HTMLElement;
    modal.hidden = false;

    // Trap focus
    this.focusableElements = Array.from(
      modal.querySelectorAll<HTMLElement>(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
      )
    );

    // Focus first element
    this.focusableElements[0]?.focus();

    // Handle tab trapping
    modal.addEventListener('keydown', this.handleKeydown);

    // Prevent background scroll
    document.body.style.overflow = 'hidden';
  }

  close(modal: HTMLElement): void {
    modal.hidden = true;
    modal.removeEventListener('keydown', this.handleKeydown);
    document.body.style.overflow = '';

    // Restore focus
    this.previousFocus?.focus();
  }

  private handleKeydown = (e: KeyboardEvent): void => {
    if (e.key === 'Escape') {
      this.close(e.currentTarget as HTMLElement);
      return;
    }

    if (e.key !== 'Tab') return;

    const first = this.focusableElements[0];
    const last = this.focusableElements[this.focusableElements.length - 1];

    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  };
}
```

## Tabs

```html
<div class="tabs">
  <div role="tablist" aria-label="Account settings">
    <button role="tab" aria-selected="true" aria-controls="panel-general" id="tab-general">
      General
    </button>
    <button role="tab" aria-selected="false" aria-controls="panel-security" id="tab-security" tabindex="-1">
      Security
    </button>
  </div>

  <div role="tabpanel" id="panel-general" aria-labelledby="tab-general">
    General settings content
  </div>
  <div role="tabpanel" id="panel-security" aria-labelledby="tab-security" hidden>
    Security settings content
  </div>
</div>
```

Keyboard: Arrow Left/Right to switch tabs, Home/End for first/last, Enter/Space to activate.

```typescript
function handleTabKeydown(e: KeyboardEvent, tabs: HTMLElement[]): void {
  const current = tabs.indexOf(e.target as HTMLElement);
  let next: number;

  switch (e.key) {
    case 'ArrowRight': next = (current + 1) % tabs.length; break;
    case 'ArrowLeft': next = (current - 1 + tabs.length) % tabs.length; break;
    case 'Home': next = 0; break;
    case 'End': next = tabs.length - 1; break;
    default: return;
  }

  e.preventDefault();
  activateTab(tabs[next]);
}

function activateTab(tab: HTMLElement): void {
  // Deactivate all
  const tablist = tab.closest('[role="tablist"]')!;
  tablist.querySelectorAll('[role="tab"]').forEach(t => {
    t.setAttribute('aria-selected', 'false');
    t.setAttribute('tabindex', '-1');
    const panel = document.getElementById(t.getAttribute('aria-controls')!);
    panel?.setAttribute('hidden', '');
  });

  // Activate selected
  tab.setAttribute('aria-selected', 'true');
  tab.removeAttribute('tabindex');
  tab.focus();
  const panel = document.getElementById(tab.getAttribute('aria-controls')!);
  panel?.removeAttribute('hidden');
}
```

## Data Tables

```html
<table>
  <caption>Monthly Sales Report</caption>
  <thead>
    <tr>
      <th scope="col">Product</th>
      <th scope="col">Q1</th>
      <th scope="col">Q2</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row">Widget A</th>
      <td>1,200</td>
      <td>1,450</td>
    </tr>
  </tbody>
</table>

<!-- Sortable table header -->
<th scope="col" aria-sort="ascending">
  <button>
    Name
    <span aria-hidden="true">▲</span>
  </button>
</th>
```

## Navigation Menu

```html
<nav aria-label="Main navigation">
  <ul>
    <li><a href="/" aria-current="page">Home</a></li>
    <li>
      <button aria-expanded="false" aria-controls="products-menu">Products</button>
      <ul id="products-menu" hidden>
        <li><a href="/widgets">Widgets</a></li>
        <li><a href="/gadgets">Gadgets</a></li>
      </ul>
    </li>
    <li><a href="/about">About</a></li>
  </ul>
</nav>
```

## Skip Links

```html
<!-- First element in body -->
<a href="#main-content" class="skip-link">Skip to main content</a>

<header>...</header>
<nav>...</nav>
<main id="main-content" tabindex="-1">
  <!-- Page content -->
</main>
```

```css
.skip-link {
  position: absolute;
  left: -10000px;
  top: auto;
  width: 1px;
  height: 1px;
  overflow: hidden;
}

.skip-link:focus {
  position: fixed;
  top: 10px;
  left: 10px;
  width: auto;
  height: auto;
  padding: 8px 16px;
  background: #000;
  color: #fff;
  z-index: 10000;
}
```

## Carousel / Slider

```html
<div role="region" aria-roledescription="carousel" aria-label="Featured products">
  <div aria-live="polite">
    <div role="group" aria-roledescription="slide" aria-label="1 of 3">
      <img src="product1.jpg" alt="Blue widget — on sale for $19.99" />
    </div>
  </div>

  <button aria-label="Previous slide">‹</button>
  <button aria-label="Next slide">›</button>

  <!-- Dot indicators -->
  <div role="tablist" aria-label="Slides">
    <button role="tab" aria-selected="true" aria-label="Slide 1"></button>
    <button role="tab" aria-selected="false" aria-label="Slide 2"></button>
    <button role="tab" aria-selected="false" aria-label="Slide 3"></button>
  </div>
</div>
```

Key requirements:
- Pause auto-rotation on hover/focus
- Provide stop/play button if auto-advancing
- Announce current slide via `aria-live`

## Common Pitfalls

- **Missing focus management**: Opening modals/menus without moving focus
- **No keyboard support**: All interactive elements must work with keyboard alone
- **Empty alt text on meaningful images**: Use descriptive alt; empty `alt=""` only for decorative
- **`div` and `span` as buttons**: Use semantic `<button>` or `<a>` elements; if not possible, add `role`, `tabindex`, and key handlers
- **Color as only indicator**: Combine color with text, icons, or patterns
- **Missing skip links**: Essential for keyboard users on content-heavy pages
- **Auto-playing media**: Always provide pause controls; prefer `prefers-reduced-motion`
