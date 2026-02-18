# Code Review Practices

PR review checklists, anti-patterns, and effective feedback guidelines.

## PR Review Checklist

| Category | Check |
|----------|-------|
| Correctness | Does the code do what it claims? |
| Design | Is the approach appropriate for the problem? |
| Naming | Are variables, functions, classes well-named? |
| Complexity | Is the code as simple as possible? |
| Tests | Are there adequate tests for the changes? |
| Consistency | Does it follow existing codebase patterns? |
| Security | Are there any security implications? |
| Performance | Are there obvious performance concerns? |

## Review Anti-Patterns

| Anti-Pattern | Better Approach |
|--------------|----------------|
| Rubber-stamping (approval without reading) | Allocate dedicated review time |
| Nitpicking style only | Focus on logic, design, correctness first |
| Blocking on preferences | Distinguish preferences from requirements |
| Reviewing too late | Review early, review often (draft PRs) |
| Huge PRs (>500 lines) | Break into focused, reviewable chunks |
| No context in PR description | Require clear description of what and why |

## Effective Feedback Guidelines

| Do | Avoid |
|----|-------|
| Ask questions to understand intent | Assume bad intent |
| Suggest alternatives with reasoning | Dictate without explanation |
| Distinguish "must fix" from "nit" | Treat all feedback as blocking |
| Praise good patterns | Only point out problems |
| Link to relevant standards/docs | Make unsubstantiated claims |
