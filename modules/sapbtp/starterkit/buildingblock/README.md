---
name: SAP BTP Starterkit
supportedPlatforms:
  - sapbtp
description: |
  The SAP BTP Starterkit provides application teams with pre-configured SAP BTP subaccounts for development and production environments, including entitlements and optional Cloud Foundry configuration.
---

# SAP BTP Starterkit Building Block

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

## Overview

This composition building block creates a complete SAP BTP environment with separate development and production subaccounts, including entitlements and optional Cloud Foundry configuration.

## What It Creates

- 2 meshStack projects (dev and prod)
- 2 SAP BTP subaccounts (one per project)
- Entitlements building blocks for both environments
- Optional Cloud Foundry environment instances
- Project Admin access for the creator

## Architecture

```
Workspace
├── Project: <name>-dev
│   └── Tenant: SAP BTP Subaccount (Dev)
│       ├── Building Block: Entitlements
│       └── Building Block: Cloud Foundry (optional)
└── Project: <name>-prod
    └── Tenant: SAP BTP Subaccount (Prod)
        ├── Building Block: Entitlements
        └── Building Block: Cloud Foundry (optional)
```

## Usage

This building block is designed to be used as a composition/starterkit that orchestrates multiple other building blocks to provide a complete development environment.

### Required Variables

- `workspace_identifier` - The meshStack workspace where projects will be created
- `name` - Base name for the environment (will create `<name>-dev` and `<name>-prod`)
- `platform_identifier` - SAP BTP platform identifier
- `landing_zone_dev_identifier` - Landing zone for dev subaccount
- `landing_zone_prod_identifier` - Landing zone for prod subaccount
- `entitlements_definition_version_uuid` - UUID of entitlements building block definition
- `creator` - User information for project admin assignment

### Optional Cloud Foundry

Set `enable_cloudfoundry = true` and provide:
- `cloudfoundry_definition_version_uuid`
- `cloudfoundry_plan` (default: "standard")
- `cf_services_dev` - Services for dev environment
- `cf_services_prod` - Services for prod environment

## Dependencies

This building block depends on the following building block definitions being available:
- SAP BTP Entitlements building block
- SAP BTP Cloud Foundry building block (if `enable_cloudfoundry = true`)

## Project Tags

You can customize project tags using the `project_tags_yaml` variable:

```yaml
dev:
  environment:
    - "development"
  cost-center:
    - "CC-123"
prod:
  environment:
    - "production"
  cost-center:
    - "CC-456"
```
