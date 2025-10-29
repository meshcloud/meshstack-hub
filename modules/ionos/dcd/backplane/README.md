# IONOS DCD Backplane

This backplane module sets up the foundational infrastructure for managing IONOS Data Center Designer (DCD) environments.

## Purpose

The backplane creates and manages:
- IONOS service users for Terraform operations
- Administrative groups with appropriate permissions
- Foundational access controls for DCD management

## Usage

```hcl
module "ionos_dcd_backplane" {
  source = "path/to/ionos/dcd/backplane"

  service_user_email = "terraform-service@company.com"
  initial_password   = var.service_password
  group_name         = "DCD-Terraform-Managers"

  # Authentication is handled via IONOS_TOKEN environment variable
}
```

## Outputs

The backplane provides outputs that can be used by building blocks:
- Service user credentials
- Group IDs for permission management
- Administrative user information

## Requirements

- IONOS Cloud account with administrative access
- Permissions to create users and groups
- API access enabled
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_ionoscloud"></a> [ionoscloud](#requirement\_ionoscloud) | ~> 6.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ionoscloud_group.dcd_managers](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/group) | resource |
| [ionoscloud_user.group_assignment](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/user) | resource |
| [ionoscloud_user.ionos_service_user](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/user) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_group_name"></a> [group\_name](#input\_group\_name) | Name of the IONOS group for DCD management | `string` | `"DCD-Managers"` | no |
| <a name="input_initial_password"></a> [initial\_password](#input\_initial\_password) | Initial password for the IONOS service user | `string` | n/a | yes |
| <a name="input_ionos_token"></a> [ionos\_token](#input\_ionos\_token) | IONOS API token for authentication | `string` | n/a | yes |
| <a name="input_service_user_email"></a> [service\_user\_email](#input\_service\_user\_email) | Email address for the IONOS service user | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dcd_managers_group_id"></a> [dcd\_managers\_group\_id](#output\_dcd\_managers\_group\_id) | ID of the DCD managers group |
| <a name="output_dcd_managers_group_name"></a> [dcd\_managers\_group\_name](#output\_dcd\_managers\_group\_name) | Name of the DCD managers group |
| <a name="output_service_user_email"></a> [service\_user\_email](#output\_service\_user\_email) | Email of the IONOS service user |
| <a name="output_service_user_id"></a> [service\_user\_id](#output\_service\_user\_id) | ID of the IONOS service user |
<!-- END_TF_DOCS -->