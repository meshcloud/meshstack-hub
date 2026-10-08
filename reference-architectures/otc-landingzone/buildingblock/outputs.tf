output "platform_identifier" {
  value       = local.platform_identifier
  description = "Identifier of the created meshStack platform, including the playground suffix."
}

output "console_login_url" {
  value       = coalesce(module.otc_integration.identity_provider_login_link, "https://console.otc.t-systems.com")
  description = "Where project users sign in: the identity provider's login link, or the plain console without federation."
}

output "summary" {
  description = "Summary of what this reference architecture created."
  value       = <<-EOT
    # T Cloud Public Landing Zone: **${local.platform_identifier}**

    %{if var.playground_mode~}
    > **Playground mode.** The platform identifier carries a random suffix so this deployment does
    > not occupy a name for good. Do not publish this platform or the building block definition it
    > registered to other workspaces. Redeploy with `playground_mode` set to false for a platform
    > that is actually used.

    %{endif~}
    | Property | Value |
    |----------|-------|
    | **Domain** | `${var.otc_domain_name}` |
    | **Region** | `${var.otc_region}` |
    | **Landing Zone** | `${module.otc_integration.landingzone_ref.name}` |
    | **Backplane IAM user** | `mesh-${local.platform_identifier}` |
    | **Identity provider** | ${var.identity_provider.protocol == "none" ? "none — users are not mapped into projects" : "`${var.identity_provider.name}` (${var.identity_provider.protocol})"} |

    Application teams can now create meshStack projects in the `${module.otc_integration.landingzone_ref.name}`
    landing zone. Each one becomes a T Cloud Public project `${var.otc_region}_<project>`.

    Users sign in at <${coalesce(module.otc_integration.identity_provider_login_link, "https://console.otc.t-systems.com")}>.
  EOT
}
