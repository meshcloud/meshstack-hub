---
name: SAP BTP Entitlements
supportedPlatforms:
  - btp
description: Manages service entitlements in an SAP BTP subaccount, enabling access to platform services and setting quota allocations.
---

# SAP BTP Entitlements Building Block

This building block manages service entitlements for an SAP BTP subaccount. Entitlements grant access to platform services and define quota allocations.

## Prerequisites

- An existing SAP BTP subaccount (either created via the `subaccount` building block or imported)
- SAP BTP authentication configured via environment variables:
  - `BTP_USERNAME`
  - `BTP_PASSWORD`
  - `BTP_GLOBALACCOUNT`

## Usage

### Creating New Entitlements

```hcl
globalaccount  = "my-global-account"
subaccount_id  = "ab5dcd3d-c824-4470-a2f6-758d37da52ea"
entitlements   = "postgresql-db.trial,destination.lite,xsuaa.application"
```

### Importing Existing Entitlements

1. Create a `terraform.tfvars` file with your configuration
2. Run the import script:
   ```bash
   ./import-resources.sh
   ```
3. Verify with `tofu plan`

## Entitlement Types

### Quota-Based Services
These services require quota allocation (amount is automatically set):
- `APPLICATION_RUNTIME` - Cloud Foundry runtime memory
- `cloudfoundry` - Cloud Foundry environment
- `postgresql-db` - PostgreSQL database
- `redis-cache` - Redis cache
- `hana-cloud` - SAP HANA Cloud
- `auditlog-viewer` - Audit log viewer
- `sapappstudio` - SAP Business Application Studio
- `sap-build-apps` - SAP Build Apps

### Non-Quota Services
These services don't require quota (boolean entitlement):
- `destination` - Destination service
- `xsuaa` - Authorization and trust management
- `connectivity` - Connectivity service
- Most other BTP services

## Variables

| Name | Description | Required |
|------|-------------|----------|
| `globalaccount` | Global account subdomain | Yes |
| `subaccount_id` | Target subaccount ID | Yes |
| `entitlements` | Comma-separated list of entitlements in format `service.plan` | No |

## Outputs

| Name | Description |
|------|-------------|
| `entitlements` | Map of created entitlements with service names, plans, and quotas |
| `subaccount_id` | Passthrough of subaccount ID for dependency chaining |

## Lifecycle Management

The `amount` attribute for quota-based entitlements is ignored after initial creation. This allows:
- Importing existing entitlements without conflicts
- Manual quota adjustments via BTP Cockpit
- Flexible quota management

## Dependency Chain

This building block depends on:
- **subaccount** - Must have a subaccount ID

This building block is required by:
- **subscriptions** - Subscriptions need entitlements
- **cloudfoundry** - CF environment needs entitlements

## Common Scenarios

### Standard Application Development
```
entitlements = "cloudfoundry.standard,APPLICATION_RUNTIME.MEMORY,xsuaa.application,destination.lite"
```

### Database-Backed Application
```
entitlements = "postgresql-db.small,redis-cache.medium"
```

### SAP Build Development
```
entitlements = "sapappstudio.standard-edition,sap-build-apps.standard"
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [btp_subaccount_entitlement.entitlement_with_quota](https://registry.terraform.io/providers/hashicorp/btp/latest/docs/resources/subaccount_entitlement) | resource |
| [btp_subaccount_entitlement.entitlement_without_quota](https://registry.terraform.io/providers/hashicorp/btp/latest/docs/resources/subaccount_entitlement) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_entitlements"></a> [entitlements](#input\_entitlements) | Comma-separated list of service entitlements in format: service.plan (e.g., 'postgresql-db.trial,destination.lite,xsuaa.application') | `string` | `""` | no |
| <a name="input_globalaccount"></a> [globalaccount](#input\_globalaccount) | The subdomain of the global account in which you want to manage resources. | `string` | n/a | yes |
| <a name="input_subaccount_id"></a> [subaccount\_id](#input\_subaccount\_id) | The ID of the subaccount where entitlements should be added. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_entitlements"></a> [entitlements](#output\_entitlements) | Map of entitlements created for this subaccount |
| <a name="output_subaccount_id"></a> [subaccount\_id](#output\_subaccount\_id) | The subaccount ID (passthrough for dependency chaining) |
<!-- END_TF_DOCS -->