output "team_id" {
  value       = litellm_team.this.id
  description = "ID of the LiteLLM team. meshStack uses it as the platform tenant ID, so later building blocks can bind resources to this team."
}

output "team_alias" {
  value       = litellm_team.this.team_alias
  description = "Alias of the LiteLLM team, shown in the LiteLLM UI."
}

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

output "summary" {
  description = "Summary with the endpoint, the virtual key and the budget."
  sensitive   = true
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    team_alias      = litellm_team.this.team_alias
    team_id         = litellm_team.this.id
    virtual_key     = litellm_key.this.key
    api_base        = local.api_base
    max_budget      = var.max_budget
    budget_duration = var.budget_duration
    models          = var.models
  })
}
