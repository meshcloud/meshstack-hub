# The default (unaliased) `meshstack` provider would authenticate with this run's ephemeral,
# workspace-scoped API token. meshStack never grants ADM_* permissions to that token, and creating a
# workspace or a payment method requires them (see the meshstack_workspace / meshstack_payment_method
# resource docs) — so every resource in this building block is managed through this admin-scoped
# alias instead. `endpoint` is left unset so it falls back to the same `MESHSTACK_ENDPOINT` the runner
# already exports for the default provider.
provider "meshstack" {
  apikey    = var.meshstack_admin_api_key
  apisecret = var.meshstack_admin_api_secret
}
