locals {
  write_to_vault = nonsensitive(var.output_to_vault != null)

  vault_data_json = jsonencode({ kubeconfig = yamlencode(local.kubeconfig) })

  # The version must be a number, so the first 48 bits of the hash stand in for it.
  vault_secret_hash = parseint(substr(nonsensitive(sha256(local.vault_data_json)), 0, 12), 16)
}

provider "vault" {
  address = var.output_to_vault == null ? null : var.output_to_vault.address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  dynamic "auth_login_userpass" {
    for_each = var.output_to_vault[*]
    content {
      username = auth_login_userpass.value.username
      password = auth_login_userpass.value.password
    }
  }
}

resource "vault_kv_secret_v2" "this" {
  lifecycle {
    enabled = local.write_to_vault
  }

  mount                = var.output_to_vault.mount
  name                 = var.output_to_vault.path
  data_json_wo         = local.vault_data_json
  data_json_wo_version = local.vault_secret_hash
}
