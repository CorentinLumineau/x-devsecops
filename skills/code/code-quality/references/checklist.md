# Code Quality Checklist

> Validation checklist for code-quality skill

## Before Completion

All gates must pass:

### Type Safety
- [ ] No `any` types (TypeScript)
- [ ] No type assertions without justification
- [ ] Proper null/undefined handling

### Code Structure
- [ ] Functions under 30 lines
- [ ] Cyclomatic complexity < 10
- [ ] No commented-out code
- [ ] No debug statements (console.log, print)

### Completeness
- [ ] No TODO comments in production paths
- [ ] No placeholder implementations
- [ ] No "Not implemented" errors
- [ ] All edge cases handled

### SOLID Compliance
- [ ] Single Responsibility - one reason to change
- [ ] Open/Closed - extensible without modification
- [ ] Liskov Substitution - subtypes work everywhere
- [ ] Interface Segregation - no unused dependencies
- [ ] Dependency Inversion - abstractions over concretions

### Simplicity (DRY/KISS/YAGNI)
- [ ] No duplicated logic (extract to shared)
- [ ] Simplest solution that works
- [ ] No unused code or features
- [ ] Only what was requested

## Quick Reference

**Positive Framing:**

| Instead of | Do |
|------------|-----|
| "Don't use any" | "Use specific types for safety" |
| "No TODOs" | "Complete all implementations" |
| "Don't duplicate" | "Extract shared logic to utilities" |
| "No long functions" | "Keep functions focused (< 30 lines)" |
