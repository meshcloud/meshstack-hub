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

output "organization_url" {
  description = "URL of the Forgejo organization. Falls back to the instance URL when no organization was asked for."
  value = local.create_forgejo_organization ? format(
    "%s/%s", trimsuffix(module.instance.instance.url, "/"), var.forgejo_organization
  ) : module.instance.instance.url
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
  description = "`{path, secret_hash}` of the secret written to `output_to_vault`, or `{}` when that is not set. `secret_hash` is the secret's KV version and changes with its content."
  value = {
    for key, value in {
      path        = local.write_to_vault ? nonsensitive(var.output_to_vault.path) : null
      secret_hash = local.vault_secret_hash
    } : key => value if local.write_to_vault
  }
}
