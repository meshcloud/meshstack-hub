# No output below carries a credential, and none can: `version_spec.outputs` of
# `meshstack_building_block_definition` has no `sensitive` block, unlike `version_spec.inputs`, so
# every building block output is stored and displayed in cleartext in meshPanel. The gateway's
# master key and the ClickHouse administrative password are generated inside the run and stay there.

output "litellm_url" {
  description = "URL the gateway answers on. Application teams never call it directly — their credential carries the endpoint — but it is what an operator opens."
  value       = local.litellm_public_url
}

output "litellm_console_url" {
  description = "URL of the gateway's admin console. The identity provider authenticates the login, and the console holds at most five users."
  value       = module.litellm.console_url
}

output "litellm_api_base" {
  description = "OpenAI-compatible base URL of the gateway, including the '/v1' suffix. Every tenant's credential carries this value."
  value       = "${local.litellm_api_base}/v1"
}

output "litellm_oidc_callback_url" {
  description = "Callback URL to register at the identity provider for the admin console. Null when console single sign-on is turned off."
  value       = module.litellm.oidc_callback_url
}

output "litellm_master_key_secret" {
  description = "Name of the Kubernetes Secret in the gateway namespace that holds the master key. An operator who needs the root credential of the gateway reads it there; it is never an output of this building block, because a building block output is cleartext in meshPanel."
  value       = module.litellm.master_key_secret_name
}

output "model_aliases" {
  description = "Model aliases the gateway offers. A landing zone allows a subset of them, and a tenant puts one of them in the 'model' field of a request."
  value       = join(", ", module.litellm.model_aliases)
}

output "clickhouse_host" {
  description = "In-cluster hostname of the shared ClickHouse cluster every tenant's tracing instance writes to."
  value       = module.clickhouse.host
}

output "platform_identifier" {
  description = "Identifier of the gateway platform registered in meshStack, in the `<name>.<location>` form."
  value       = "${meshstack_platform.litellm.metadata.name}.${meshstack_platform.litellm.spec.location_ref.name}"
}

output "landing_zones" {
  description = "AI landing zones created for the gateway platform. Each one provisions model access for every tenant that lands in it."
  value       = join(", ", [for lz in meshstack_landingzone.ai : lz.metadata.name])
}

output "summary" {
  description = "Summary of what one order of this architecture created."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    litellm_url         = local.litellm_public_url
    litellm_console_url = coalesce(module.litellm.console_url, "single sign-on is turned off")
    litellm_api_base    = "${local.litellm_api_base}/v1"
    litellm_namespace   = module.litellm.namespace
    master_key_secret   = module.litellm.master_key_secret_name
    model_aliases       = join(", ", module.litellm.model_aliases)

    postgres_database = module.litellm_database.database_name
    clickhouse_host   = module.clickhouse.host
    valkey_host       = var.valkey_host

    platform_identifier = "${meshstack_platform.litellm.metadata.name}.${meshstack_platform.litellm.spec.location_ref.name}"
    apps_domain         = var.apps_domain

    landing_zones = [
      for name, lz in meshstack_landingzone.ai : {
        name            = lz.metadata.name
        display_name    = lz.spec.display_name
        models          = length(var.landing_zones[name].models) == 0 ? "every model the gateway offers" : join(", ", var.landing_zones[name].models)
        max_budget      = var.landing_zones[name].max_budget
        budget_duration = var.landing_zones[name].budget_duration
      }
    ]
  })
}
