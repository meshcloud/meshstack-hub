output "git_repo_url" {
  description = "URL of the created STACKIT Git repository."
  value       = meshstack_building_block_v2.git_repo.status.outputs.repository_html_url.value_string
}

output "summary" {
  description = "Summary with next steps and insights into created resources."
  value       = <<-EOT
# STACKIT Starter Kit

✅ **Your environment is ready!**

This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

@buildingblock[${meshstack_building_block_v2.git_repo.metadata.uuid}]

@project[${meshstack_project.dev.metadata.owned_by_workspace}.${meshstack_project.dev.metadata.name}]\
&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant_v4.dev.metadata.uuid}]
&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.forgejo_connector_dev.metadata.uuid}]

@project[${meshstack_project.prod.metadata.owned_by_workspace}.${meshstack_project.prod.metadata.name}]\
&nbsp;&nbsp;&nbsp;&nbsp;@tenant[${meshstack_tenant_v4.prod.metadata.uuid}]
&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block_v2.forgejo_connector_prod.metadata.uuid}]

---

## What's Included

- **Git Repository**: `${local.repo_name}` on STACKIT Git
- **Dev Project**: `${meshstack_project.dev.metadata.name}` with SKE namespace
  - Forgejo Actions CI/CD connector for development deployments
- **Prod Project**: `${meshstack_project.prod.metadata.name}` with SKE namespace
  - Forgejo Actions CI/CD connector for production deployments

---

## Next Steps

### 1. Develop
- Clone the repository and start developing
- Push changes to deploy to your Kubernetes namespaces via Forgejo Actions

### 2. Access SKE Namespaces
- [Dev Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/tenants)
- [Prod Namespace](/#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/tenants)

### 3. Manage Access
- Invite team members via meshStack:
  - [Dev Access](#/w/${var.workspace_identifier}/p/${meshstack_project.dev.metadata.name}/access-management/role-mapping/overview)
  - [Prod Access](#/w/${var.workspace_identifier}/p/${meshstack_project.prod.metadata.name}/access-management/role-mapping/overview)

---

🎉 Happy coding!
EOT
}
