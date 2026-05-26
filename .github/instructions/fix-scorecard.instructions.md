---
applyTo: '*'
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
   The output lists each failing check ID, its category, and a link to the relevant section in `AGENTS.md` or the `.github/instructions/` files that explains the correct convention.

3. **Apply fixes** — for each failing check, read the referenced instruction section and apply the required changes to the module files. The check IDs and their fix locations are:

   | Check ID | Instruction Section |
   |----------|-------------------|
   | `buildingblock_dir`, `versions_tf`, `backplane` | `AGENTS.md#module-structure` |
   | `meshstack_integration`, `backplane_source_hub_git_ref`, `ref_name_hub_git_ref` | `AGENTS.md#meshstack_integrationtf-conventions` |
   | `required_providers_meshstack` | `AGENTS.md#required-providers` |
   | `variable_hub`, `variable_meshstack`, `variable_hub_const`, `bbd_draft`, `bbd_tags_forwarded` | `AGENTS.md#shared-variable-conventions` |
   | `output_bbd` | `AGENTS.md#exposing-building-block-definition-references` |
   | `provider_pinned` | `AGENTS.md#variable-conventions` |
   | `readme_frontmatter`, `logo`, `bbd_readme` | `AGENTS.md#documentation-requirements` |
   | `e2e_tests`, `e2e_tftest` | `AGENTS.md#end-to-end-testing` |
   | `azure_uses_uami`, `azure_federated_identity_credential` | `.github/instructions/azure-backplane.instructions.md#implementation-pattern` |
   | `azure_no_azuread_application`, `azure_no_spn`, `azure_no_app_password`, `azure_no_create_spn_toggle` | `.github/instructions/azure-backplane.instructions.md#what-to-avoid` |
   | `azure_wif_nonnullable` | `.github/instructions/azure-backplane.instructions.md#backplane-variables-azure` |
   | `azure_identity_output` | `.github/instructions/azure-backplane.instructions.md#backplane-outputs-azure` |
   | `azure_integration_rg_location` | `.github/instructions/azure-backplane.instructions.md#meshstack_integrationtf-wiring-azure` |

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
