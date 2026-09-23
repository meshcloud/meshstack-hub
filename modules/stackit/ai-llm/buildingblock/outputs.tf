output "base_url" {
  value       = local.base_url
  description = "OpenAI-compatible inference endpoint."
}

output "model" {
  value       = var.model
  description = "Model applications default to."
}

# One object rather than three strings, so a consumer wires inference with a single input.
#
# meshStack has no sensitive building block output, so the token travels in the clear, as the
# registry credentials already do.
output "access_credentials" {
  description = "Inference credentials: the endpoint, the token and the default model."
  value = jsonencode({
    base_url = local.base_url
    api_key  = nonsensitive(stackit_modelserving_token.this.token)
    model    = var.model
  })
}

output "summary" {
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    base_url   = local.base_url
    model      = var.model
    token_name = var.token_name
    region     = var.stackit_region
  })
  description = "Markdown summary shown on the building block."
}
