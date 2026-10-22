locals {
  vault_secret_path = "${nonsensitive(var.output_to_vault.path_prefix)}ske/cluster"

  vault_data_json = jsonencode({ kubeconfig = local.admin_kubeconfig })

  # The version must be a number, so the first 48 bits of the hash stand in for it.
  vault_secret_hash = parseint(substr(nonsensitive(sha256(local.vault_data_json)), 0, 12), 16)
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
  mount                = var.output_to_vault.mount
  name                 = local.vault_secret_path
  data_json_wo         = local.vault_data_json
  data_json_wo_version = local.vault_secret_hash
}
