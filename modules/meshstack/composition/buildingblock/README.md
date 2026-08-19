---
name: Composition Demo
supportedPlatforms:
  - meshstack
description: |
  Reference building block demonstrating the composition pattern: it uses the run's
  ephemeral API key to create a building block definition with a building block from it,
  and an empty platform with a landing zone.
# Creates only meshObjects through the meshStack API, so there is nothing to set up cloud-side.
requiresBackplane: false
---
# Composition Demo

This building block is a reference implementation of the **composition** pattern: a building block
that provisions other meshObjects through the meshStack API instead of cloud resources. It creates:

- a `meshBuildingBlockDefinition` in the consuming workspace and a `meshBuildingBlock` from it, and
- an **empty platform** — a `meshPlatformType`, a `meshLocation`, a `meshPlatform` and a
  `meshLandingZone` on it.

The created definition runs the hub's [`link`](../../link) building block, which provisions nothing
but a `terraform_data` and needs neither a cloud provider nor an operator. Reusing it keeps the whole
chain automatic and avoids inventing a throwaway implementation just to have something to create.
Both created building block objects are named after `link_name` (default `Link`) to keep them
distinguishable from the `Composition Demo` block that created them.

*Empty* is the point of the platform: it is a `CUSTOM` platform with no cloud connection config and a
landing zone whose platform properties are `{}`. meshStack ships no `CUSTOM` platform type and every
built-in type is a cloud platform whose config would need real credentials, so the module creates a
type of its own. Nothing about it can be replicated to a cloud — it exists to carry a name, a landing
zone and its creation provenance.

## How it works

The building block definition declares `permissions`, so meshStack issues an **ephemeral API key**
scoped to the consuming workspace for the duration of each run and injects it as `MESHSTACK_ENDPOINT`
/ `MESHSTACK_API_TOKEN`. The `meshstack` provider picks those up with no explicit configuration, so
`provider "meshstack" {}` is all this module needs.

Because every meshObject is created with that key, meshStack records it as their creation author and
surfaces **"created by building block"** provenance on each of them, linking back to the composition
that created them. That makes this module a convenient end-to-end check of that provenance without any
cloud platform involved.

## Permissions

| Permission | Why |
|---|---|
| `BUILDINGBLOCKDEFINITION_LIST` / `_SAVE` / `_DELETE` | Manage the created building block definition |
| `BUILDINGBLOCK_LIST` / `_SAVE` / `_DELETE` | Manage the created building block |
| `PLATFORMINSTANCE_LIST` / `_SAVE` / `_DELETE` | Manage the created platform, its location and its platform type |
| `LANDINGZONE_LIST` / `_SAVE` / `_DELETE` | Manage the created landing zone |

The created definition itself declares no permissions, so it stays within meshStack's privilege
escalation guard (a nested definition may only request a subset of its parent's permissions).

## Notes

- This module does not wait for the created building block's run. That run needs a terraform runner,
  and a stack with a single one cannot start it before this run returns. Provenance is recorded when
  the block is created, so nothing here depends on the result.
- For the same reason the created definition uses `deletion_mode = "PURGE"`. `DELETE` would schedule
  a deprovisioning run on teardown that cannot start until the composition's own destroy run returns.
  Purging leaks nothing, since `link` provisions no infrastructure.
- `hub_git_ref` is wired in as a static input from the composition's own `var.hub.git_ref`, so the
  created definition clones the `link` module from the same hub revision.
- The created definition's version stays a **draft**. Releasing needs admin approval, which the run's
  ephemeral key — a plain workspace key — cannot obtain, so `draft = false` would leave the version
  `DRAFT` regardless, warn on every run, and leave `version_latest_release` null. The created
  building block therefore references `version_latest`, which a draft permits because the definition
  and the building block's target are the same workspace.
- A platform, location and platform type identifier is globally unique and cannot be reused once
  deleted. The module therefore derives all three from `building_block_uuid`, a
  `TENANT_BUILDING_BLOCK_UUID` input carrying the UUID of the building block the run belongs to, so
  each building block gets identifiers of its own that survive re-runs.
- The created platform is `PUBLIC` but `UNPUBLISHED`, which keeps it out of the marketplace. The
  restriction cannot be `PRIVATE`: meshStack then requires `restricted_to_workspaces` to name exactly
  the owner, and the provider defaults that set to empty.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.created](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block_definition.created](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition) | resource |
| [meshstack_landingzone.created](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/landingzone) | resource |
| [meshstack_location.created](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/location) | resource |
| [meshstack_platform.created](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/platform) | resource |
| [meshstack_platform_type.created](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/platform_type) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_building_block_uuid"></a> [building\_block\_uuid](#input\_building\_block\_uuid) | UUID of the building block this run belongs to. Wired in as a TENANT\_BUILDING\_BLOCK\_UUID input and used to name the created platform, location and platform type, whose identifiers must be globally unique. | `string` | n/a | yes |
| <a name="input_hub_git_ref"></a> [hub\_git\_ref](#input\_hub\_git\_ref) | Hub reference the created building block definition clones its implementation from. Wired in as a static input from the composition's own `var.hub.git_ref`, so both definitions stay on the same hub revision. | `string` | n/a | yes |
| <a name="input_link_name"></a> [link\_name](#input\_link\_name) | Name given to the building block definition and building block this composition creates. | `string` | `"Link"` | no |
| <a name="input_link_url"></a> [link\_url](#input\_link\_url) | Target of the link the created building block publishes. | `string` | n/a | yes |
| <a name="input_platform_name"></a> [platform\_name](#input\_platform\_name) | Display name of the platform this composition creates. Its identifier is generated instead of taken from here, because a platform identifier cannot be reused once deleted. | `string` | `"Composition Demo Platform"` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Workspace the created building block definition is owned by and the created building block is attached to. Wired in as a WORKSPACE\_IDENTIFIER input, so it is always the consuming workspace — the same one the run's ephemeral API key is scoped to. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_created_building_block_definition_uuid"></a> [created\_building\_block\_definition\_uuid](#output\_created\_building\_block\_definition\_uuid) | UUID of the building block definition this composition created. |
| <a name="output_created_building_block_uuid"></a> [created\_building\_block\_uuid](#output\_created\_building\_block\_uuid) | UUID of the building block this composition created. |
| <a name="output_created_landing_zone_identifier"></a> [created\_landing\_zone\_identifier](#output\_created\_landing\_zone\_identifier) | Identifier of the landing zone this composition created. Landing zones have no UUID in the API. |
| <a name="output_created_platform_uuid"></a> [created\_platform\_uuid](#output\_created\_platform\_uuid) | UUID of the platform this composition created. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown on the building block's detail page. |
<!-- END_TF_DOCS -->
