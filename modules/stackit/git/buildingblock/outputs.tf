output "instance_name" {
  description = "Name of the STACKIT Git instance."
  value       = stackit_git.this.name
}

output "instance_id" {
  description = "STACKIT Git instance id."
  value       = stackit_git.this.instance_id
}

output "instance_url" {
  description = "URL of the Forgejo instance. Sign in here to create the bot account and mint the Personal Access Token the second run needs."
  value       = stackit_git.this.url
}

output "forgejo_organization" {
  description = "Name of the Forgejo organization created in the instance, or null while no token has been supplied."
  # Short-circuits on the guard so the disabled resource's null attributes are never decoded.
  value = local.create_forgejo_organization ? jsondecode(restapi_object.forgejo_organization.api_response).name : null
}

output "forgejo_token_provided" {
  description = "Whether a Forgejo Personal Access Token is available, i.e. whether this instance is past the token bootstrap step."
  value       = local.forgejo_token_provided
}
