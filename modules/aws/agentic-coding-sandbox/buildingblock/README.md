---
name: Agentic Coding Sandbox
supportedPlatforms:
- aws
description: |
  A composition building block that provides developers with a sandboxed AWS environment
  to access agentic coding tools like Claude via AWS Bedrock, with automatic budget alerts
  and region enablement for AI model access.
---
# Agentic Coding Sandbox

This building block is a **composition** that orchestrates multiple components to provide developers with a complete agentic coding environment. It automatically provisions a meshStack project and AWS tenant configured for AI-powered development workflows.

## Prerequisites

Before deploying this building block:

1. ✅ Deploy the [AWS Bedrock landing zone](../backplane/landingzone/README.md) to your AWS platform.
2. ✅ Import [AWS Budget Alert Building Block](https://hub.meshcloud.io/definitions/aws-budget-alert) from meshStack Hub into your meshStack
3. ✅ Import [AWS Enable Opt-In Region building block](https://hub.meshcloud.io/definitions/aws-opt-in-region) from meshStack Hub into your meshStack
4. ✅ Configure the `composition_config_yaml` with the correct UUIDs and identifiers
5. ✅ Configure an meshStack API key for the composition with admin permissions for projects, tenants, and building blocks

## What This Building Block Does

This composition creates:

1. **meshProject**: A dedicated project with auto-generated naming (`acs-{username}-{suffix}`) to avoid conflicts. The project allows you to manage IAM and Billing with ease in meshStack.
2. **AWS Account**: A tenant in the specified AWS platform using the configured landing zone
3. **Budget Alert**: Automated cost monitoring with email notifications to the user
4. **EU South 2 Region Access**: Enables the Spain region where advanced models like Anthropic's Claude Sonnet 4 are available as an alternative to the primary Frankfurt region used in this example.

## Configuration Requirements

⚠️ **Important**: Since this is a composition, platform operators **must** populate the `composition_config_yaml` variable with the correct UUIDs and identifiers from the building blocks deployed to their meshStack from meshStack Hub. Configure this as a static code input in your meshStack.

### Required Configuration

The `composition_config_yaml` variable must contain:

```yaml
landing_zone:
  landing_zone_identifier: "your-bedrock-landing-zone-id"  # From your AWS Bedrock LZ deployment
  platform_identifier: "your-aws-platform-id"             # Your AWS platform identifier

budget_alert_building_block:
  definition_uuid: "uuid-from-meshstack-hub"      # UUID from AWS Budget Alert BB deployment
  definition_version: 1                           # Version from your deployment

enable_eu_south_2_region_building_block:
  definition_uuid: "uuid-from-meshstack-hub"      # UUID from AWS Enable Opt-In Region BB deployment
  definition_version: 1                           # Version from your deployment

project:                                          # Optional project configuration
  default_tags:
    environment: "sandbox"
    cost_center: "engineering"
  owner_tag_key: "project_owner"                 # Optional: adds owner tag to project
```

### How to Get the Required Values

1. **Landing Zone Identifiers**: Check your AWS platform configuration in meshStack
2. **Building Block UUIDs**: After importing building blocks from meshStack Hub, find their UUIDs in:
   - meshStack Admin Area → Building Block Definitions
   - Or via meshStack API: `GET /api/meshobjects/meshbuildingblockdefinitions`

## User Inputs

End users provide:

- **username**: Must be a `@meshcloud.io` email address (validated)
- **budget_amount**: Monthly budget limit for cost alerts

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | 0.7.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_buildingblock.budget_alert](https://registry.terraform.io/providers/meshcloud/meshstack/0.7.1/docs/resources/buildingblock) | resource |
| [meshstack_buildingblock.enable_eu_south_2_region](https://registry.terraform.io/providers/meshcloud/meshstack/0.7.1/docs/resources/buildingblock) | resource |
| [meshstack_project.sandbox](https://registry.terraform.io/providers/meshcloud/meshstack/0.7.1/docs/resources/project) | resource |
| [meshstack_tenant.sandbox](https://registry.terraform.io/providers/meshcloud/meshstack/0.7.1/docs/resources/tenant) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | Monthly budget amount. You will receive an alert when the budget is exceeded. | `number` | n/a | yes |
| <a name="input_composition_config_yaml"></a> [composition\_config\_yaml](#input\_composition\_config\_yaml) | YAML configuration for landing zone and building blocks. Expected structure:<pre>yaml<br>landing_zone:<br>  landing_zone_identifier: "my-landing-zone"<br>  platform_identifier: "my-platform"<br>budget_alert_building_block:<br>  definition_uuid: "uuid-here"<br>  definition_version: 1<br>enable_eu_south_2_region_building_block:<br>  definition_uuid: "uuid-here"<br>  definition_version: 1<br>project:<br>  default_tags:<br>    environment: "sandbox"<br>    cost_center: "engineering"<br>  owner_tag_key: "project_owner"  # optional, if not set no project owner tag will be set</pre> | `string` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | meshStack username of the project contact. This should be an email. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier for the owning workspace | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->