---
name: OCI Application Compartment
supportedPlatforms:
  - oci
description: |
  Creates an application compartment with IAM groups and policies for team-based access control.
---

# OCI Application Compartment Building Block

Creates an application compartment with IAM groups and policies for team-based access control.

## Features

- **Application Compartment**: Creates a compartment for application workloads
- **Conditional Placement**: Places compartments based on meshStack project tags
- **Flexible Configuration**: Tag names and compartment mappings configurable via YAML
- **IAM Groups**: Three groups with different access levels (readers, users, admins)
- **Access Policies**: Granular permissions for each group

## Access Levels

### Readers
- Read-only access to all resources in the compartment

### Users
- Manage compute instances, storage, networking, and load balancers
- Read all resources

### Admins
- Full management access to all resources in the compartment

## Compartment Placement Logic

The module determines the parent compartment based on meshStack project tags configured in the `tag_relations` variable:

1. **Sandbox Landing Zone**: Always uses sandbox compartment, regardless of environment
2. **Cloud-Native Landing Zone**: Uses environment-specific compartments (dev/qa/test/prod)
3. **Fallback**: Uses default compartment if no tags match

## Usage

### Basic Usage

```hcl
module "application_compartment" {
  source = "./application-compartment"

  tenancy_ocid = var.tenancy_ocid
  foundation   = "my-foundation"
  workspace_id = "my-workspace"
  project_id   = "my-project"
  region       = "eu-frankfurt-1"
  users        = var.users
}
```

The module uses default tag names (`Environment`, `landingzone_family`) and placeholder compartment IDs.

### Custom Configuration

Override the `tag_relations` variable to customize tag names and compartment mappings:

```hcl
module "application_compartment" {
  source = "./application-compartment"

  tenancy_ocid = var.tenancy_ocid
  foundation   = "my-foundation"
  workspace_id = "my-workspace"
  project_id   = "my-project"
  region       = "eu-frankfurt-1"
  users        = var.users

  tag_relations = <<-EOT
    # meshStack tag names to read
    tag_names:
      environment: "Environment"
      landing_zone: "landingzone_family"

    # Landing zone configurations
    landing_zones:
      # Sandbox: single compartment for all environments
      sandbox:
        compartment_id: "ocid1.compartment.oc1..aaaaaaaa...sandbox"

      # Cloud-native: per-environment compartments
      cloud-native:
        environments:
          dev:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-dev"
          qa:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-qa"
          test:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-test"
          prod:
            compartment_id: "ocid1.compartment.oc1..aaaaaaaa...cloudnative-prod"

    # Fallback if no match
    default_compartment_id: "ocid1.compartment.oc1..aaaaaaaa...default"
  EOT
}
```

## Configuration Structure

The `tag_relations` variable accepts YAML with the following structure:

```yaml
# Which meshStack tags to read
tag_names:
  environment: "Environment"              # Tag name for environment
  landing_zone: "landingzone_family"      # Tag name for landing zone family

# Compartment mappings per landing zone
# The landing zone names here match the values in your meshStack tags
landing_zones:
  sandbox:                                # When landing_zone tag = "sandbox"
    compartment_id: "ocid1.compartment..."  # Single compartment (no environments)

  cloud-native:                           # When landing_zone tag = "cloud-native"
    environments:                         # Per-environment compartments
      dev:
        compartment_id: "ocid1.compartment..."
      qa:
        compartment_id: "ocid1.compartment..."
      test:
        compartment_id: "ocid1.compartment..."
      prod:
        compartment_id: "ocid1.compartment..."

# Default fallback compartment
default_compartment_id: "ocid1.compartment..."
```

**Important**:
- The keys under `landing_zones` (e.g., `sandbox`, `cloud-native`) must match the **values** in your meshStack `landingzone_family` tag
- Landing zones without an `environments` section will use the same compartment for all environments
- Landing zones with an `environments` section will route based on the environment tag value

## meshStack Integration

The module automatically:
1. Fetches project metadata from meshStack using `workspace_id` and `project_id`
2. Reads tags from the project (format: `map(list(string))`)
3. Extracts tag values based on `tag_names` configuration
4. Selects the appropriate compartment based on landing zone and environment

## Example Tag Scenarios

| meshStack Tags | Selected Compartment |
|----------------|---------------------|
| `landingzone_family: ["sandbox"]`, `Environment: ["dev"]` | `landing_zones.sandbox.compartment_id` |
| `landingzone_family: ["sandbox"]`, `Environment: ["prod"]` | `landing_zones.sandbox.compartment_id` |
| `landingzone_family: ["cloud-native"]`, `Environment: ["dev"]` | `landing_zones.cloud-native.environments.dev.compartment_id` |
| `landingzone_family: ["cloud-native"]`, `Environment: ["prod"]` | `landing_zones.cloud-native.environments.prod.compartment_id` |
| No matching tags | `default_compartment_id` |

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [oci_identity_compartment.application](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_compartment) | resource |
| [oci_identity_group.admins](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_group) | resource |
| [oci_identity_group.readers](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_group) | resource |
| [oci_identity_group.users](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_group) | resource |
| [oci_identity_policy.application](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_policy) | resource |
| [oci_identity_user_group_membership.admins](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_user_group_membership) | resource |
| [oci_identity_user_group_membership.readers](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_user_group_membership) | resource |
| [oci_identity_user_group_membership.users](https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/identity_user_group_membership) | resource |
| [meshstack_project.project](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/project) | data source |
| [oci_identity_users.all_users](https://registry.terraform.io/providers/oracle/oci/latest/docs/data-sources/identity_users) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_foundation"></a> [foundation](#input\_foundation) | Foundation name prefix | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project identifier (e.g., application name) | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | OCI region identifier (e.g., eu-frankfurt-1, us-ashburn-1) | `string` | n/a | yes |
| <a name="input_tag_relations"></a> [tag\_relations](#input\_tag\_relations) | YAML configuration for tag-based compartment mapping | `string` | `"# meshStack tag names to read\ntag_names:\n  environment: \"Environment\"\n  landing_zone: \"landingzone_family\"\n\n# Landing zone configurations\nlanding_zones:\n  # Sandbox: single compartment for all environments\n  sandbox:\n    compartment_id: \"ocid1.compartment.oc1..aaaaaaaa...sandbox\"\n      \n  # Cloud-native: per-environment compartments\n  cloud-native:\n    environments:\n      dev:\n        compartment_id: \"ocid1.compartment.oc1..aaaaaaaa...cloudnative-dev\"\n      qa:\n        compartment_id: \"ocid1.compartment.oc1..aaaaaaaa...cloudnative-qa\"\n      test:\n        compartment_id: \"ocid1.compartment.oc1..aaaaaaaa...cloudnative-test\"\n      prod:\n        compartment_id: \"ocid1.compartment.oc1..aaaaaaaa...cloudnative-prod\"\n\n# Fallback if no match\ndefault_compartment_id: \"ocid1.compartment.oc1..aaaaaaaa...default\"\n"` | no |
| <a name="input_tenancy_ocid"></a> [tenancy\_ocid](#input\_tenancy\_ocid) | OCID of the OCI tenancy | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from authoritative system | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_workspace_id"></a> [workspace\_id](#input\_workspace\_id) | Workspace identifier (e.g., team name or business unit) | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_admin_group_id"></a> [admin\_group\_id](#output\_admin\_group\_id) | OCID of the admins group |
| <a name="output_admin_group_name"></a> [admin\_group\_name](#output\_admin\_group\_name) | Name of the admins group |
| <a name="output_compartment_id"></a> [compartment\_id](#output\_compartment\_id) | OCID of the created application compartment |
| <a name="output_compartment_name"></a> [compartment\_name](#output\_compartment\_name) | Name of the created application compartment |
| <a name="output_console_url"></a> [console\_url](#output\_console\_url) | OCI Console URL for direct access to the compartment |
| <a name="output_policy_id"></a> [policy\_id](#output\_policy\_id) | OCID of the access policy |
| <a name="output_reader_group_id"></a> [reader\_group\_id](#output\_reader\_group\_id) | OCID of the readers group |
| <a name="output_reader_group_name"></a> [reader\_group\_name](#output\_reader\_group\_name) | Name of the readers group |
| <a name="output_user_group_id"></a> [user\_group\_id](#output\_user\_group\_id) | OCID of the users group |
| <a name="output_user_group_name"></a> [user\_group\_name](#output\_user\_group\_name) | Name of the users group |
<!-- END_TF_DOCS -->
