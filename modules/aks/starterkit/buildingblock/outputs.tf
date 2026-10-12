
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
  value       = jsondecode(meshstack_building_block.repo.status.outputs.repo_html_url.value)
}

output "summary" {
  description = "Summary with next steps and insights into created resources"
  value       = <<-EOT
# AKS Starter Kit

✅ **Your environment is ready!**

This starter kit has set up the following resources in workspace `${var.workspace_identifier}`:

@buildingblock[${meshstack_building_block.repo.metadata.uuid}]

@buildingblock[${meshstack_building_block.namespace["dev"].metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block.github_actions["dev"].metadata.uuid}]

@buildingblock[${meshstack_building_block.namespace["prod"].metadata.uuid}]\
&nbsp;&nbsp;&nbsp;&nbsp;@buildingblock[${meshstack_building_block.github_actions["prod"].metadata.uuid}]

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

View deployment status: [GitHub Actions](${jsondecode(meshstack_building_block.repo.status.outputs.repo_html_url.value)}/actions/workflows/k8s-deploy.yml)

- **Dev**: [${local.identifier}-dev.${var.apps_base_domain}](https://${local.identifier}-dev.${var.apps_base_domain})
- **Prod**: [${local.identifier}.${var.apps_base_domain}](https://${local.identifier}.${var.apps_base_domain})

---

## Next Steps

### 1. Develop
- Push changes to **main** → deploys to **dev**
- Merge PR from **main → release** → deploys to **prod**

### 2. Monitor
- Check workflow status in the [Actions tab](<${jsondecode(meshstack_building_block.repo.status.outputs.repo_html_url.value)}/actions>)

### 3. Manage Access
- Namespace access follows the Entra groups the platform team configured for this starter kit.
  Ask them to add your team's group.

---

🎉 Happy coding!
EOT
}
