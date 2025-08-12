
output "dev-link" {
  description = "Link to the dev environment Angular app"
  value       = "https://${local.identifier}-dev.likvid-k8s.msh.host"
}

output "prod-link" {
  description = "Link to the prod environment Angular app"
  value       = "https://${local.identifier}.likvid-k8s.msh.host"
}

output "github_repo_url" {
  description = "URL of the created GitHub repository"
  value       = data.meshstack_building_block_v2.repo_data.status.outputs.repo_html_url.value_string
}

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# AKS Starter Kit

✅ **Your environment is ready!**

This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

- **GitHub Repository**: [${local.identifier}](<${data.meshstack_building_block_v2.repo_data.status.outputs.repo_html_url.value_string}>)
- **Development Project**: [${meshstack_project.dev.spec.display_name}](/#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/tenants)
  - **AKS Namespace**: [${data.meshstack_tenant_v4.aks-dev.spec.platform_tenant_id}](/#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/i/aks.eu-de-central/overview/azure_kubernetes_service)
- **Production Project**: [${meshstack_project.prod.spec.display_name}](/#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/tenants)
  - **AKS Namespace**: [${data.meshstack_tenant_v4.aks-prod.spec.platform_tenant_id}](/#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/i/aks.eu-de-central/overview/azure_kubernetes_service)

---

## What's Included

Your GitHub repository contains:

- Angular frontend & Node.js backend
- Dockerfiles for both apps
- Kubernetes deployment files
- GitHub Actions CI/CD workflows for AKS

---

## Deployments

Trigger a deployment by:
- Pushing to the **main** branch (deploys to **dev**)
- Merging **main** into **release** via PR (deploys to **prod**)

View deployment status: [GitHub Actions](${data.meshstack_building_block_v2.repo_data.status.outputs.repo_html_url.value_string}/actions/workflows/k8s-deploy.yml)

- **Dev**: [${local.identifier}-dev.likvid-k8s.msh.host](https://${local.identifier}-dev.likvid-k8s.msh.host)
- **Prod**: [${local.identifier}.likvid-k8s.msh.host](https://${local.identifier}.likvid-k8s.msh.host)

---

## Next Steps

### 1. Develop
- Push changes to **main** → deploys to **dev**
- Merge PR from **main → release** → deploys to **prod**

### 2. Monitor
- Check workflow status in the [Actions tab](<${data.meshstack_building_block_v2.repo_data.status.outputs.repo_html_url.value_string}/actions>)

### 3. Access AKS Namespaces
- [Dev Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/i/aks.eu-de-central/overview/azure_kubernetes_service)
- [Prod Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/i/aks.eu-de-central/overview/azure_kubernetes_service)

### 4. Manage Access
- Invite team members via meshStack:
  - [Dev Access](#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/access-management/role-mapping/overview)
  - [Prod Access](#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/access-management/role-mapping/overview)

---

🎉 Happy coding!
EOT
}