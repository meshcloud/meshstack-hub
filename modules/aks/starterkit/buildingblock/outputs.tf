
output "dev-link" {
  description = "Link to the dev environment Angular app"
  value       = "https://${local.identifier}-dev.${var.apps_base_domain}"
}

output "prod-link" {
  description = "Link to the prod environment Angular app"
  value       = "https://${local.identifier}.${var.apps_base_domain}"
}

output "github_repo_url" {
  description = "URL of the created GitHub repository"
  value       = meshstack_building_block_v2.repo.status.outputs.repo_html_url.value_string
}

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# AKS Starter Kit

✅ **Your environment is ready!**

This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

@buildingblock[${meshstack_building_block_v2.repo.metadata.uuid}]

@project[${meshstack_project.dev.metadata.owned_by_workspace}.${meshstack_project.dev.metadata.name}]\
&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant_v4.dev.metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.github_actions_dev.metadata.uuid}]

@project[${meshstack_project.prod.metadata.owned_by_workspace}.${meshstack_project.prod.metadata.name}]\
&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant_v4.prod.metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.github_actions_prod.metadata.uuid}]

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

View deployment status: [GitHub Actions](${meshstack_building_block_v2.repo.status.outputs.repo_html_url.value_string}/actions/workflows/k8s-deploy.yml)

- **Dev**: [${local.identifier}-dev.${var.apps_base_domain}](https://${local.identifier}-dev.${var.apps_base_domain})
- **Prod**: [${local.identifier}.${var.apps_base_domain}](https://${local.identifier}.${var.apps_base_domain})

---

## Next Steps

### 1. Develop
- Push changes to **main** → deploys to **dev**
- Merge PR from **main → release** → deploys to **prod**

### 2. Monitor
- Check workflow status in the [Actions tab](<${meshstack_building_block_v2.repo.status.outputs.repo_html_url.value_string}/actions>)

### 3. Access AKS Namespaces
- [Dev Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/i/${meshstack_tenant_v4.dev.spec.platform_identifier}/overview/azure_kubernetes_service)
- [Prod Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/i/${meshstack_tenant_v4.prod.spec.platform_identifier}/overview/azure_kubernetes_service)

### 4. Manage Access
- Invite team members via meshStack:
  - [Dev Access](#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/access-management/role-mapping)
  - [Prod Access](#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/access-management/role-mapping)

---

🎉 Happy coding!
EOT
}
