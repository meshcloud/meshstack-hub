output "url" {
  value       = var.url
  description = "The linked resource, rendered as a deep link in meshPanel."
}

output "summary" {
  value       = trimspace(var.summary) != "" ? var.summary : local.default_summary
  description = "Markdown rendered for the application team after deployment."
}
