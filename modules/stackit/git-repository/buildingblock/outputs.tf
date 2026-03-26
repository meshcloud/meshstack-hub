output "repository_id" {
  value       = forgejo_repository.this.id
  description = "The ID of the created repository"
}

output "repository_name" {
  value       = var.name
  description = "Name of the created repository"
}

output "repository_html_url" {
  value       = forgejo_repository.this.html_url
  description = "Web URL of the repository"
}

output "repository_ssh_url" {
  value       = forgejo_repository.this.ssh_url
  description = "SSH clone URL"
}

output "repository_clone_url" {
  value       = forgejo_repository.this.clone_url
  description = "HTTPS clone URL"
}

output "summary" {
  description = "Summary with next steps and links for the created repository"
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    name           = var.name
    owner          = var.forgejo_organization
    repo_html_url  = forgejo_repository.this.html_url
    repo_clone_url = forgejo_repository.this.clone_url
    clone_addr     = var.clone_addr
    default_branch = var.default_branch
    forgejo_host   = data.external.env.result["FORGEJO_HOST"]

    team_names = local.team_names

    # Per-member info for the summary table
    members = [
      for member in var.workspace_members : {
        email         = member.email
        roles         = join(", ", member.roles)
        team_type     = local.member_team_type[member.username]
        resolve_error = lookup(local._resolved_users, "error:${member.email}", "")
        username      = lookup(local._resolved_users, member.email, "")
      }
    ]
  })
}
