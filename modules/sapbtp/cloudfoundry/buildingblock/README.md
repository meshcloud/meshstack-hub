---
name: SAP BTP Cloud Foundry
supportedPlatforms:
  - btp
description: Enables Cloud Foundry environment in an SAP BTP subaccount and manages Cloud Foundry service instances like PostgreSQL, Redis, XSUAA, and more.
---

# SAP BTP Cloud Foundry Building Block

This building block enables the Cloud Foundry environment in an SAP BTP subaccount and manages Cloud Foundry service instances.

## What This Module Does

1. **Provisions Cloud Foundry Environment**: Creates a Cloud Foundry org and space
2. **Manages CF Service Instances**: Creates service instances (databases, messaging, etc.) within Cloud Foundry

## Prerequisites

- An existing SAP BTP subaccount
- Required entitlements:
  - `cloudfoundry.standard` or `cloudfoundry.free`
  - `APPLICATION_RUNTIME.MEMORY` (for running apps)
  - Entitlements for any CF services you want to use
- SAP BTP authentication configured via environment variables

## Usage

### Enable Cloud Foundry Only

```hcl
globalaccount       = "my-global-account"
subaccount_id       = "ab5dcd3d-c824-4470-a2f6-758d37da52ea"
project_identifier  = "my-project"
cloudfoundry_plan   = "standard"
```

### Enable Cloud Foundry with Services

```hcl
globalaccount       = "my-global-account"
subaccount_id       = "ab5dcd3d-c824-4470-a2f6-758d37da52ea"
project_identifier  = "my-project"
cloudfoundry_plan   = "standard"
cf_services         = "postgresql.small,redis.medium,xsuaa.application,destination.lite"
```

### Importing Existing CF Environment

1. Create a `terraform.tfvars` file with your configuration
2. Run the import script:
   ```bash
   ./import-resources.sh
   ```
3. Verify with `tofu plan`

## Available Cloud Foundry Services

### Databases
- `postgresql.small`, `postgresql.medium`, `postgresql.large` - PostgreSQL databases
- `redis.small`, `redis.medium`, `redis.large` - Redis cache

### Platform Services
- `xsuaa.application` - Authentication and authorization
- `xsuaa.broker` - Service broker authentication
- `destination.lite` - Destination service
- `connectivity.lite` - Connectivity to on-premise systems

### Application Services
- `application-logs.lite`, `application-logs.standard` - Application logging
- `html5-apps-repo.app-host`, `html5-apps-repo.app-runtime` - HTML5 application repository
- `jobscheduler.lite`, `jobscheduler.standard` - Job scheduling
- `credstore.free`, `credstore.standard` - Credential storage
- `objectstore.s3-standard` - Object storage (S3-compatible)

## Variables

| Name | Description | Required |
|------|-------------|----------|
| `globalaccount` | Global account subdomain | Yes |
| `subaccount_id` | Target subaccount ID | Yes |
| `project_identifier` | Project identifier for naming | Yes |
| `cloudfoundry_plan` | CF plan (standard, free, trial) | No (default: standard) |
| `cf_services` | Comma-separated CF service instances | No |

## Outputs

| Name | Description |
|------|-------------|
| `cloudfoundry_instance_id` | CF environment instance ID |
| `cloudfoundry_instance_state` | CF environment state (OK, CREATING, etc.) |
| `cloudfoundry_services` | Map of created CF service instances |
| `subaccount_id` | Passthrough of subaccount ID |

## Service Instance Naming

Service instances are automatically named: `{service}-{plan}`

Examples:
- `postgresql.small` → instance name: `postgresql-small`
- `redis.medium` → instance name: `redis-medium`
- `xsuaa.application` → instance name: `xsuaa-application`

## Lifecycle Management

The `parameters` attribute for CF service instances is ignored after creation. This allows:
- Importing existing service instances
- Manual parameter updates via CF CLI
- Flexible service configuration

## Dependency Chain

This building block depends on:
- **subaccount** - Must have a subaccount ID
- **entitlements** - CF and service entitlements required

## Common Scenarios

### Basic Web Application Stack
```
cf_services = "postgresql.small,xsuaa.application,destination.lite"
```

### Microservices Platform
```
cf_services = "postgresql.medium,redis.medium,xsuaa.application,application-logs.standard,jobscheduler.standard"
```

### Enterprise Application
```
cf_services = "postgresql.large,redis.large,xsuaa.application,connectivity.lite,destination.lite,credstore.standard"
```

## Important Notes

### Provisioning Time
- CF environment: 10-20 minutes
- Service instances: 2-10 minutes each

### Entitlement Requirements
Each CF service requires a corresponding entitlement. Use the **entitlements building block** first.

### Service Binding
After creating service instances:
1. Use CF CLI to bind services to your apps
2. Or use manifest.yml `services:` section
3. Service credentials are injected via `VCAP_SERVICES`

## Accessing Cloud Foundry

After provisioning, access CF via:
```bash
cf login -a https://api.cf.{region}.hana.ondemand.com
cf target -o {org-name} -s {space-name}
```

Find your org name in BTP Cockpit → Cloud Foundry → Organizations
