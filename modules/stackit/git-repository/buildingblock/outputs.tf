locals {
  repo_id        = var.use_template ? "${local.owner}/${var.repository_name}" : (length(gitea_repository.repo) > 0 ? tostring(gitea_repository.repo[0].id) : "")
  repo_html_url  = var.use_template ? local.html_url : (length(gitea_repository.repo) > 0 ? gitea_repository.repo[0].html_url : local.html_url)
  repo_ssh_url   = var.use_template ? local.ssh_url : (length(gitea_repository.repo) > 0 ? gitea_repository.repo[0].ssh_url : local.ssh_url)
  repo_clone_url = var.use_template ? local.clone_url : (length(gitea_repository.repo) > 0 ? gitea_repository.repo[0].clone_url : local.clone_url)
}

output "repository_id" {
  value       = local.repo_id
  description = "The ID of the created repository"
}

output "repository_name" {
  value       = var.repository_name
  description = "Name of the created repository"
}

output "repository_html_url" {
  value       = local.repo_html_url
  description = "Web URL of the repository"
}

output "repository_ssh_url" {
  value       = local.repo_ssh_url
  description = "SSH clone URL"
}

output "repository_clone_url" {
  value       = local.repo_clone_url
  description = "HTTPS clone URL"
}

output "summary" {
  description = "Summary with next steps and links for the created repository"
  value       = <<-EOT
# ✅ Git Repository Created

**${var.repository_name}** is ready on STACKIT Git.

## Repository Details

- **Name**: ${var.repository_name}
- **Owner**: ${local.owner}
- **URL**: ${local.repo_html_url}
- **Clone URL**: `${local.repo_clone_url}`
${var.use_template ? "\n- **Created from template**: `${var.template_owner}/${var.template_name}`" : ""}

## Next Steps

1. **Clone your repository**:
   ```bash
   git clone ${local.repo_clone_url}
   cd ${var.repository_name}
   ```

2. **Start developing**: Edit application files and push your changes.

3. **Push your changes**:
   ```bash
   git add .
   git commit -m "Initial commit"
   git push origin ${var.default_branch}
   ```

${var.webhook_url != "" ? "## Webhook Configured\n\nPushes to this repository will trigger builds at:\n- **Webhook URL**: `${var.webhook_url}`\n- **Events**: ${join(", ", var.webhook_events)}" : ""}

## Resources

- [Open repository in STACKIT Git](${local.repo_html_url})
EOT
}
