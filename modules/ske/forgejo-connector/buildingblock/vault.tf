provider "vault" {
  address = var.vault_reader.address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = var.vault_reader.username
    password = var.vault_reader.password
  }
}

ephemeral "vault_kv_secret_v2" "forgejo_api_token" {
  mount = var.vault_reader.mount
  name  = var.forgejo_api_token_path
}

# The ephemeral vault_kv_secret_v2 fails on secrets whose values are maps; this one accepts them.
ephemeral "vault_generic_secret" "registry" {
  path = "${var.vault_reader.mount}/data/${var.registry_secret_path}"
}

ephemeral "vault_generic_secret" "additional" {
  for_each = var.additional_kubernetes_secrets

  path = "${var.vault_reader.mount}/data/${each.value}"
}

locals {
  forgejo_api_token = ephemeral.vault_kv_secret_v2.forgejo_api_token.data["forgejo-api-token"]
}
