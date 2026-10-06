provider "vault" {
  address = var.vault_reader.address
  # A Secrets Manager user may not create the child token the provider asks for by default.
  skip_child_token = true

  auth_login_userpass {
    username = var.vault_reader.username
    password = var.vault_reader.password
  }
}

data "vault_kv_secret_v2" "forgejo_api_token" {
  mount = var.vault_reader.mount
  name  = var.forgejo_api_token_path
}

data "vault_kv_secret_v2" "registry_pull" {
  mount = var.vault_reader.mount
  name  = var.registry_pull_path
}

data "vault_kv_secret_v2" "additional" {
  for_each = var.additional_kubernetes_secrets

  mount = var.vault_reader.mount
  name  = each.value
}

locals {
  forgejo_api_token = data.vault_kv_secret_v2.forgejo_api_token.data["forgejo_api_token"]
  registry_pull     = data.vault_kv_secret_v2.registry_pull.data
}
