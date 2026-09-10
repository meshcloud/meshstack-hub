---
description: Module layout and documentation requirements for meshstack-hub building blocks — the backplane/buildingblock two-tier structure, where logos live, buildingblock/README.md front-matter, which readme the app team reads (BBD readme field vs APP_TEAM_README.md), backplane/README.md, and the checklist for new modules.
---

# Module Layout and Documentation

<!-- scorecard-checks: buildingblock_dir, versions_tf, backplane -->
## Module Structure

Every module follows a two-tier layout. The `backplane` tier is optional and should be omitted for simple building blocks that require no cloud-side setup (e.g. those that receive all credentials as static inputs).

```
modules/<cloud-provider>/<service-name>/
├── backplane/          # optional — Infrastructure/permissions setup (run by platform team)
│   ├── main.tf         # Omit entirely for simple building blocks that need no cloud-side setup
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── README.md
├── buildingblock/      # Actual service resources (run by meshStack per tenant)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── provider.tf
│   ├── README.md          # YAML front-matter required (see below)
│   └── logo.png
├── e2e/                # optional — smoke test against a live meshStack (see the e2e-test skill)
└── meshstack_integration.tf   # Example wiring into a meshStack instance
```

The `modules/<cloud-provider>/` directory itself holds the platform's own `README.md` (front-matter
with `name` and `description`) and its `logo.png` or `logo.svg`.

**Logos are always named `logo.png` or `logo.svg`** and colocated with what they depict — platforms,
building blocks and reference architectures alike. The website generator copies them into its
generated asset directories under `website/public/assets/`; never add files there by hand.

<!-- scorecard-checks: readme_frontmatter, logo, app_team_readme, no_documentation_md_output -->
## Documentation Requirements

See [bbd-readme.md](bbd-readme.md) for the complete BBD readme specification, template, and checklist.

**`buildingblock/README.md`** — must include YAML front-matter:

```yaml
---
name: <Human-readable name>
supportedPlatforms:
  - <platform-id> # e.g. aws, azure, stackit
description: One-sentence description of what the module provisions.
requiresBackplane: false # optional — see below
---
```

`requiresBackplane: false` is optional and declares that the module needs no cloud-side setup, so
the scorecard treats the missing `backplane/` tier as not applicable instead of a gap. Only set it
for building blocks that genuinely provision nothing cloud-side (e.g. those receiving all
credentials as static inputs) — add a comment above it saying why.

**User-facing readme — two patterns depending on module completeness:**

- **Modules with `meshstack_integration.tf`** (full building blocks): user-facing readme lives in the `readme` field of `meshstack_building_block_definition.spec`. Always use `chomp(<<-EOT)` inline — never `file()` or a separate file (one-file copy/paste requirement). See [bbd-readme.md](bbd-readme.md) for full spec.

- **Modules without `meshstack_integration.tf`** (standalone building blocks): place the user-facing readme at `buildingblock/APP_TEAM_README.md`. meshStack uses this file as a fallback when no inline readme is available. The same content requirements apply (plain-text description first, usage motivation, examples, shared responsibility table).

The readme (inline or `APP_TEAM_README.md`) must include:

- A **plain-text description** as the first content — no leading `#` heading.
- **Usage motivation**: who this building block is for and when to use it.
- **Usage examples**: 1–2 concrete developer scenarios.
- **Shared responsibility matrix**: markdown table with `✅` / `❌` emojis.

**`backplane/README.md`** — documentation relevant to platform engineers deploying the backplane. Include an overview of what the backplane provisions, required permissions/roles, and operational notes.

**Anti-pattern: `documentation_md` output** — do **not** add a `documentation_md` output to backplane modules. This is a legacy pattern. Documentation must instead be split into:
- User-facing content → BBD `readme` field in `meshstack_integration.tf` (or `APP_TEAM_README.md` if no integration file)
- Platform-engineer-facing content → `backplane/README.md`

---

## Checklist for New Modules

- [ ] `backplane/` (optional) and `buildingblock/` with all required files
- [ ] `meshstack_integration.tf` present at the module root
- [ ] Provider versions float within one major (`>= X.Y.Z, < N.0.0`) in `versions.tf` and `meshstack_integration.tf` — `meshcloud/meshstack` keeps a bare `>=`
- [ ] Variables in `snake_case` with cloud-provider prefix in `meshstack_integration.tf` (e.g. `azure_tenant_id`)
- [ ] `buildingblock/README.md` with YAML front-matter
- [ ] BBD `readme` field uses `chomp(<<-EOT)` inline (no `file()`), starts with plain-text description (no `#` heading), and includes usage motivation, 1–2 examples, and a shared responsibility table with ✅ / ❌ — see [bbd-readme.md](bbd-readme.md)
- [ ] If no `meshstack_integration.tf`: `buildingblock/APP_TEAM_README.md` is present with the same content requirements (plain-text description first, motivation, examples, shared responsibility table)
- [ ] `meshstack_integration.tf` declares `meshcloud/meshstack` in `required_providers`
- [ ] `meshstack_integration.tf` uses `variable "hub" { type = object({git_ref = string}) }` and `variable "meshstack" { type = object({owning_workspace_identifier = string}) }`
- [ ] `meshstack_integration.tf` references backplane via GitHub URL with `?ref=${var.hub.git_ref}` (e.g. `github.com/meshcloud/meshstack-hub//modules/<provider>/<service>/backplane?ref=${var.hub.git_ref}`) — never a hardcoded commit SHA or relative `./backplane` path
- [ ] `variable "hub"` has `const = true`
- [ ] Variables referenced from `meshstack_building_block_definition` input `argument` fields have explicit defaults (never rely on `optional()` defaults via bare `default = {}`)
- [ ] `ref_name` uses `var.hub.git_ref` — no hardcoded `"main"`
- [ ] `version_spec.draft` uses `var.hub.bbd_draft`
- [ ] `spec.display_name`, `spec.description` and `spec.readme` are overridable via `coalesce(var.bbd_*, <the module's own text>)` — see [meshstack-integration.md](meshstack-integration.md)
- [ ] `terraform_version` is `1.12.5` — never the panel's `1.9.0` prefill, which predates OpenTofu's short-circuiting `&&`/`||`
- [ ] `metadata.tags = var.meshstack.tags` in `meshstack_building_block_definition` resource
- [ ] Tags are modeled via `var.meshstack.tags` (no separate top-level `variable "tags"` in integrations)
- [ ] `building_block_definition` output is exposed as `{ uuid, version_ref }` with `version_ref` using `bbd_draft ? version_latest : version_latest_release`
- [ ] `locals` blocks (if used) appear below variables and outputs
- [ ] `terraform { required_providers { ... } }` block is at the **bottom** of `meshstack_integration.tf`
- [ ] `meshstack` and `hub` variables are at the end of the variable section
- [ ] `logo.png` included in `buildingblock/`
- [ ] No `documentation_md` output in `backplane/` — use BBD `readme` field and `backplane/README.md` instead
- [ ] `meshstack_platform` resources include `lifecycle { ignore_changes = [spec.availability] }`
- [ ] Every child `meshstack_building_block` carries the run-status `postcondition` — see [Ordering Child Building Blocks](meshstack-resources.md#ordering-child-building-blocks)
- [ ] Every `*_ref` on a meshStack resource takes the target's `ref` output — see [Referencing meshStack Objects](meshstack-resources.md#referencing-meshstack-objects)
- [ ] Every `try` carries a comment saying what it swallows — see [Guarding Expressions with `try`](terraform-conventions.md#guarding-expressions-with-try)
- [ ] No trailing whitespace
- [ ] **Azure modules**: also follow the [Azure Backplane Checklist](azure-backplane.md#checklist-for-azure-backplanes)
- [ ] **GCP modules**: also follow the [GCP Backplane Checklist](gcp-backplane.md#checklist-for-gcp-backplanes)
