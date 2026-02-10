---
name: AKS Starter Kit - Azure DevOps
supportedPlatforms:
  - aks
description: Provides a complete AKS development environment with Azure DevOps project, Git repository, CI/CD pipelines, and separate dev/prod namespaces with passwordless authentication.
---

# AKS Starter Kit - Azure DevOps

This building block creates a complete AKS application development environment integrated with Azure DevOps, including:

- **Azure DevOps Project**: Dedicated project with role-based access control
- **Git Repository**: Initialized with application templates and deployment manifests
- **Dev Environment**: meshStack project + AKS namespace + service connection + pipeline
- **Prod Environment**: meshStack project + AKS namespace + service connection + pipeline
- **CI/CD Pipelines**: Automated deployments triggered by branch commits
- **Service Connections**: Passwordless authentication using Workload Identity Federation

## Architecture

```
Azure DevOps Project
├── Git Repository
├── Dev Pipeline (main branch) → Dev AKS Namespace
└── Prod Pipeline (release branch) → Prod AKS Namespace
```

## Resources Created

### Azure DevOps Resources
- **Project**: Container for all Azure DevOps resources
- **Repository**: Git repository with application code and manifests
- **Pipelines**: Two pipelines (dev and prod) with separate triggers

### meshStack Resources
- **Dev Project + Tenant**: Development AKS namespace
- **Prod Project + Tenant**: Production AKS namespace
- **Service Connections**: Azure service connections for both environments
- **User Bindings**: Creator assigned as Project Admin on both projects

## Deployment Flow

### Development
1. Developer commits to `main` branch
2. Dev pipeline triggers automatically
3. Builds container image
4. Scans with security tools
5. Deploys to dev AKS namespace

### Production
1. Developer creates PR from `main` to `release`
2. PR review and merge
3. Prod pipeline triggers
4. Same build and scan process
5. Requires manual authorization (first run)
6. Deploys to prod AKS namespace

## Security Features

- **Workload Identity Federation**: Passwordless authentication between Azure DevOps and Azure
- **Branch Policies**: Enforced code reviews on main branch
- **Manual Authorization**: Production deployments require explicit approval
- **Least Privilege**: Service principals have minimal required permissions
- **Separate Environments**: Isolated dev and prod namespaces

## Prerequisites

The following must be configured before using this building block:

1. **Azure DevOps Organization**: Active organization with PAT token stored in Key Vault
2. **Service Principals**: Pre-created for dev and prod environments with appropriate role assignments
3. **AKS Landing Zones**: Configured landing zones for dev and prod
4. **Building Block Definitions**: Azure DevOps project, repository, pipeline, and service connection definitions must exist

## Variables

### Required Variables

- `workspace_identifier`: meshStack workspace
- `name`: Name for projects, repository, and namespaces
- `full_platform_identifier`: AKS platform identifier
- `landing_zone_dev_identifier`: Dev AKS landing zone
- `landing_zone_prod_identifier`: Prod AKS landing zone
- `azdevops_*_definition_*_uuid`: UUIDs for all Azure DevOps building block definitions
- `azdevops_organization_name`: Azure DevOps organization name
- `creator`: Creator user information for RBAC
- `dev_azure_subscription_id`: Azure subscription for dev
- `dev_service_principal_id`: Service principal for dev
- `dev_application_object_id`: Azure AD app object ID for dev
- `prod_azure_subscription_id`: Azure subscription for prod
- `prod_service_principal_id`: Service principal for prod
- `prod_application_object_id`: Azure AD app object ID for prod
- `azure_tenant_id`: Azure AD tenant ID

### Optional Variables

- `project_tags_yaml`: YAML configuration for project tags (default: empty)
- `repository_init_type`: Repository initialization (Clean or Import, default: Clean)
- `enable_branch_policies`: Enable branch policies (default: true)
- `minimum_reviewers`: Minimum PR reviewers (default: 1)

## Outputs

- `dev_link`: URL to dev environment application
- `prod_link`: URL to prod environment application
- `azdevops_project_url`: Azure DevOps project URL
- `azdevops_repository_url`: Git repository URL
- `summary`: Detailed summary with next steps and resource links

## Integration with Other Building Blocks

This starter kit orchestrates multiple building blocks:

1. **Azure DevOps Project** (`azuredevops/project`)
2. **Azure DevOps Repository** (`azuredevops/repository`)
3. **Azure DevOps Pipeline** (2x - `azuredevops/pipeline`)
4. **Azure DevOps Service Connection** (2x - `azuredevops/service-connection-subscription`)

Parent-child relationships ensure proper dependency ordering and resource cleanup.

## Best Practices

### Naming Convention
The `name` variable is normalized to create consistent identifiers:
- Special characters removed
- Converted to lowercase
- Spaces/hyphens normalized
- Random suffix added to ensure uniqueness

### Branch Strategy
- `main`: Development work, auto-deploys to dev
- `release`: Production releases, auto-deploys to prod
- Feature branches: Create from main, merge back to main

### Service Connections
- Dev: Auto-authorized for faster development iteration
- Prod: Manual authorization for enhanced security

### Project Tags
Use `project_tags_yaml` to apply consistent tagging across dev and prod projects for cost allocation and governance.

## Troubleshooting

### Pipeline Authorization Required
**Symptom**: Prod pipeline pauses asking for resource authorization

**Solution**: This is expected on first run. Click "View" → "Permit" to authorize the service connection.

### Service Connection Invalid
**Symptom**: Pipeline fails with authentication error

**Solution**: Verify service principals exist and have correct role assignments. Contact platform team.

### Repository Not Initialized
**Symptom**: Empty repository created

**Solution**: Verify `repository_init_type` is set to "Clean" or "Import". For Import, ensure template repository is accessible.

## Maintenance

### Updating Pipeline YAML
Pipelines reference `azure-pipelines-dev.yml` and `azure-pipelines-prod.yml` in the repository. Modify these files to customize the CI/CD process.

### Adding New Environments
To add staging or other environments:
1. Create new meshStack project and tenant
2. Add service connection building block
3. Add pipeline building block with appropriate branch trigger

### Service Principal Rotation
Service principals use Workload Identity Federation (OIDC). No credential rotation is required - authentication is passwordless.

## Related Documentation

- [Azure DevOps Pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/)
- [Workload Identity Federation](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [meshStack Building Blocks](https://docs.meshcloud.io/docs/meshstack.building-blocks.html)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | 0.15.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [meshstack_building_block_v2.azdevops_project](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.pipeline_dev](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.pipeline_prod](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.repository](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.service_connection_dev](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/building_block_v2) | resource |
| [meshstack_building_block_v2.service_connection_prod](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/building_block_v2) | resource |
| [meshstack_project.dev](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/project) | resource |
| [meshstack_project.prod](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/project) | resource |
| [meshstack_project_user_binding.creator_dev_admin](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/project_user_binding) | resource |
| [meshstack_project_user_binding.creator_prod_admin](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/project_user_binding) | resource |
| [meshstack_tenant_v4.dev](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/tenant_v4) | resource |
| [meshstack_tenant_v4.prod](https://registry.terraform.io/providers/meshcloud/meshstack/0.15.0/docs/resources/tenant_v4) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azdevops_organization_name"></a> [azdevops\_organization\_name](#input\_azdevops\_organization\_name) | Azure DevOps organization name. Used only for display purposes. | `string` | n/a | yes |
| <a name="input_azdevops_pipeline_definition_uuid"></a> [azdevops\_pipeline\_definition\_uuid](#input\_azdevops\_pipeline\_definition\_uuid) | UUID of the Azure DevOps pipeline building block definition. | `string` | n/a | yes |
| <a name="input_azdevops_pipeline_definition_version_uuid"></a> [azdevops\_pipeline\_definition\_version\_uuid](#input\_azdevops\_pipeline\_definition\_version\_uuid) | UUID of the Azure DevOps pipeline building block definition version. | `string` | n/a | yes |
| <a name="input_azdevops_project_definition_uuid"></a> [azdevops\_project\_definition\_uuid](#input\_azdevops\_project\_definition\_uuid) | UUID of the Azure DevOps project building block definition. | `string` | n/a | yes |
| <a name="input_azdevops_project_definition_version_uuid"></a> [azdevops\_project\_definition\_version\_uuid](#input\_azdevops\_project\_definition\_version\_uuid) | UUID of the Azure DevOps project building block definition version. | `string` | n/a | yes |
| <a name="input_azdevops_repository_definition_uuid"></a> [azdevops\_repository\_definition\_uuid](#input\_azdevops\_repository\_definition\_uuid) | UUID of the Azure DevOps repository building block definition. | `string` | n/a | yes |
| <a name="input_azdevops_repository_definition_version_uuid"></a> [azdevops\_repository\_definition\_version\_uuid](#input\_azdevops\_repository\_definition\_version\_uuid) | UUID of the Azure DevOps repository building block definition version. | `string` | n/a | yes |
| <a name="input_azdevops_service_connection_definition_uuid"></a> [azdevops\_service\_connection\_definition\_uuid](#input\_azdevops\_service\_connection\_definition\_uuid) | UUID of the Azure DevOps service connection building block definition. | `string` | n/a | yes |
| <a name="input_azdevops_service_connection_definition_version_uuid"></a> [azdevops\_service\_connection\_definition\_version\_uuid](#input\_azdevops\_service\_connection\_definition\_version\_uuid) | UUID of the Azure DevOps service connection building block definition version. | `string` | n/a | yes |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | Azure AD tenant ID | `string` | n/a | yes |
| <a name="input_creator"></a> [creator](#input\_creator) | Information about the creator of the resources who will be assigned Project Admin role | <pre>object({<br>    type        = string<br>    identifier  = string<br>    displayName = string<br>    username    = optional(string)<br>    email       = optional(string)<br>    euid        = optional(string)<br>  })</pre> | n/a | yes |
| <a name="input_dev_application_object_id"></a> [dev\_application\_object\_id](#input\_dev\_application\_object\_id) | Azure AD application object ID for the development service principal | `string` | n/a | yes |
| <a name="input_dev_azure_subscription_id"></a> [dev\_azure\_subscription\_id](#input\_dev\_azure\_subscription\_id) | Azure subscription ID for the development environment | `string` | n/a | yes |
| <a name="input_dev_service_principal_id"></a> [dev\_service\_principal\_id](#input\_dev\_service\_principal\_id) | Service principal client ID for the development environment | `string` | n/a | yes |
| <a name="input_enable_branch_policies"></a> [enable\_branch\_policies](#input\_enable\_branch\_policies) | Enable branch policies for the main branch (minimum reviewers, work item linking) | `bool` | `true` | no |
| <a name="input_full_platform_identifier"></a> [full\_platform\_identifier](#input\_full\_platform\_identifier) | Full platform identifier of the AKS Namespace platform. | `string` | n/a | yes |
| <a name="input_landing_zone_dev_identifier"></a> [landing\_zone\_dev\_identifier](#input\_landing\_zone\_dev\_identifier) | AKS Landing zone identifier for the development tenant. | `string` | n/a | yes |
| <a name="input_landing_zone_prod_identifier"></a> [landing\_zone\_prod\_identifier](#input\_landing\_zone\_prod\_identifier) | AKS Landing zone identifier for the production tenant. | `string` | n/a | yes |
| <a name="input_minimum_reviewers"></a> [minimum\_reviewers](#input\_minimum\_reviewers) | Minimum number of reviewers required for pull requests | `number` | `1` | no |
| <a name="input_name"></a> [name](#input\_name) | This name will be used for the created projects, app subdomain, Azure DevOps project and repository. | `string` | n/a | yes |
| <a name="input_prod_application_object_id"></a> [prod\_application\_object\_id](#input\_prod\_application\_object\_id) | Azure AD application object ID for the production service principal | `string` | n/a | yes |
| <a name="input_prod_azure_subscription_id"></a> [prod\_azure\_subscription\_id](#input\_prod\_azure\_subscription\_id) | Azure subscription ID for the production environment | `string` | n/a | yes |
| <a name="input_prod_service_principal_id"></a> [prod\_service\_principal\_id](#input\_prod\_service\_principal\_id) | Service principal client ID for the production environment | `string` | n/a | yes |
| <a name="input_project_tags_yaml"></a> [project\_tags\_yaml](#input\_project\_tags\_yaml) | YAML configuration for project tags that will be applied to dev and prod projects. Expected structure:<pre>yaml<br>dev:<br>  key1:<br>    - "value1"<br>    - "value2"<br>  key2:<br>    - "value3"<br>prod:<br>  key1:<br>    - "value4"<br>  key2:<br>    - "value5"<br>    - "value6"</pre> | `string` | `"dev: {}\nprod: {}\n"` | no |
| <a name="input_repository_init_type"></a> [repository\_init\_type](#input\_repository\_init\_type) | Repository initialization type (Clean or Import) | `string` | `"Clean"` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | meshStack workspace identifier | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azdevops_project_url"></a> [azdevops\_project\_url](#output\_azdevops\_project\_url) | URL of the created Azure DevOps project |
| <a name="output_azdevops_repository_url"></a> [azdevops\_repository\_url](#output\_azdevops\_repository\_url) | URL of the created Azure DevOps repository |
| <a name="output_dev_link"></a> [dev\_link](#output\_dev\_link) | Link to the dev environment application |
| <a name="output_prod_link"></a> [prod\_link](#output\_prod\_link) | Link to the prod environment application |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with next steps and insights into created resources |
<!-- END_TF_DOCS -->