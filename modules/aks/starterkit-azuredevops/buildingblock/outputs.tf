output "dev_link" {
  description = "Link to the dev environment application"
  value       = "https://${local.identifier}-dev.likvid-k8s.msh.host"
}

output "prod_link" {
  description = "Link to the prod environment application"
  value       = "https://${local.identifier}.likvid-k8s.msh.host"
}

output "azdevops_project_url" {
  description = "URL of the created Azure DevOps project"
  value       = "https://dev.azure.com/${var.azdevops_organization_name}/${meshstack_building_block_v2.azdevops_project.spec.display_name}"
}

output "azdevops_repository_url" {
  description = "URL of the created Azure DevOps repository"
  value       = "https://dev.azure.com/${var.azdevops_organization_name}/${meshstack_building_block_v2.azdevops_project.spec.display_name}/_git/${meshstack_building_block_v2.repository.spec.display_name}"
}

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# AKS Starter Kit - Azure DevOps

✅ **Your environment is ready!**

This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

@buildingblock[${meshstack_building_block_v2.azdevops_project.metadata.uuid}]
&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.repository.metadata.uuid}]

@project[${meshstack_project.dev.metadata.owned_by_workspace}.${meshstack_project.dev.metadata.name}]\
&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant_v4.dev.metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.service_connection_dev.metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.pipeline_dev.metadata.uuid}]

@project[${meshstack_project.prod.metadata.owned_by_workspace}.${meshstack_project.prod.metadata.name}]\
&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant_v4.prod.metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.service_connection_prod.metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.pipeline_prod.metadata.uuid}]

---

## What's Included

Your Azure DevOps project contains:

- Git repository with application code
- Dockerfile and Kubernetes manifests
- **Dev Pipeline**: Deploys on commits to **main** branch
- **Prod Pipeline**: Deploys on commits to **release** branch
- Service connections with Workload Identity Federation (passwordless)

---

## Deployments

Trigger a deployment by:
- Pushing to the **main** branch (deploys to **dev**)
- Merging **main** into **release** via PR (deploys to **prod**)

View deployment status: [Azure Pipelines](https://dev.azure.com/${var.azdevops_organization_name}/${meshstack_building_block_v2.azdevops_project.spec.display_name}/_build)

- **Dev**: [${local.identifier}-dev.likvid-k8s.msh.host](https://${local.identifier}-dev.likvid-k8s.msh.host)
- **Prod**: [${local.identifier}.likvid-k8s.msh.host](https://${local.identifier}.likvid-k8s.msh.host)

---

## Next Steps

### 1. Clone Repository
```bash
git clone https://dev.azure.com/${var.azdevops_organization_name}/${meshstack_building_block_v2.azdevops_project.spec.display_name}/_git/${meshstack_building_block_v2.repository.spec.display_name}
```

### 2. Develop
- Push changes to **main** → deploys to **dev** automatically
- Create PR from **main → release** → deploys to **prod** after merge

### 3. Monitor
- [Dev Pipeline](https://dev.azure.com/${var.azdevops_organization_name}/${meshstack_building_block_v2.azdevops_project.spec.display_name}/_build?definitionId=${meshstack_building_block_v2.pipeline_dev.metadata.uuid})
- [Prod Pipeline](https://dev.azure.com/${var.azdevops_organization_name}/${meshstack_building_block_v2.azdevops_project.spec.display_name}/_build?definitionId=${meshstack_building_block_v2.pipeline_prod.metadata.uuid})

### 4. Access AKS Namespaces
- [Dev Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/i/aks.eu-de-central/overview/azure_kubernetes_service)
- [Prod Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/i/aks.eu-de-central/overview/azure_kubernetes_service)

### 5. Manage Access
- Invite team members via meshStack:
  - [Dev Access](/#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/access-management/role-mapping/overview)
  - [Prod Access](/#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/access-management/role-mapping/overview)

---

⚠️ **Note**: First prod deployment requires manual authorization of the service connection. Follow the prompts in the pipeline run.

🎉 Happy coding!
EOT
}
