output "instance_name" {
  description = "Name of the STACKIT Git instance."
  value       = module.instance.instance.name
}

output "instance_id" {
  description = "STACKIT Git instance id."
  value       = module.instance.instance.instance_id
}

output "instance_url" {
  description = "URL of the Forgejo instance."
  value       = module.instance.instance.url
}

locals {
  organization_url = local.create_forgejo_organization ? format(
    "%s/%s", trimsuffix(module.instance.instance.url, "/"), var.forgejo_organization
  ) : module.instance.instance.url
}

output "organization_url" {
  description = "URL of the Forgejo organization. Falls back to the instance URL when no organization was asked for."
  value       = local.organization_url
}

output "forgejo_organization" {
  description = "Name of the Forgejo organization for this instance. Empty when none was asked for."
  # The name, not a claim that the organization exists: meshStack fails a building block whose
  # declared output is null. The organization is a Forgejo-side resource — STACKIT's Git API has
  # instances, users, runners and authentications, and nothing for organizations.
  value = coalesce(var.forgejo_organization, "")
}

output "local_user_username" {
  description = "Username of the technical user the token belongs to."
  value       = local.local_user_username
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret in Vault, where `secret_hash` changes with its content; `{}` without `output_to_vault`."
  value = {
    for key, value in {
      path        = local.vault_secret_path
      secret_hash = local.vault_secret_hash
    } : key => value if local.write_to_vault
  }
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    instance_name        = module.instance.instance.name
    instance_url         = module.instance.instance.url
    forgejo_organization = local.create_forgejo_organization ? var.forgejo_organization : null
    organization_url     = local.organization_url
    local_user_username  = local.local_user_username
    shared_runner_labels = var.shared_runner_labels
    vault_secret_path    = local.vault_secret_path
    vault_mount          = local.vault_mount
    members = [
      for email, role in local.member_roles : { email = email, role = role, username = lookup(local.forgejo_usernames, email, "") }
    ]
  })
}
