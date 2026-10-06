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

# Not ephemeral: restapi_object has no write-only body, https://github.com/Mastercard/terraform-provider-restapi/issues/304
data "vault_kv_secret_v2" "registry_push" {
  lifecycle {
    enabled = var.registry_push_path != null
  }

  mount = var.vault_reader.mount
  name  = var.registry_push_path
}

locals {
  forgejo_api_token = ephemeral.vault_kv_secret_v2.forgejo_api_token.data["forgejo_api_token"]

  # The secret names the starter kit template's workflow reads.
  registry_push_action_secrets = var.registry_push_path == null ? {} : {
    HARBOR_USERNAME = data.vault_kv_secret_v2.registry_push.data["username"]
    HARBOR_PASSWORD = data.vault_kv_secret_v2.registry_push.data["password"]
  }
}
