---
name: SAP BTP Subaccount
supportedPlatforms:
  - sapbtp
description: |
  Provisions SAP BTP subaccounts with optional application subscriptions, entitlements, Cloud Foundry environment, and custom identity provider configuration.
category: platform
---

# SAP BTP subaccount with environment configuration

This Terraform module provisions a subaccount in SAP Business Technology Platform (BTP).

## Features

This building block provides the following optional capabilities:

- **Subaccount Creation**: Basic subaccount provisioning with region and folder placement
- **Entitlements**: Service quota and plan assignments required for subscriptions
- **Subscriptions**: Application subscriptions (SAP Build Code, Process Automation, etc.)
- **Cloud Foundry**: Optional Cloud Foundry environment instance for application deployment
- **Trust Configuration**: External Identity Provider integration (SAP IAS, custom IdP)

## Usage Example

```hcl
module "sap_btp_subaccount" {
  source = "./modules/sapbtp/subaccounts/buildingblock"

  globalaccount      = "my-global-account"
  project_identifier = "my-project"
  subfolder          = "development"
  region             = "eu30"

  entitlements = [
    {
      service_name = "build-code"
      plan_name    = "free"
    },
    {
      service_name = "storage"
      plan_name    = "standard"
      amount       = 5
    }
  ]

  subscriptions = [
    {
      app_name   = "build-code"
      plan_name  = "free"
      parameters = {}
    }
  ]

  cloudfoundry_instance = {
    name      = "dev-cf"
    plan_name = "standard"
  }

  trust_configuration = {
    identity_provider = "mytenant.accounts.ondemand.com"
  }
}
```

## Providers

```hcl
terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.8.0"
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_btp"></a> [btp](#requirement\_btp) | ~> 1.8.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [btp_subaccount.subaccount](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount) | resource |
| [btp_subaccount_entitlement.entitlement](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_entitlement) | resource |
| [btp_subaccount_environment_instance.cloudfoundry](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_environment_instance) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_admin](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_service_admininstrator](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_viewer](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_subscription.subscription](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_subscription) | resource |
| [btp_subaccount_trust_configuration.custom_idp](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_trust_configuration) | resource |
| [btp_directories.all](https://registry.terraform.io/providers/SAP/btp/latest/docs/data-sources/directories) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudfoundry_instance"></a> [cloudfoundry\_instance](#input\_cloudfoundry\_instance) | Configuration for Cloud Foundry environment instance. Set to null to skip creation. | <pre>object({<br>    name        = optional(string, "cf-instance")<br>    environment = optional(string, "cloudfoundry")<br>    plan_name   = string<br>    parameters  = optional(map(string), {})<br>  })</pre> | `null` | no |
| <a name="input_entitlements"></a> [entitlements](#input\_entitlements) | List of entitlements to assign to the subaccount. For quota-based services, specify 'amount'. For multitenant applications (category APPLICATION), omit 'amount' or set to null. Entitlements must be configured before subscriptions can be created. | <pre>list(object({<br>    service_name = string<br>    plan_name    = string<br>    amount       = optional(number)<br>  }))</pre> | `[]` | no |
| <a name="input_globalaccount"></a> [globalaccount](#input\_globalaccount) | The subdomain of the global account in which you want to manage resources. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | The meshStack project identifier. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region of the subaccount. | `string` | `"eu30"` | no |
| <a name="input_subfolder"></a> [subfolder](#input\_subfolder) | The subfolder to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit. | `string` | n/a | yes |
| <a name="input_subscriptions"></a> [subscriptions](#input\_subscriptions) | List of application subscriptions to create in the subaccount (e.g., SAP Build Code, Process Automation). | <pre>list(object({<br>    app_name   = string<br>    plan_name  = string<br>    parameters = optional(map(string), {})<br>  }))</pre> | `[]` | no |
| <a name="input_trust_configuration"></a> [trust\_configuration](#input\_trust\_configuration) | Trust configuration for external Identity Provider (e.g., SAP IAS). Set to null to skip configuration. Only identity\_provider is required; origin and other attributes are computed. | <pre>object({<br>    identity_provider = string<br>  })</pre> | `null` | no |
| <a name="input_users"></a> [users](#input\_users) | Users and their roles provided by meshStack | <pre>list(object(<br>    {<br>      meshIdentifier = string<br>      username       = string<br>      firstName      = string<br>      lastName       = string<br>      email          = string<br>      euid           = string<br>      roles          = list(string)<br>    }<br>  ))</pre> | `[]` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | The meshStack workspace identifier. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_btp_subaccount_id"></a> [btp\_subaccount\_id](#output\_btp\_subaccount\_id) | n/a |
| <a name="output_btp_subaccount_login_link"></a> [btp\_subaccount\_login\_link](#output\_btp\_subaccount\_login\_link) | n/a |
| <a name="output_btp_subaccount_name"></a> [btp\_subaccount\_name](#output\_btp\_subaccount\_name) | n/a |
| <a name="output_btp_subaccount_region"></a> [btp\_subaccount\_region](#output\_btp\_subaccount\_region) | n/a |
| <a name="output_cloudfoundry_instance_id"></a> [cloudfoundry\_instance\_id](#output\_cloudfoundry\_instance\_id) | ID of the Cloud Foundry environment instance (if created) |
| <a name="output_cloudfoundry_instance_state"></a> [cloudfoundry\_instance\_state](#output\_cloudfoundry\_instance\_state) | State of the Cloud Foundry environment instance (if created) |
| <a name="output_entitlements"></a> [entitlements](#output\_entitlements) | Map of entitlements created for this subaccount |
| <a name="output_subscriptions"></a> [subscriptions](#output\_subscriptions) | Map of application subscriptions created in this subaccount |
| <a name="output_trust_configuration_origin"></a> [trust\_configuration\_origin](#output\_trust\_configuration\_origin) | Origin key of the configured trust configuration (if configured) |
<!-- END_TF_DOCS -->
