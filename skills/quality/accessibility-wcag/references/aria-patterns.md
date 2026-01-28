# ARIA Patterns Reference

Common ARIA patterns for accessible components.

## Dialog/Modal

```html
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="dialog-title"
  aria-describedby="dialog-desc"
>
  <h2 id="dialog-title">Confirm Action</h2>
  <p id="dialog-desc">Are you sure you want to proceed?</p>
  <button>Cancel</button>
  <button>Confirm</button>
</div>
```

### Focus Management
```javascript
// On open: focus first focusable element
// On close: return focus to trigger
const trigger = document.activeElement;
modal.open();
modal.querySelector('button').focus();

modal.addEventListener('close', () => {
  trigger.focus();
});
```

## Tabs

```html
<div role="tablist" aria-label="Settings">
  <button role="tab" aria-selected="true" aria-controls="panel-1" id="tab-1">
    General
  </button>
  <button role="tab" aria-selected="false" aria-controls="panel-2" id="tab-2">
    Privacy
  </button>
</div>

<div role="tabpanel" id="panel-1" aria-labelledby="tab-1">
  General settings content
</div>
<div role="tabpanel" id="panel-2" aria-labelledby="tab-2" hidden>
  Privacy settings content
</div>
```

### Keyboard Navigation
- Arrow Left/Right: Move between tabs
- Home: First tab
- End: Last tab
- Enter/Space: Activate tab

## Menu/Dropdown

```html
<button
  aria-haspopup="menu"
  aria-expanded="false"
  aria-controls="menu-1"
>
  Options
</button>

<ul role="menu" id="menu-1" hidden>
  <li role="menuitem">Edit</li>
  <li role="menuitem">Delete</li>
  <li role="separator"></li>
  <li role="menuitem">Settings</li>
</ul>
```

## Accordion

```html
<div>
  <h3>
    <button
      aria-expanded="true"
      aria-controls="section-1"
    >
      Section 1
    </button>
  </h3>
  <div id="section-1" role="region" aria-labelledby="heading-1">
    Content for section 1
  </div>
</div>
```

## Live Regions

```html
<!-- Polite: Announced when user is idle -->
<div aria-live="polite" aria-atomic="true">
  Form saved successfully
</div>

<!-- Assertive: Interrupts immediately -->
<div aria-live="assertive" role="alert">
  Error: Please fix the highlighted fields
</div>
```

## Autocomplete/Combobox

```html
<label for="search">Search</label>
<input
  id="search"
  type="text"
  role="combobox"
  aria-autocomplete="list"
  aria-expanded="true"
  aria-controls="results"
  aria-activedescendant="result-2"
/>

<ul id="results" role="listbox">
  <li id="result-1" role="option">Option 1</li>
  <li id="result-2" role="option" aria-selected="true">Option 2</li>
  <li id="result-3" role="option">Option 3</li>
</ul>
```

## Progress

```html
<!-- Determinate -->
<div
  role="progressbar"
  aria-valuenow="75"
  aria-valuemin="0"
  aria-valuemax="100"
  aria-label="Upload progress"
>
  75%
</div>

<!-- Indeterminate -->
<div
  role="progressbar"
  aria-label="Loading"
>
  Loading...
</div>
```

## Tooltip

```html
<button aria-describedby="tooltip-1">
  Save
</button>
<div id="tooltip-1" role="tooltip" hidden>
  Save your changes (Ctrl+S)
</div>
```

## Form Validation

```html
<label for="email">Email</label>
<input
  id="email"
  type="email"
  aria-required="true"
  aria-invalid="true"
  aria-describedby="email-error"
/>
<span id="email-error" role="alert">
  Please enter a valid email address
</span>
```
