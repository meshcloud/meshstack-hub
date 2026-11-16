locals {
  token_url = "https://portal.stackit.cloud/model-serving/tokens/${stackit_modelserving_token.this.token_id}?project=${var.stackit_project_id}"
}

output "token_url" {
  value       = local.token_url
  description = "STACKIT portal page of the model serving token."
}

output "summary" {
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    base_url   = local.base_url
    model      = var.model
    token_name = var.token_name
    token_url  = local.token_url
    region     = var.stackit_region
  })
  description = "Markdown summary shown on the building block."
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret in Vault, where `secret_hash` changes with its content."
  value       = { path = local.vault_secret_path, secret_hash = local.vault_secret_hash }
}
