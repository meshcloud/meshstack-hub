output "summary" {
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    base_url   = local.base_url
    model      = var.model
    token_name = var.token_name
    region     = var.stackit_region
  })
  description = "Markdown summary shown on the building block."
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret written to `output_to_vault`. `secret_hash` is the secret's KV version and changes with its content."
  value       = { path = nonsensitive(var.output_to_vault.path), secret_hash = local.vault_secret_hash }
}
