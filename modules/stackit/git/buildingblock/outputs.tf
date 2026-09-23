output "instance_name" {
  description = "Name of the STACKIT Git instance."
  value       = stackit_git.this.name
}

output "instance_id" {
  description = "STACKIT Git instance id."
  value       = stackit_git.this.instance_id
}

output "instance_url" {
  description = "URL of the Forgejo instance."
  value       = stackit_git.this.url
}

output "organization_url" {
  description = "URL of the Forgejo organization. Falls back to the instance URL when no organization was asked for."
  value = local.create_forgejo_organization ? format(
    "%s/%s", trimsuffix(stackit_git.this.url, "/"), var.forgejo_organization
  ) : stackit_git.this.url
}

output "forgejo_organization" {
  description = "Name of the Forgejo organization for this instance. Empty when none was asked for."
  # The name, not a claim that the organization exists: meshStack fails a building block whose
  # declared output is null. The organization is a Forgejo-side resource — STACKIT's Git API has
  # instances, users, runners and authentications, and nothing for organizations.
  value = coalesce(var.forgejo_organization, "")
}

output "forgejo_api_token" {
  description = "Personal Access Token for this instance, for building blocks that manage repositories, runners or organization members."
  value       = local.forgejo_api_token
  sensitive   = true
}

output "local_user_username" {
  description = "Username of the technical user the token belongs to."
  value       = var.local_user_username
}
