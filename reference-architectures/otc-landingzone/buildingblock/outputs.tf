output "platform_identifier" {
  value       = local.platform_identifier
  description = "Identifier of the created meshStack platform, including the playground suffix."
}

output "console_login_url" {
  value       = coalesce(module.otc_integration.identity_provider_login_link, "https://console.otc.t-systems.com")
  description = "Where project users sign in: the identity provider's login link, or the plain console without federation."
}

locals {
  # Built outside the heredoc: template directives inside `<<-EOT` throw off its indentation
  # stripping, which merged the table rows and the playground note in meshPanel.
  summary_playground_note = var.playground_mode ? join("\n", [
    "> **Playground mode.** The platform identifier carries a random suffix so this deployment does",
    "> not occupy a name for good. Do not publish this platform or the building block definition it",
    "> registered to other workspaces. Redeploy with `playground_mode` set to false for a platform",
    "> that is actually used.",
    "",
  ]) : ""

  summary_identity_provider = local.federation_enabled ? "`${var.identity_provider.name}` (${var.identity_provider.protocol})" : "none — users are not mapped into projects"
}

output "summary" {
  description = "Summary of what this reference architecture created."
  value       = <<-EOT
    # T Cloud Public Landing Zone: **${local.platform_identifier}**

    ${local.summary_playground_note}
    | Property | Value |
    |----------|-------|
    | **Domain** | `${var.otc_domain_name}` |
    | **Region** | `${var.otc_region}` |
    | **Landing Zone** | `${module.otc_integration.landingzone_ref.name}` |
    | **Backplane IAM user** | `mesh-${local.platform_identifier}` |
    | **Management project** | `${meshstack_project.management.metadata.name}` (T Cloud Public `${var.otc_region}_${meshstack_project.management.metadata.name}`) |
    | **Identity provider** | ${local.summary_identity_provider} |

    Application teams can now create meshStack projects in the `${module.otc_integration.landingzone_ref.name}`
    landing zone. Each one becomes a T Cloud Public project `${var.otc_region}_<project>`.

    Users sign in at <${coalesce(module.otc_integration.identity_provider_login_link, "https://console.otc.t-systems.com")}>.
  EOT
}
