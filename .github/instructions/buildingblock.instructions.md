---
applyTo: '**/buildingblock/**.md'
---

# Building Block Module Patterns and Conventions

When asked to create a new building block definition for meshStack, follow these patterns and conventions.

## Directory Structure

```
<cloud-provider>/
  <service-name>/
    meshstack_integration.tf
    backplane/           # optional — only needed when cloud-side setup is required
      main.tf
      outputs.tf
      variables.tf
      versions.tf
      README.md
      [provider-specific files like iam.tf]
    buildingblock/
      main.tf
      outputs.tf
      variables.tf
      versions.tf
      provider.tf
      README.md
      logo.png
      [*.tftest.hcl]
```

Each module follows a two-tier architecture:
- the **backplane** (optional) sets up infrastructure permissions required to deploy many individually parameterized instances of the building block module. Omit it for simple building blocks that need no cloud-side setup (e.g. those that receive all credentials as static inputs).
- the **buildingblock** module, i.e. the actual service provided

## Provider Versions

Provider versions are **module-specific**. Use `~> X.Y.Z` to allow patch updates. **Exception:** the `meshcloud/meshstack` provider is pre-1.0, so pin to the minor version with `~> 0.Y.0` (e.g. `~> 0.20.0`). Terraform baseline: `>= 1.3.0`.

## Backplane Patterns

**AWS:** IAM users + CloudFormation StackSets for cross-account roles, assume role for target account access.

**Azure:**
- Custom role definitions scoped to subscription or management group
- Optional service principal creation with Workload Identity Federation (WIF); falls back to app password
- Two-tier networking roles: `buildingblock_deploy` (main) and `buildingblock_deploy_hub` (VNet peering, ACR, Key Vault)

## Variables

Use `snake_case`: `monthly_budget_amount`, `azure_subscription_id`. Never use `camelCase` or `kebab-case`.

In `meshstack_integration.tf`, cloud-provider-specific variables must be **flat** with a provider prefix (e.g. `azure_tenant_id`, `aws_region`, `gcp_project_id`, `stackit_project_id`). Do **not** group them into a single provider object like `variable "azure" { type = object({...}) }`.

Cross-cutting concerns like workload identity federation settings may be grouped into a `variable "workload_identity"` object when the fields are logically inseparable. Only `variable "meshstack"` and `variable "hub"` use shared object conventions across all integrations.

## Testing

Test files (`.tftest.hcl`) must cover:
- Positive scenarios (valid configs)
- Negative scenarios (invalid inputs)
- Naming collision prevention

**Test users:**
```hcl
{ meshIdentifier = "likvid-tom-user",     username = "likvid-tom@meshcloud.io",     roles = ["admin", "Workspace Owner"] }
{ meshIdentifier = "likvid-daniela-user", username = "likvid-daniela@meshcloud.io", roles = ["user", "Workspace Manager"] }
{ meshIdentifier = "likvid-anna-user",    username = "likvid-anna@meshcloud.io",    roles = ["reader", "Workspace Member"] }
```

## Documentation

Consitent documentation is important for discoverability and usability. Follow these to ensure consistent representation of building blocks in meshStack Hub:

### buildingblock/README.md

This file needs to contain YAML front-matter and terraform-docs as follows:
```yaml
---
name: AWS S3 Bucket
supportedPlatforms:
  - aws
description: Provides an AWS S3 bucket for object storage with access controls, lifecycle policies, and encryption.
---

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
```

### BBD `readme` field (in `meshstack_integration.tf`)

User-facing documentation is placed directly in the `readme` field of `meshstack_building_block_definition.spec`. It must always include:

- A short plain-text description of the building block (no additional sub-heading).
- Usage motivation: who it is for and when to use it.
- 1–2 usage examples showing a developer using the building block.
- A shared responsibility table (markdown) with a clear demarcation between platform team and application team responsibilities.

For the markdown apply the following rules:
- Don't use an additional sub-heading for the short description.
- Use emojis in the shared responsibility table (✅ / ❌).
- You can use emojis elsewhere where appropriate.

### meshstack_integration.tf

`meshstack_integration.tf` files are **examples** showing how to integrate a platform or building block into a meshStack instance. They are starting points to be adapted, not production-ready configs.

- **Platform integration**: registers a cloud platform with meshStack — provider setup, `meshstack_platform`, `meshstack_location`, and `meshstack_landingzone` resources.
- **Building block integration**: registers a `meshstack_building_block_definition`, wiring backplane outputs to static building block inputs.
- Keep variables at the top and outputs right after variables. Keep `variable "meshstack"` and `variable "hub"` at the end of the variable section.
- Cloud-provider-specific variables must be flat with a provider prefix (e.g. `azure_tenant_id`, `aws_region`). Do **not** group them into a single provider object.
- Cross-cutting concerns (e.g. workload identity federation) may use an `object({})` variable when the fields are logically inseparable.
- `locals` blocks are allowed when they simplify implementation, but place them below variables and outputs.
- Model metadata tags via `var.meshstack.tags` instead of a separate top-level `variable "tags"` in integration files.
- Keep `terraform { required_providers { ... } }` at the bottom and do not include manual provider blocks in `meshstack_integration.tf`.
- Avoid top-of-file banner comments in `meshstack_integration.tf`.

Consult the [meshStack terraform provider documentation](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs) for details on available resources and attributes.

## Checklist for New Modules

- [ ] `backplane/` (optional) and `buildingblock/` directories with all required files
- [ ] Provider versions pinned with `~>`
- [ ] Variables in `snake_case` with cloud-provider prefix in `meshstack_integration.tf` (e.g. `azure_tenant_id`)
- [ ] `README.md` with YAML front-matter
- [ ] BBD `readme` field in `meshstack_integration.tf` contains description, usage motivation, examples, and shared responsibility table
- [ ] `meshstack_integration.tf` example for meshStack registration
- [ ] Test file covering positive, negative, and naming scenarios
- [ ] `logo.png` included
- [ ] No trailing whitespace
