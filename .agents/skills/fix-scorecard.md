---
description: Workflow for fixing scorecard violations in meshstack-hub modules. Use when asked to fix scorecard checks, resolve violations, or improve module maturity scores.
---

# Fixing Scorecard Violations

When asked to fix scorecard violations for a module, follow this workflow:

## Workflow

1. **Identify violations** — run the scorecard for the target module:
   ```sh
   node tools/scorecard/scorecard.mjs --module=<provider>/<service>
   ```

2. **Get the fix prompt** — run with `--fix` to get a structured list of what to fix and where the instructions are:
   ```sh
   node tools/scorecard/scorecard.mjs --module=<provider>/<service> --fix
   ```
   The output lists each failing check ID, its category, and a link to the relevant section in `AGENTS.md` or the `.agents/skills/` files that explains the correct convention.

3. **Apply fixes** — for each failing check, read the referenced instruction section and apply the required changes to the module files.

4. **Verify** — re-run the scorecard after each set of fixes:
   ```sh
   node tools/scorecard/scorecard.mjs --module=<provider>/<service>
   ```
   Repeat until all checks show ✅.

5. **Commit** — once all checks pass, commit the changes with a message like:
   ```
   fix(<provider>/<service>): resolve scorecard violations
   ```

## Notes

- Fix one category at a time (Core → Integration → Azure Backplane → Testing) to avoid regressions.
- The `logo` check requires a `buildingblock/logo.png` file. If one is missing, generate one using an AI image generator with a flat-design, white-background icon that represents the service, then resize to 256×256 px and optimise with `pngquant`.
- The `e2e_tests` and `e2e_tftest` checks are aspirational — creating a full e2e test is a larger task. Check with the module owner before adding e2e tests.
- Do not mark any check as passing by changing the check logic in `scorecard.mjs`. Fix the module, not the check.
