---
name: STACKIT Project
supportedPlatforms:
  - stackit
description: |
  Creates a new STACKIT project and manages user access permissions with configurable role-based access control.
---

# STACKIT Project Building Block

This Terraform module provisions a STACKIT project with user access control. meshStack roles from the `users` input are mapped to STACKIT project roles via the configurable `role_mapping` input. When used through the meshStack integration, a pre-run script performs best-effort STACKIT organization onboarding for all assigned users before project-level role assignments are applied and writes a summary that marks users with ✅ when the required organization role is currently assigned.

## Requirements

- Terraform `>= 1.11.0`
- STACKIT Provider `>= 0.98.0`

## Providers

Authentication uses Workload Identity Federation (OIDC token exchange) — no long-lived
service account key. meshStack injects the federated token file and sets `STACKIT_USE_OIDC`
and `STACKIT_FEDERATED_TOKEN_FILE` in the environment.

```hcl
terraform {
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0"
    }
  }
}

provider "stackit" {
  service_account_email = var.service_account_email
  use_oidc              = true
  experiments           = ["iam"] # Required for authorization resources
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_project_role_assignment.role_assignments](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_resourcemanager_project.project](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | The environment type (production, staging, development). If not set, uses parent\_container\_id directly. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the project. Use 'networkArea' to specify the STACKIT Network Area. | `map(string)` | `{}` | no |
| <a name="input_parent_container_id"></a> [parent\_container\_id](#input\_parent\_container\_id) | The parent container ID (organization or folder) where the project will be created. | `string` | n/a | yes |
| <a name="input_parent_container_ids"></a> [parent\_container\_ids](#input\_parent\_container\_ids) | Parent container IDs for different environments. If environment is set, the corresponding container ID will be used. | <pre>object({<br/>    production  = optional(string)<br/>    staging     = optional(string)<br/>    development = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the StackIt project to create. | `string` | n/a | yes |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Maps meshStack roles from `users[*].roles` to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names. Unknown meshStack roles are ignored. | `map(list(string))` | <pre>{<br/>  "admin": [<br/>    "owner"<br/>  ],<br/>  "reader": [<br/>    "reader"<br/>  ],<br/>  "user": [<br/>    "editor"<br/>  ]<br/>}</pre> | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | Email of the STACKIT service account for WIF-based authentication and project ownership. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to STACKIT project roles via `role_mapping`. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_id"></a> [container\_id](#output\_container\_id) | The user-friendly container ID of the created StackIt project. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The UUID of the created StackIt project. |
| <a name="output_project_name"></a> [project\_name](#output\_project\_name) | The name of the created StackIt project. |
| <a name="output_project_url"></a> [project\_url](#output\_project\_url) | The deep link URL to access the project in the StackIt portal. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of STACKIT organization membership onboarding for assigned project users. |
<!-- END_TF_DOCS -->