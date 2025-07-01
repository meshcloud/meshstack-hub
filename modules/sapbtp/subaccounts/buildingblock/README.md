---
name: SAP BTP subaccount
supportedPlatforms:
  - sapbtp
description: |
  This building block Creates a subaccount in SAP BTP.
---

# SAP BTP subaccount with environment configuration

This Terraform module provisions a subaccount in SAP Business Technology Platform (BTP).

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
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | 0.7.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [btp_directory.child](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/directory) | resource |
| [btp_subaccount.subaccount](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_admin](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_service_admininstrator](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_viewer](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_directories.all](https://registry.terraform.io/providers/SAP/btp/latest/docs/data-sources/directories) | data source |
| [meshstack_project.example](https://registry.terraform.io/providers/meshcloud/meshstack/0.7.1/docs/data-sources/project) | data source |
| [meshstack_tag_definition.example](https://registry.terraform.io/providers/meshcloud/meshstack/0.7.1/docs/data-sources/tag_definition) | data source |
| [meshstack_tag_definitions.all](https://registry.terraform.io/providers/meshcloud/meshstack/0.7.1/docs/data-sources/tag_definitions) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_globalaccount"></a> [globalaccount](#input\_globalaccount) | The subdomain of the global account in which you want to manage resources. | `string` | n/a | yes |
| <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id) | The ID of the parent resource. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | The meshStack project identifier. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region of the subaccount. | `string` | `"eu30"` | no |
| <a name="input_subfolder"></a> [subfolder](#input\_subfolder) | The subfolder to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | Users and their roles provided by meshStack | <pre>list(object(<br/>    {<br/>      meshIdentifier = string<br/>      username       = string<br/>      firstName      = string<br/>      lastName       = string<br/>      email          = string<br/>      euid           = string<br/>      roles          = list(string)<br/>    }<br/>  ))</pre> | `[]` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | The meshStack workspace identifier. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_btp_subaccount_id"></a> [btp\_subaccount\_id](#output\_btp\_subaccount\_id) | n/a |
| <a name="output_btp_subaccount_login_link"></a> [btp\_subaccount\_login\_link](#output\_btp\_subaccount\_login\_link) | n/a |
| <a name="output_btp_subaccount_name"></a> [btp\_subaccount\_name](#output\_btp\_subaccount\_name) | n/a |
| <a name="output_btp_subaccount_region"></a> [btp\_subaccount\_region](#output\_btp\_subaccount\_region) | n/a |
| <a name="output_subfolders"></a> [subfolders](#output\_subfolders) | n/a |
<!-- END_TF_DOCS -->
