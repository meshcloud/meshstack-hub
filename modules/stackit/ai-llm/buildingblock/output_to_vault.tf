locals {
  # The starter kit application reads its inference configuration from these keys.
  vault_data_json = jsonencode({
    STACKIT_AI_BASE_URL = local.base_url
    STACKIT_AI_API_KEY  = stackit_modelserving_token.this.token
    STACKIT_AI_MODEL    = var.model
  })
}

provider "vault" {
  address = var.output_to_vault.address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = var.output_to_vault.username
    password = var.output_to_vault.password
  }
}

resource "vault_kv_secret_v2" "this" {
  mount        = var.output_to_vault.mount
  name         = var.output_to_vault.path
  data_json_wo = local.vault_data_json
  # The version must be a number, so the first 48 bits of the hash stand in for it.
  data_json_wo_version = parseint(substr(nonsensitive(sha256(local.vault_data_json)), 0, 12), 16)
}
