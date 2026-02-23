# AGENTS.md - Building Block Module Patterns and Conventions

## Directory Structure

```
<cloud-provider>/
  <service-name>/
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

Each module follows a two-tier architecture: **backplane** (infrastructure/permissions setup) and **buildingblock** (the actual service resources).

## Provider Versions

Provider versions are **module-specific**. Use `~> X.Y.Z` to allow patch updates. Terraform baseline: `>= 1.3.0`.

## Backplane Patterns

**AWS:** IAM users + CloudFormation StackSets for cross-account roles, assume role for target account access.

**Azure:**
- Custom role definitions scoped to subscription or management group
- Optional service principal creation with Workload Identity Federation (WIF); falls back to app password
- Two-tier networking roles: `buildingblock_deploy` (main) and `buildingblock_deploy_hub` (VNet peering, ACR, Key Vault)

## Variables

Use `snake_case`: `monthly_budget_amount`, `subscription_id`. Never camelCase.

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

**buildingblock/README.md** — YAML front-matter required:
```yaml
---
name: AWS S3 Bucket
supportedPlatforms:
  - aws
description: Provides an AWS S3 bucket for object storage with access controls, lifecycle policies, and encryption.
---
```

**APP_TEAM_README.md** — user-facing; must include usage examples, shared responsibility matrix, and best practices.

## meshstack_integration.tf Files

`meshstack_integration.tf` files are **examples** showing how to integrate a platform or building block into a meshStack instance. They are starting points to be adapted, not production-ready configs.

- **Platform integration** (e.g. `modules/azure/meshstack_integration.tf`): registers a cloud platform with meshStack — provider setup, `meshstack_platform`, `meshstack_location`, and `meshstack_landingzone` resources.
- **Building block integration** (e.g. `modules/aws/s3_bucket/meshstack_integration.tf`): registers a `meshstack_building_block_definition`, wiring backplane outputs to building block inputs.

## Checklist for New Modules

- [ ] `backplane/` and `buildingblock/` directories with all required files
- [ ] Provider versions pinned with `~>`
- [ ] Variables in `snake_case`
- [ ] `README.md` with YAML front-matter
- [ ] `APP_TEAM_README.md` with required sections
- [ ] Test file covering positive, negative, and naming scenarios
- [ ] `logo.png` included
- [ ] No trailing whitespace
