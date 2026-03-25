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
    backplane/
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
      APP_TEAM_README.md
      logo.png
      [*.tftest.hcl]
```

Each module follows a two-tier architecture:
- the **backplane** sets up infrastructure permissions required to deploy many individually parameterized instances of the building block module
- the **buildingblock** module, i.e. the actual service provided

## Provider Versions

Provider versions are **module-specific**. Use `~> X.Y.Z` to allow patch updates. Terraform baseline: `>= 1.3.0`.

## Backplane Patterns

**AWS:** IAM users + CloudFormation StackSets for cross-account roles, assume role for target account access.

**Azure:**
- Custom role definitions scoped to subscription or management group
- Optional service principal creation with Workload Identity Federation (WIF); falls back to app password
- Two-tier networking roles: `buildingblock_deploy` (main) and `buildingblock_deploy_hub` (VNet peering, ACR, Key Vault)

## Variables

Use `snake_case`: `monthly_budget_amount`, `subscription_id`. Never use `camelCase` or `kebab-case`.

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

### buildingblock/APP_TEAM_README.md

The app team readme should always include these elements
- description of the building block (what is it) in plain text.
- usage motivation: who this building block is for and when it should be used
- usage examples: provide 1-2 examples of how this building block can be used by a developer building on the cloud
- shared responsibility: clear demarcation of the responsibility of the service (ie what is managed and provided) vs. what the application team is responsible for. This should be formatted as a markdown table.


For the markdown apply the following rules
- Don't use an additional sub-heading for the short description.
- Use emojis in the shared responsibility table (checkmark and x).
- You can use emojis elsewhere where appropriate.

### meshstack_integration.tf

`meshstack_integration.tf` files are **examples** showing how to integrate a platform or building block into a meshStack instance. They are starting points to be adapted, not production-ready configs.

- **Platform integration**: registers a cloud platform with meshStack — provider setup, `meshstack_platform`, `meshstack_location`, and `meshstack_landingzone` resources.
- **Building block integration**: registers a `meshstack_building_block_definition`, wiring backplane outputs to static building block inputs.
- Keep variables at the top and outputs right after variables. Keep `variable "meshstack"` and `variable "hub"` at the end of the variable section.
- `locals` blocks are allowed when they simplify implementation, but place them below variables and outputs.
- Model metadata tags via `var.meshstack.tags` instead of a separate top-level `variable "tags"` in integration files.
- Keep `terraform { required_providers { ... } }` at the bottom and do not include manual provider blocks in `meshstack_integration.tf`.
- Avoid top-of-file banner comments in `meshstack_integration.tf`.

Consult the [meshStack terraform provider documentation](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs) for details on available resources and attributes.

## Checklist for New Modules

- [ ] `backplane/` and `buildingblock/` directories with all required files
- [ ] Provider versions pinned with `~>`
- [ ] Variables in `snake_case`
- [ ] `README.md` with YAML front-matter
- [ ] `APP_TEAM_README.md` with required sections
- [ ] `meshstack_integration.tf` example for meshStack registration
- [ ] Test file covering positive, negative, and naming scenarios
- [ ] `logo.png` included
- [ ] No trailing whitespace
