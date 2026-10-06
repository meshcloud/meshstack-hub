output "summary" {
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    base_url   = local.base_url
    model      = var.model
    token_name = var.token_name
    region     = var.stackit_region
  })
  description = "Markdown summary shown on the building block."
}
