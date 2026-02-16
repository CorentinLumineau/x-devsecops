# Anti-Rationalization Reference

> Centralized excuse/reality tables by enforcement category. Referenced by x-implement, x-verify, and x-review hard gates.

## Why This Reference Exists

LLM agents rationalize shortcuts using the same patterns humans do. Research shows that **naming the excuse before the agent uses it** dramatically reduces shortcut-taking (Cialdini 2021, Meincke et al. 2025, N=28,000). This reference provides the excuse/reality pairs organized by enforcement category.

> **Foundational principle**: "Violating the letter IS violating the spirit." There is no case where following the rule technically but not actually is acceptable.

---

## TDD Rationalizations

| Excuse | Reality | Violation |
|--------|---------|-----------|
| "The code is trivial" | Trivial code gets trivial tests. Still mandatory. | V-TEST-02 |
| "I will add tests after" | TDD means tests FIRST. "After" is not TDD. | V-TEST-02 |
| "Running low on context" | Stop coding. Write the test. Resume after. | V-TEST-01 |
| "This is just a refactor" | Refactors need tests to prove behavior unchanged. | V-TEST-01 |
| "The existing tests cover this" | New behavior needs new tests. Existing tests cover old behavior. | V-TEST-01 |
| "It's a one-line change" | One-line changes can break systems. Test it. | V-TEST-02 |

---

## SOLID Rationalizations

| Excuse | Reality | Violation |
|--------|---------|-----------|
| "This class needs to do both things" | That's the definition of SRP violation. Split it. | V-SOLID-01 |
| "It's simpler to put it all in one place" | Simpler now, unmaintainable later. SRP exists for a reason. | V-SOLID-01 |
| "Adding an interface would be over-engineering" | If there's a dependency, there should be an abstraction. | V-SOLID-05 |
| "Nobody else will extend this" | OCP isn't about prediction — it's about making extension possible. | V-SOLID-02 |
| "The subclass works fine here" | Does it honor the contract? LSP requires behavioral compatibility. | V-SOLID-03 |

---

## Documentation Rationalizations

| Excuse | Reality | Violation |
|--------|---------|-----------|
| "The code is self-documenting" | Public APIs need explicit documentation. Always. | V-DOC-01 |
| "I'll update docs in a follow-up" | Stale docs are worse than no docs. Update now. | V-DOC-01 |
| "The behavior didn't really change" | If the signature changed, the docs must change. | V-DOC-04 |
| "Nobody reads the docs" | Agents read docs. Humans read docs. Keep them current. | V-DOC-02 |

---

## Verification Rationalizations

| Excuse | Reality | Violation |
|--------|---------|-----------|
| "Tests should pass" | "Should" is a prediction. Run them and prove it. | V-TEST-07 |
| "Based on the code, tests will pass" | Code reading ≠ test execution. Run the tests. | V-TEST-07 |
| "I only changed a comment" | Comments can break parsers, YAML, JSDoc. Run the gates. | V-TEST-07 |
| "This is a documentation-only change" | Doc changes can break builds (imports, links). Run the gates. | V-TEST-07 |
| "The same pattern works elsewhere" | Patterns have edge cases. Run the gates. | V-TEST-07 |
| "I'll verify after the next change" | Deferred verification = skipped verification. Verify NOW. | V-TEST-07 |
| "Running tests would take too long" | Skipping tests costs more than running them. Run the gates. | V-TEST-07 |
| "Coverage is probably fine" | Measure it. "Probably" is not a number. | V-TEST-03 |

---

## Review Rationalizations

| Excuse | Reality | Violation |
|--------|---------|-----------|
| "Overall the code looks good" | Review is checklist-driven, not impression-driven. | V-PARETO-01 |
| "These issues are cosmetic" | Check the severity table. CRITICAL/HIGH are never cosmetic. | V-PARETO-01 |
| "The user seems in a hurry" | Quality gates protect users from their own urgency. | V-PARETO-01 |
| "It's just a small change" | Small changes with CRITICAL violations are still CRITICAL. | V-PARETO-01 |
| "We can fix this in the next PR" | Known violations don't get deferred. Fix now or document exception. | V-PARETO-02 |

---

## Red Flag Self-Check

Before proceeding past ANY gate, ask yourself these 5 questions:

1. **Am I claiming success without showing output?**
   → If yes, go back and run the command. Read the output. Quote it.

2. **Am I skipping a step because it "probably" works?**
   → If yes, "probably" means "not verified." Run the step.

3. **Am I rationalizing why this case is "different"?**
   → If yes, check the tables above. Your excuse is probably listed.

4. **Am I following the spirit of the gate, or just the letter?**
   → If you're looking for a loophole, you've already failed the gate.

5. **Would I approve this if reviewing someone else's work?**
   → If no, don't approve your own either. Same standard applies.

---

## Integration

This reference is loaded on demand by:
- `x-implement` — TDD hard gate (Phase 2)
- `x-verify` — Coverage hard gate (Phase 3)
- `x-review` — Approval hard gate (Phase 3)

Each skill's Critical Rules section includes a cross-reference:
```
See @skills/code-code-quality/references/anti-rationalization.md
```
