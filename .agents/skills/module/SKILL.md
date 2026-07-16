---
name: module
description: >
  Create or update a meshstack-hub building block module. Covers the full lifecycle: module
  structure, backplane identity (per cloud provider), BBD readme, and scorecard compliance.
  Use when asked to create a new module, add or fix a backplane, write the readme, or resolve
  scorecard violations.
---

# Module Skill

This skill drives two workflows: **creating** a new building block module and **keeping modules up
to date** with the latest conventions (scorecard fixes). For backplane identity details and readme
conventions, see the reference files in `.agents/references/`.

---

## Workflow: Creating a New Module

1. **Determine scope** — identify the cloud provider and service name → module path `modules/<provider>/<service>/`

2. **Create the directory structure** (AGENTS.md § Module Structure):
   ```
   modules/<provider>/<service>/
   ├── backplane/          # omit if no cloud-side setup needed
   ├── buildingblock/
   └── meshstack_integration.tf
   ```

3. **Implement `buildingblock/`** — `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `provider.tf`, `README.md` (with YAML front-matter), `logo.png`

4. **Implement `backplane/`** (if needed) — read the provider-specific reference:
   - AWS → `.agents/references/aws-backplane.md`
   - Azure → `.agents/references/azure-backplane.md`
   - STACKIT → `.agents/references/stackit-backplane.md`

5. **Write the BBD readme** → `.agents/references/bbd-readme.md`

6. **Write `meshstack_integration.tf`** — follow AGENTS.md § `meshstack_integration.tf` Conventions
   - Always add `lifecycle { ignore_changes = [ availability ] }` to every `meshstack_platform` resource (see AGENTS.md § `meshstack_platform` Lifecycle)

7. **Validate**:
   ```sh
   terraform validate   # in buildingblock/ and backplane/ if present
   ```

8. **Run scorecard** and iterate until all checks pass:
   ```sh
   tools/scorecard/scorecard.mjs --module=<provider>/<service>
   ```

---

## Workflow: Fixing Scorecard Violations

1. **Identify violations**:
   ```sh
   tools/scorecard/scorecard.mjs --module=<provider>/<service>
   ```

2. **Get fix hints** — structured list of failing checks with references to the relevant docs:
   ```sh
   tools/scorecard/scorecard.mjs --module=<provider>/<service> --fix
   ```

3. **Apply fixes** — for each failing check, read the referenced section and fix the module. Work category by category: **Core → Integration → Azure Backplane → Testing**.

4. **Verify** after each category:
   ```sh
   tools/scorecard/scorecard.mjs --module=<provider>/<service>
   ```
   Repeat until all checks show ✅.

5. **Commit**:
   ```
   fix(<provider>/<service>): resolve scorecard violations
   ```

### Scorecard fix notes

- **`logo` check**: requires `buildingblock/logo.png` (256×256 px, flat-design, white-background icon). Generate with an AI image tool if missing, then resize and optimise with `pngquant`.
- **`e2e_tests` / `e2e_tftest`**: creating a full e2e test is a larger task — check with the module owner before adding. See `.agents/skills/e2e-test/SKILL.md`.
- **Never** fix a check by editing the check logic in `scorecard.mjs` — fix the module.

---

## Key references

| Topic | Reference |
|---|---|
| Module structure & `meshstack_integration.tf` | AGENTS.md |
| Terraform/OpenTofu coding conventions | `.agents/references/terraform-conventions.md` |
| BBD readme | `.agents/references/bbd-readme.md` |
| AWS backplane identity | `.agents/references/aws-backplane.md` |
| Azure backplane identity | `.agents/references/azure-backplane.md` |
| STACKIT backplane identity | `.agents/references/stackit-backplane.md` |
| E2E tests | `.agents/skills/e2e-test/SKILL.md` |
