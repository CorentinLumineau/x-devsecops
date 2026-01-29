# Web Performance Reference

Core Web Vitals and frontend optimization techniques.

## Core Web Vitals

### Largest Contentful Paint (LCP)

Target: **< 2.5 seconds**. Measures loading performance of the largest visible element.

```html
<!-- Preload critical hero image -->
<link rel="preload" as="image" href="/hero.webp" fetchpriority="high" />

<!-- Use responsive images -->
<img
  src="hero-800.webp"
  srcset="hero-400.webp 400w, hero-800.webp 800w, hero-1200.webp 1200w"
  sizes="(max-width: 600px) 400px, (max-width: 1000px) 800px, 1200px"
  alt="Hero image"
  fetchpriority="high"
  decoding="async"
/>
```

Key optimizations:
- Preload LCP element (`<link rel="preload">`)
- Use `fetchpriority="high"` on LCP image
- Eliminate render-blocking CSS/JS
- Server-side render above-the-fold content

### Interaction to Next Paint (INP)

Target: **< 200ms**. Measures responsiveness to user interactions.

```typescript
// BAD: Long task blocks main thread
button.addEventListener('click', () => {
  processLargeDataset(data);  // 500ms blocking
  updateUI();
});

// GOOD: Break up long tasks
button.addEventListener('click', async () => {
  updateUI();  // Immediate visual feedback

  // Yield to main thread between chunks
  for (const chunk of chunks(data, 100)) {
    await scheduler.yield();  // or setTimeout(0)
    processChunk(chunk);
  }
});
```

### Cumulative Layout Shift (CLS)

Target: **< 0.1**. Measures visual stability.

```css
/* Always set dimensions on media */
img, video {
  width: 100%;
  height: auto;
  aspect-ratio: 16 / 9;
}

/* Reserve space for dynamic content */
.ad-slot {
  min-height: 250px;
}

/* Avoid layout-triggering animations */
.animate {
  /* BAD: triggers layout */
  /* top: 10px; width: 200px; */

  /* GOOD: compositor-only */
  transform: translateY(10px);
  opacity: 0.8;
}
```

## Lazy Loading

```html
<!-- Native lazy loading for images -->
<img src="photo.webp" loading="lazy" alt="Photo" />

<!-- Intersection Observer for components -->
<script>
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      loadComponent(entry.target);
      observer.unobserve(entry.target);
    }
  });
}, { rootMargin: '200px' });

document.querySelectorAll('[data-lazy]').forEach(el => observer.observe(el));
</script>
```

## Code Splitting

```typescript
// Route-based splitting (React)
const Dashboard = React.lazy(() => import('./Dashboard'));
const Settings = React.lazy(() => import('./Settings'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
      </Routes>
    </Suspense>
  );
}

// Component-level splitting
const HeavyChart = React.lazy(() => import('./HeavyChart'));

function Report({ showChart }) {
  return (
    <div>
      <Summary />
      {showChart && (
        <Suspense fallback={<ChartSkeleton />}>
          <HeavyChart />
        </Suspense>
      )}
    </div>
  );
}
```

## Bundle Optimization

### Tree Shaking

```typescript
// BAD: Imports entire library
import _ from 'lodash';
_.debounce(fn, 300);

// GOOD: Import specific function
import debounce from 'lodash/debounce';
debounce(fn, 300);
```

### Webpack/Vite Configuration

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          charts: ['d3', 'recharts'],
        },
      },
    },
  },
});
```

### Bundle Analysis

```bash
# Webpack
npx webpack-bundle-analyzer dist/stats.json

# Vite
npx vite-bundle-visualizer
```

## Image Optimization

| Format | Use Case | Browser Support |
|--------|----------|----------------|
| WebP | Photos, general | All modern |
| AVIF | Photos (better compression) | Chrome, Firefox |
| SVG | Icons, logos | All |
| PNG | Screenshots, transparency | All |

```html
<!-- Progressive enhancement with picture -->
<picture>
  <source srcset="photo.avif" type="image/avif" />
  <source srcset="photo.webp" type="image/webp" />
  <img src="photo.jpg" alt="Photo" loading="lazy" />
</picture>
```

## Resource Hints

```html
<head>
  <!-- DNS prefetch for third-party domains -->
  <link rel="dns-prefetch" href="//api.example.com" />

  <!-- Preconnect to critical origins -->
  <link rel="preconnect" href="https://fonts.googleapis.com" crossorigin />

  <!-- Prefetch next-page resources -->
  <link rel="prefetch" href="/next-page.js" />

  <!-- Preload critical resources -->
  <link rel="preload" href="/fonts/main.woff2" as="font" type="font/woff2" crossorigin />
</head>
```

## Font Optimization

```css
/* Use font-display for text visibility */
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: swap;          /* Show fallback immediately */
  unicode-range: U+0000-00FF;  /* Only Latin characters */
}
```

## Performance Budget

| Resource | Budget |
|----------|--------|
| Total JS (compressed) | < 200 KB |
| Total CSS (compressed) | < 50 KB |
| LCP image | < 100 KB |
| Web fonts | < 100 KB |
| Total page weight | < 1 MB |

## Common Pitfalls

- **Unoptimized images**: Largest single performance win; automate with build pipeline
- **Render-blocking resources**: Defer non-critical JS, inline critical CSS
- **Third-party scripts**: Audit with Lighthouse; load async or defer
- **No compression**: Enable Brotli/gzip at server or CDN level
- **Layout thrashing**: Batch DOM reads before writes; use `requestAnimationFrame`
- **Missing resource hints**: Preconnect to API domains; prefetch likely navigation targets
