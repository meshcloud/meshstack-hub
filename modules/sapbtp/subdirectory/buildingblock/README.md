---
name: SAP BTP subdirectory
supportedPlatforms:
  - sapbtp
description: |
This building block Creates a subdirectory in SAP BTP.
---

# SAP BTP subdirectory

This Terraform module provisions a subdirectory in SAP Business Technology Platform (BTP).

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
| [btp_directory.child](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/directory) | resource |
| [btp_directories.all](https://registry.terraform.io/providers/SAP/btp/latest/docs/data-sources/directories) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_globalaccount"></a> [globalaccount](#input\_globalaccount) | The subdomain of the global account in which you want to manage resources. | `string` | n/a | yes |
| <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id) | The ID of the parent resource. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | The meshStack project identifier. | `string` | n/a | yes |
| <a name="input_subfolder"></a> [subfolder](#input\_subfolder) | The subfolder to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_btp_subdirectory_id"></a> [btp\_subdirectory\_id](#output\_btp\_subdirectory\_id) | n/a |
| <a name="output_btp_subdirectory_name"></a> [btp\_subdirectory\_name](#output\_btp\_subdirectory\_name) | n/a |
| <a name="output_project_folder"></a> [project\_folder](#output\_project\_folder) | n/a |
<!-- END_TF_DOCS -->