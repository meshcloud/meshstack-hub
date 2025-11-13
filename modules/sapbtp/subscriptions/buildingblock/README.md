---
name: SAP BTP Subscriptions
supportedPlatforms:
  - btp
description: Manages application subscriptions in an SAP BTP subaccount, enabling access to SaaS applications like SAP Build Work Zone, Integration Suite, and more.
---

# SAP BTP Subscriptions Building Block

This building block manages application subscriptions for an SAP BTP subaccount. Subscriptions enable access to SaaS applications available in the SAP BTP marketplace.

## Prerequisites

- An existing SAP BTP subaccount
- Required entitlements for the applications you want to subscribe to
- SAP BTP authentication configured via environment variables

## Usage

### Creating New Subscriptions

```hcl
globalaccount  = "my-global-account"
subaccount_id  = "ab5dcd3d-c824-4470-a2f6-758d37da52ea"
subscriptions  = "build-workzone.standard,sapappstudio.standard-edition"
```

### Importing Existing Subscriptions

1. Create a `terraform.tfvars` file with your configuration
2. Run the import script:
   ```bash
   ./import-resources.sh
   ```
3. Verify with `tofu plan`

## Common Applications

### Development & Integration
- `sapappstudio.standard-edition` - SAP Business Application Studio IDE
- `sap-build-apps.standard` - Low-code development platform
- `integrationsuite.enterprise_agreement` - Integration Suite
- `cicd-service.default` - CI/CD service

### Productivity & Collaboration
- `build-workzone.standard` - SAP Build Work Zone
- `mobile-services.standard` - Mobile services

### Business Applications
- `business-rules.standard` - Business rules management
- `workflow.standard` - Workflow automation

## Important Notes

### Entitlement Dependency
Subscriptions **require corresponding entitlements**. For example:
- `sapappstudio.standard-edition` subscription needs `sapappstudio.standard-edition` entitlement
- Always add entitlements before subscriptions

### Provisioning Time
Some subscriptions take time to provision (5-15 minutes). The `state` output shows provisioning status.

### Subscription vs Service Instance
- **Subscription**: SaaS application (like SAP Business Application Studio)
- **Service Instance**: Platform service (like PostgreSQL) - managed in Cloud Foundry building block

## Variables

| Name | Description | Required |
|------|-------------|----------|
| `globalaccount` | Global account subdomain | Yes |
| `subaccount_id` | Target subaccount ID | Yes |
| `subscriptions` | Comma-separated list in format `app.plan` | No |

## Outputs

| Name | Description |
|------|-------------|
| `subscriptions` | Map of created subscriptions with app names, plans, and states |
| `subaccount_id` | Passthrough of subaccount ID for dependency chaining |

## Dependency Chain

This building block depends on:
- **subaccount** - Must have a subaccount ID
- **entitlements** - Required entitlements must exist

## Common Scenarios

### Full Development Environment
```
subscriptions = "sapappstudio.standard-edition,build-workzone.standard,cicd-service.default"
```

### Integration Platform
```
subscriptions = "integrationsuite.enterprise_agreement,mobile-services.standard"
```

### Low-Code Platform
```
subscriptions = "sap-build-apps.standard,build-workzone.standard"
```
