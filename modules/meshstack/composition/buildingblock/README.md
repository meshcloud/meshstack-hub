---
name: Composition Demo
supportedPlatforms:
  - meshstack
description: |
  Reference building block demonstrating the composition pattern: it uses the run's
  ephemeral API key to create a building block definition and a building block from it.
# Creates only meshObjects through the meshStack API, so there is nothing to set up cloud-side.
requiresBackplane: false
---
# Composition Demo

This building block is a reference implementation of the **composition** pattern: a building block
that provisions other meshObjects through the meshStack API instead of cloud resources. It creates a
`meshBuildingBlockDefinition` in the consuming workspace and a `meshBuildingBlock` from that
definition.

The created definition runs the hub's [`link`](../../link) building block, which provisions nothing
but a `terraform_data` and needs neither a cloud provider nor an operator. Reusing it keeps the whole
chain automatic and avoids inventing a throwaway implementation just to have something to create.
Both created meshObjects are named after `link_name` (default `Link`) to keep them distinguishable
from the `Composition Demo` block that created them.

## How it works

The building block definition declares `permissions`, so meshStack issues an **ephemeral API key**
scoped to the consuming workspace for the duration of each run and injects it as `MESHSTACK_ENDPOINT`
/ `MESHSTACK_API_TOKEN`. The `meshstack` provider picks those up with no explicit configuration, so
`provider "meshstack" {}` is all this module needs.

Because both meshObjects are created with that key, meshStack records it as their creation author and
surfaces **"created by building block"** provenance on the definition and the building block, linking
back to the composition that created them. That makes this module a convenient end-to-end check of
that provenance without any cloud platform involved.

## Permissions

| Permission | Why |
|---|---|
| `BUILDINGBLOCKDEFINITION_LIST` / `_SAVE` / `_DELETE` | Manage the created building block definition |
| `BUILDINGBLOCK_LIST` / `_SAVE` / `_DELETE` | Manage the created building block |

The created definition itself declares no permissions, so it stays within meshStack's privilege
escalation guard (a nested definition may only request a subset of its parent's permissions).

## Notes

- This module does not wait for the created building block's run. That run needs a terraform runner,
  and a stack with a single one cannot start it before this run returns. Provenance is recorded when
  the block is created, so nothing here depends on the result.
- `hub_git_ref` is wired in as a static input from the composition's own `var.hub.git_ref`, so the
  created definition clones the `link` module from the same hub revision.
- The created definition's version stays a **draft**. Releasing needs admin approval, which the run's
  ephemeral key — a plain workspace key — cannot obtain, so `draft = false` would leave the version
  `DRAFT` regardless, warn on every run, and leave `version_latest_release` null. The created
  building block therefore references `version_latest`, which a draft permits because the definition
  and the building block's target are the same workspace.

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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hub_git_ref"></a> [hub\_git\_ref](#input\_hub\_git\_ref) | Hub reference the created building block definition clones its implementation from. Wired in as a static input from the composition's own `var.hub.git_ref`, so both definitions stay on the same hub revision. | `string` | n/a | yes |
| <a name="input_link_name"></a> [link\_name](#input\_link\_name) | Name given to the building block definition and building block this composition creates. | `string` | n/a | yes |
| <a name="input_link_url"></a> [link\_url](#input\_link\_url) | Target of the link the created building block publishes. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Workspace the created building block definition is owned by and the created building block is attached to. Wired in as a WORKSPACE\_IDENTIFIER input, so it is always the consuming workspace — the same one the run's ephemeral API key is scoped to. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_created_building_block_definition_uuid"></a> [created\_building\_block\_definition\_uuid](#output\_created\_building\_block\_definition\_uuid) | UUID of the building block definition this composition created. |
| <a name="output_created_building_block_uuid"></a> [created\_building\_block\_uuid](#output\_created\_building\_block\_uuid) | UUID of the building block this composition created. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown on the building block's detail page. |
<!-- END_TF_DOCS -->
