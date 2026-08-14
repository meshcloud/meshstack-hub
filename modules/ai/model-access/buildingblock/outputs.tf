# The virtual key is deliberately absent from this file. It is created in this run, written into the
# Secret in this run, and never returned: a building block output cannot be sensitive, because
# `version_spec.outputs` of meshstack_building_block_definition has no `sensitive` block, unlike
# `version_spec.inputs`. Not returning it at all is what keeps it inside the run.

output "team_id" {
  value       = litellm_team.this.id
  description = "ID of the LiteLLM team. meshStack uses it as the platform tenant ID, so later building blocks can bind resources to this team."
}

output "team_alias" {
  value       = litellm_team.this.team_alias
  description = "Alias of the LiteLLM team, shown in the LiteLLM UI."
}

output "key_id" {
  value       = litellm_key.this.id
  description = "Hash of the virtual key. LiteLLM identifies the key by this value, and it is safe to show in logs."
}

output "api_base" {
  value       = local.api_base
  description = "OpenAI-compatible base URL of the gateway, including the '/v1' suffix. The same value is written into the Secret."
}

output "secret_name" {
  value       = kubernetes_secret_v1.model_access.metadata[0].name
  description = "Name of the Kubernetes Secret that carries the model credential and the endpoint."
}

output "secret_namespace" {
  value       = kubernetes_secret_v1.model_access.metadata[0].namespace
  description = "Namespace the Secret was written into. It is the platform tenant id of the sibling tenant of this meshProject, which for a Kubernetes tenant is the namespace name."
}

output "langfuse_url" {
  value       = local.langfuse_url
  description = "URL of the tenant's own Langfuse instance. meshStack publishes it as the sign-in URL of this building block."
}

output "langfuse_namespace" {
  value       = module.langfuse.namespace
  description = "Namespace the tenant's Langfuse instance runs in, in the AI platform cluster."
}

output "langfuse_oidc_callback_url" {
  value       = module.langfuse.oidc_callback_url
  description = "Callback URL to register at the identity provider for this tenant's Langfuse instance."
}

# The names of the per-tenant resources in the four shared backends. The Postgres and the bucket names
# are read back off the resources that carry them rather than off the locals they were derived from, so
# the output describes what the run created. The ClickHouse pair comes from the derivation, because
# ClickHouse has no Terraform resource here and the names travel into the DDL Job as Helm values.
output "langfuse_backend_names" {
  description = "The per-tenant names the tenant's Langfuse instance uses in the four shared backends. The module creates the Postgres database and its owner user, the ClickHouse database and its user, and the bucket; Valkey is separated by key prefix and database index alone."
  value = {
    postgres_database   = module.postgres.database_name
    postgres_username   = module.postgres.username
    clickhouse_database = local.langfuse_clickhouse_database
    clickhouse_username = local.langfuse_clickhouse_username
    bucket              = module.bucket.bucket_name
    valkey_key_prefix   = local.langfuse_valkey_key_prefix
    valkey_database     = local.langfuse_valkey_database
  }
}

# meshStack publishes this value in meshPanel through the `SUMMARY` assignment type, so the template
# must not contain the virtual key. It carries the key ID instead, which is a hash of the key, and it
# names the Secret the key was delivered in.
output "summary" {
  description = "Summary with the endpoint, the Secret the credential was delivered in, the Langfuse URL and the budget. It does not contain the virtual key."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    api_base   = local.api_base
    team_alias = litellm_team.this.team_alias
    team_id    = litellm_team.this.id
    key_id     = litellm_key.this.id
    # Read from the Secret rather than from the inputs it was built from, so the summary can only
    # describe a Secret that was actually written.
    secret_name      = kubernetes_secret_v1.model_access.metadata[0].name
    secret_namespace = kubernetes_secret_v1.model_access.metadata[0].namespace
    secret_key_env   = local.secret_keys.api_key
    base_url_env     = local.secret_keys.api_base
    langfuse_url     = local.langfuse_url
    max_budget       = var.max_budget
    budget_duration  = var.budget_duration
    models           = var.models
  })
}
