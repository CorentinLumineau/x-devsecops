# Eval-Driven Development (EDD)

> Write evals before AI-assisted implementation — measure what matters, not just what compiles.

Adapted from everything-claude-code (MIT, Copyright 2026 Affaan Mustafa).

## Core Principle

EDD extends TDD for AI-assisted development. Where TDD validates **correctness** (does it work?), EDD validates **quality** (does it work *well enough*?). Both are mandatory — EDD does not replace TDD.

## Eval Types

| Type | What It Measures | When to Use |
|------|-----------------|-------------|
| **Correctness** | Expected output matches actual | Every AI-generated function |
| **Quality** | Output meets qualitative bar | NLP, summarization, creative tasks |
| **Performance** | Latency, throughput, resource usage | API endpoints, data pipelines |
| **Regression** | No degradation from baseline | After refactoring AI-assisted code |

## Three Graders

| Grader | Method | Best For |
|--------|--------|----------|
| **Exact match** | `output === expected` | Deterministic functions, parsers |
| **LLM-as-judge** | Claude evaluates quality (0-10 scale) | Subjective outputs, summaries |
| **Human review** | Developer scores output | Edge cases, nuanced judgment |

## Pass@k Metric

Run k independent generations, check if at least one passes:

```
pass@k = 1 - C(n-c, k) / C(n, k)
```

Where n = total samples, c = correct samples. Use pass@1 for production, pass@5 for development iteration.

## Eval File Convention

Place eval definitions in `.claude/evals/`:

```
.claude/evals/
├── auth-flow.eval.md        # Auth module evals
├── api-validation.eval.md   # Input validation evals
└── data-transform.eval.md   # Transform pipeline evals
```

### Eval Definition Format

```markdown
## Eval: {name}

**Type**: correctness | quality | performance | regression
**Grader**: exact-match | llm-judge | human-review
**Threshold**: pass@1 ≥ 95% | quality ≥ 7/10 | latency < 200ms

### Test Cases
1. Input: {...} → Expected: {...}
2. Input: {...} → Expected: {...}

### Baseline (if regression)
Previous score: X | Date: YYYY-MM-DD
```

## Integration with TDD

```
1. Write eval definition (.claude/evals/)     ← EDD
2. Write failing test (test file)              ← TDD Red
3. Implement with AI assistance                ← TDD Green
4. Run eval suite to validate quality          ← EDD verify
5. Refactor while keeping evals + tests green  ← TDD Refactor
```

## When to Use EDD

| Scenario | EDD Required? |
|----------|--------------|
| AI writes a pure function | Yes — correctness eval |
| AI generates user-facing text | Yes — quality eval (LLM-judge) |
| AI refactors existing code | Yes — regression eval |
| Human writes simple config | No — TDD sufficient |
| AI writes tests themselves | Yes — eval the eval (meta-eval) |

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Eval after implementation | Write eval FIRST (V-TEST-08) |
| Only correctness evals | Add quality + performance for AI output |
| No baseline for regression | Record baseline before refactoring |
| Eval threshold too low | Start strict, relax with evidence |
| Skipping eval for "simple" AI code | All AI-generated code gets evals |
