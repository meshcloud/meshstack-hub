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
