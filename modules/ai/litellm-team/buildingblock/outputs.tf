output "team_id" {
  value       = litellm_team.this.id
  description = "ID of the LiteLLM team. meshStack uses it as the platform tenant ID, so later building blocks can bind resources to this team."
}

output "team_alias" {
  value       = litellm_team.this.team_alias
  description = "Alias of the LiteLLM team, shown in the LiteLLM UI."
}

# This is a plain Terraform output marked sensitive, not a building block output. It stays in the
# state of the run and a composing module reads it to deliver the key to the application team.
# It must never become a building block output, because building block outputs cannot be sensitive.
output "virtual_key" {
  value       = litellm_key.this.key
  sensitive   = true
  description = "The virtual key the application sends as a bearer token. LiteLLM returns it once, at creation, and never again."
}

output "key_id" {
  value       = litellm_key.this.id
  description = "Hash of the virtual key. LiteLLM identifies the key by this value, and it is safe to show in logs."
}

output "api_base" {
  value       = local.api_base
  description = "OpenAI-compatible base URL of the LiteLLM gateway, including the '/v1' suffix."
}

# meshStack publishes this value in meshPanel through the `SUMMARY` assignment type, so the template
# must not contain the virtual key. It carries the key ID instead, which is a hash of the key.
output "summary" {
  description = "Summary with the endpoint, the team, the key ID and the budget. It does not contain the virtual key."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    team_alias      = litellm_team.this.team_alias
    team_id         = litellm_team.this.id
    key_alias       = local.key_alias
    key_id          = litellm_key.this.id
    api_base        = local.api_base
    max_budget      = var.max_budget
    budget_duration = var.budget_duration
    models          = var.models
  })
}
