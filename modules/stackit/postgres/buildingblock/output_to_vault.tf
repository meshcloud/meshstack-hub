locals {
  write_to_vault    = var.output_to_vault != null
  vault_secret_path = local.write_to_vault ? join("/", concat(["${var.output_to_vault.path_prefix}stackit/postgres", module.database.instance_id], local.create_instance ? [] : [module.database.database])) : null

  # forgejo-connector's `additional_kubernetes_secrets` reads the object under this key.
  vault_data_json = jsonencode({
    "kubernetes-secret" = {
      host     = module.database.host
      port     = tostring(module.database.port)
      database = module.database.database
      username = module.database.username
      password = module.database.password
      jdbc_url = module.database.jdbc_url
      uri      = "postgresql://${module.database.username}:${urlencode(module.database.password)}@${module.database.host}:${module.database.port}/${module.database.database}?sslmode=require"
    }
  })

  # The version must be a number, so the first 48 bits of the hash stand in for it.
  vault_secret_hash = parseint(substr(nonsensitive(sha256(local.vault_data_json)), 0, 12), 16)
}

resource "vault_kv_secret_v2" "this" {
  lifecycle {
    enabled = local.write_to_vault
  }

  mount                = var.output_to_vault.mount
  name                 = local.vault_secret_path
  data_json_wo         = local.vault_data_json
  data_json_wo_version = local.vault_secret_hash
}
