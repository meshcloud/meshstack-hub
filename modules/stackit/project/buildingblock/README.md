---
name: StackIt Project
supportedPlatforms:
  - stackit
description: |
  Creates a new StackIt project and manages user access permissions with role-based access control.
---

# StackIt Project Building Block

This Terraform module provisions a StackIt project with user access control.

## Requirements

- Terraform `>= 1.6.0`
- StackIt Provider `>= 0.60.0`

## Providers

```hcl
terraform {
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.60.0"
    }
  }
}

provider "stackit" {
  service_account_key_path = "/path/to/service-account-key.json"
  experiments             = ["iam"]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.60.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_authorization_project_role_assignment.admin_assignments](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_authorization_project_role_assignment.reader_assignments](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_authorization_project_role_assignment.user_assignments](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [stackit_resourcemanager_project.project](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/resourcemanager_project) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_environment"></a> [environment](#input\_environment) | The environment type (production, staging, development). If not set, uses parent\_container\_id directly. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels to apply to the project. Use 'networkArea' to specify the STACKIT Network Area. | `map(string)` | `{}` | no |
| <a name="input_parent_container_id"></a> [parent\_container\_id](#input\_parent\_container\_id) | The parent container ID (organization or folder) where the project will be created. | `string` | n/a | yes |
| <a name="input_parent_container_ids"></a> [parent\_container\_ids](#input\_parent\_container\_ids) | Parent container IDs for different environments. If environment is set, the corresponding container ID will be used. | <pre>object({<br>    production  = optional(string)<br>    staging     = optional(string)<br>    development = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | The name of the StackIt project to create. | `string` | n/a | yes |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | The email address of the service account that will own this project. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from authoritative system | <pre>list(object({<br>    meshIdentifier = string<br>    username       = string<br>    firstName      = string<br>    lastName       = string<br>    email          = string<br>    euid           = string<br>    roles          = list(string)<br>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_id"></a> [container\_id](#output\_container\_id) | The user-friendly container ID of the created StackIt project. |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | The UUID of the created StackIt project. |
| <a name="output_project_name"></a> [project\_name](#output\_project\_name) | The name of the created StackIt project. |
| <a name="output_project_url"></a> [project\_url](#output\_project\_url) | The deep link URL to access the project in the StackIt portal. |
<!-- END_TF_DOCS -->