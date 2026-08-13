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
5. ✅ Configure an meshStack API key for the composition with admin permissions for projects, tenants, and building blocks, and with permission to list platforms — the composition resolves the configured platform identifier to a platform reference

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
  landing_zone_identifier: "your-bedrock-landing-zone-id"   # From your AWS Bedrock LZ deployment
  platform_identifier: "your-aws-platform.your-location"    # Full platform identifier, <platform-name>.<location-name>

budget_alert_building_block:
  definition_version_uuid: "uuid-from-meshstack"  # Version UUID of the AWS Budget Alert BBD

enable_eu_south_2_region_building_block:
  definition_version_uuid: "uuid-from-meshstack"  # Version UUID of the AWS Enable Opt-In Region BBD

project:                                          # Optional project configuration
  default_tags:
    environment: "sandbox"
    cost_center: "engineering"
  owner_tag_key: "project_owner"                 # Optional: adds owner tag to project
```

### How to Get the Required Values

1. **Landing Zone and Platform Identifiers**: Check your AWS platform configuration in meshStack. The platform identifier is the full `<platform-name>.<location-name>`.
2. **Building Block Definition Version UUIDs**: After importing the building blocks from meshStack Hub, look up the UUID of the definition *version* you want to provision (not the UUID of the definition itself) in:
   - meshStack Admin Area → Building Block Definitions → the definition's version
   - Or via meshStack API: `GET /api/meshobjects/meshbuildingblockdefinitions`, and read the `uuid` of the version

## User Inputs

End users provide:

- **username**: Must be a `@meshcloud.io` email address (validated)
- **budget_amount**: Monthly budget limit for cost alerts

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.24.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block.budget_alert](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_building_block.enable_eu_south_2_region](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block) | resource |
| [meshstack_project.sandbox](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/project) | resource |
| [meshstack_tenant.sandbox](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/tenant) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [meshstack_platforms.available](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/platforms) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_budget_amount"></a> [budget\_amount](#input\_budget\_amount) | Monthly budget amount. You will receive an alert when the budget is exceeded. | `number` | n/a | yes |
| <a name="input_composition_config_yaml"></a> [composition\_config\_yaml](#input\_composition\_config\_yaml) | YAML configuration for landing zone and building blocks. Expected structure:<pre>yaml<br/>landing_zone:<br/>  landing_zone_identifier: "my-landing-zone"<br/>  platform_identifier: "my-platform.my-location" # full platform identifier, <platform-name>.<location-name><br/>budget_alert_building_block:<br/>  definition_version_uuid: "uuid-here" # uuid of the building block definition *version* to provision<br/>enable_eu_south_2_region_building_block:<br/>  definition_version_uuid: "uuid-here"<br/>project:<br/>  default_tags:<br/>    environment: "sandbox"<br/>    cost_center: "engineering"<br/>  owner_tag_key: "project_owner"  # optional, if not set no project owner tag will be set</pre> | `string` | n/a | yes |
| <a name="input_username"></a> [username](#input\_username) | meshStack username of the project contact. This should be an email. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier for the owning workspace | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->