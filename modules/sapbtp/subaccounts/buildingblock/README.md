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
- **Cloud Foundry Services**: Provision service instances (PostgreSQL, Redis, Destination, XSUAA, etc.)
- **Trust Configuration**: External Identity Provider integration (SAP IAS, custom IdP)

## Usage Examples

### Basic Subaccount with Applications

```hcl
entitlements = [
  {
    service_name = "build-code"
    plan_name    = "standard"
  }
]

subscriptions = [
  {
    app_name   = "build-code"
    plan_name  = "standard"
    parameters = {}
  }
]
```

### Development Environment with Cloud Foundry Services

```hcl
entitlements = [
  {
    service_name = "hana-cloud"
    plan_name    = "hana"
    amount       = 1
  },
  {
    service_name = "PostgreSQL"
    plan_name    = "small"
    amount       = 1
  },
  {
    service_name = "destination"
    plan_name    = "lite"
  },
  {
    service_name = "xsuaa"
    plan_name    = "application"
  }
]

cloudfoundry_instance = {
  name      = "dev-cf"
  plan_name = "standard"
}

cloudfoundry_services = {
  postgresql_instances = [
    {
      name       = "my-postgres-db"
      plan_name  = "small"
      parameters = {}
    }
  ]
  xsuaa_instances = [
    {
      name       = "my-xsuaa"
      plan_name  = "application"
      parameters = {
        xsappname = "my-app"
      }
    }
  ]
}
```

## Common SAP BTP Services

### Popular Application Subscriptions

| Application Name | Service Name | Common Plans | Description |
|-----------------|--------------|--------------|-------------|
| SAP Build Work Zone | `SAPLaunchpad` | `standard` | Central entry point for applications |
| SAP Build Code | `build-code` | `standard`, `free` | Low-code development platform |
| SAP Build Apps | `sap-build-apps` | `standard`, `free` | No-code app builder |
| SAP Build Process Automation | `process-automation` | `standard` | Process automation and RPA |
| SAP Integration Suite | `integrationsuite` | `enterprise_agreement` | Integration and API management |
| SAP Business Application Studio | `sapappstudio` | `standard-edition` | Web-based IDE |
| SAP HANA Cloud | `hana-cloud` | `hana`, `hana-cloud-connection` | In-memory database |
| SAP Cloud Transport Management | `cloud-transport-management` | `standard` | Transport management |
| SAP Continuous Integration & Delivery | `cicd-app` | `default` | CI/CD pipeline service |
| SAP Mobile Services | `mobile-services` | `standard` | Mobile app development |
| SAP Document Management Service | `sdm` | `standard` | Document storage and management |

### Cloud Foundry Services (Entitlements)

**Services requiring `amount` parameter (quota-based):**
- `PostgreSQL` - PostgreSQL database (plans: small, medium, large)
- `Redis` - Redis cache (plans: small, medium, large)
- `hana-cloud` - HANA Cloud database (plans: hana)
- `auditlog-viewer` - Audit log service (plans: default)

**Services without `amount` parameter (enable-only):**
- `destination` - Destination configuration (plans: lite)
- `connectivity` - Cloud Connector integration (plans: lite)
- `xsuaa` - Authentication & Authorization (plans: application, broker)
- `application-logs` - Application logging (plans: lite)
- `html5-apps-repo` - HTML5 application hosting (plans: app-host, app-runtime)
- `job-scheduler` - Job scheduling service (plans: lite, standard)
- `credstore` - Credential storage (plans: free, standard)
- `objectstore` - Object storage S3-compatible (plans: s3-standard)

## Cloud Foundry Service Instances

When `cloudfoundry_instance` is configured, you can provision service instances:

```hcl
cloudfoundry_services = {
  postgresql_instances = [
    {
      name       = "my-postgres"
      plan_name  = "small"
      parameters = {}
    }
  ]
  xsuaa_instances = [
    {
      name       = "my-xsuaa"
      plan_name  = "application"
      parameters = {
        xsappname = "my-app"
      }
    }
  ]
}
```

Supported: postgresql_instances, redis_instances, destination_instances, connectivity_instances, xsuaa_instances, application_logs_instances, html5_repo_instances, job_scheduler_instances, credstore_instances, objectstore_instances

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
| [btp_subaccount_entitlement.entitlement_with_quota](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_entitlement) | resource |
| [btp_subaccount_entitlement.entitlement_without_quota](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_entitlement) | resource |
| [btp_subaccount_environment_instance.cloudfoundry](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_environment_instance) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_admin](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_service_admininstrator](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_viewer](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_service_instance.cf_service](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_service_instance) | resource |
| [btp_subaccount_subscription.subscription](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_subscription) | resource |
| [btp_subaccount_trust_configuration.custom_idp](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_trust_configuration) | resource |
| [btp_directories.all](https://registry.terraform.io/providers/SAP/btp/latest/docs/data-sources/directories) | data source |
| [btp_subaccount_service_plan.cf_service_plan](https://registry.terraform.io/providers/SAP/btp/latest/docs/data-sources/subaccount_service_plan) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cf_services"></a> [cf\_services](#input\_cf\_services) | Comma-separated list of Cloud Foundry service instances in format: service.plan (e.g., 'postgresql.small,destination.lite,redis.medium') | `string` | `""` | no |
| <a name="input_cloudfoundry_plan"></a> [cloudfoundry\_plan](#input\_cloudfoundry\_plan) | Cloud Foundry environment plan (standard or trial) | `string` | `"standard"` | no |
| <a name="input_cloudfoundry_space_name"></a> [cloudfoundry\_space\_name](#input\_cloudfoundry\_space\_name) | Name for the Cloud Foundry space | `string` | `"dev"` | no |
| <a name="input_enable_cloudfoundry"></a> [enable\_cloudfoundry](#input\_enable\_cloudfoundry) | Enable Cloud Foundry environment in the subaccount | `bool` | `false` | no |
| <a name="input_entitlements"></a> [entitlements](#input\_entitlements) | Comma-separated list of service entitlements in format: service.plan (e.g., 'postgresql-db.trial,destination.lite,xsuaa.application') | `string` | `""` | no |
| <a name="input_globalaccount"></a> [globalaccount](#input\_globalaccount) | The subdomain of the global account in which you want to manage resources. | `string` | n/a | yes |
| <a name="input_identity_provider"></a> [identity\_provider](#input\_identity\_provider) | Custom identity provider origin (e.g., mytenant.accounts.ondemand.com). Leave empty to skip trust configuration. | `string` | `""` | no |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | The meshStack project identifier. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region of the subaccount. | `string` | `"eu10"` | no |
| <a name="input_subfolder"></a> [subfolder](#input\_subfolder) | The subfolder to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit. | `string` | `""` | no |
| <a name="input_subscriptions"></a> [subscriptions](#input\_subscriptions) | Comma-separated list of application subscriptions in format: app.plan (e.g., 'build-workzone.standard,integrationsuite.enterprise\_agreement') | `string` | `""` | no |
| <a name="input_users"></a> [users](#input\_users) | Users and their roles provided by meshStack | <pre>list(object(<br>    {<br>      meshIdentifier = string<br>      username       = string<br>      firstName      = string<br>      lastName       = string<br>      email          = string<br>      euid           = string<br>      roles          = list(string)<br>    }<br>  ))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_btp_subaccount_id"></a> [btp\_subaccount\_id](#output\_btp\_subaccount\_id) | n/a |
| <a name="output_btp_subaccount_login_link"></a> [btp\_subaccount\_login\_link](#output\_btp\_subaccount\_login\_link) | n/a |
| <a name="output_btp_subaccount_name"></a> [btp\_subaccount\_name](#output\_btp\_subaccount\_name) | n/a |
| <a name="output_btp_subaccount_region"></a> [btp\_subaccount\_region](#output\_btp\_subaccount\_region) | n/a |
| <a name="output_cloudfoundry_instance_id"></a> [cloudfoundry\_instance\_id](#output\_cloudfoundry\_instance\_id) | ID of the Cloud Foundry environment instance (if created) |
| <a name="output_cloudfoundry_instance_state"></a> [cloudfoundry\_instance\_state](#output\_cloudfoundry\_instance\_state) | State of the Cloud Foundry environment instance (if created) |
| <a name="output_cloudfoundry_services"></a> [cloudfoundry\_services](#output\_cloudfoundry\_services) | Map of Cloud Foundry service instances created in this subaccount |
| <a name="output_entitlements"></a> [entitlements](#output\_entitlements) | Map of entitlements created for this subaccount |
| <a name="output_subscriptions"></a> [subscriptions](#output\_subscriptions) | Map of application subscriptions created in this subaccount |
| <a name="output_trust_configuration_origin"></a> [trust\_configuration\_origin](#output\_trust\_configuration\_origin) | Origin key of the configured trust configuration (if configured) |
<!-- END_TF_DOCS -->
