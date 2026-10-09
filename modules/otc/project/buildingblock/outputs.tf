output "project_id" {
  value       = opentelekomcloud_identity_project_v3.this.id
  description = "ID of the created T Cloud Public project."
}

output "project_name" {
  value       = opentelekomcloud_identity_project_v3.this.name
  description = "Name of the created T Cloud Public project, including the region prefix."
}

output "project_url" {
  value       = var.console_login_url
  description = "Where project users sign in to the T Cloud Public console."
}

locals {
  # Built outside the heredoc: template directives inside `<<-EOT` throw off its indentation
  # stripping, which indents these lines into a code block.
  summary_role_rows = join("\n", [
    for role, group in local.groups : "| ${role} | `${group}` | ${join(", ", [for r in var.role_mapping[role] : "`${r}`"])} |"
  ])

  summary_sign_in = var.mapping_bucket != null ? join(" ", [
    "Sign in at [${var.console_login_url}](${var.console_login_url}) with your company account; your",
    "project roles apply from your next sign-in after a change. After signing in, switch to the",
    "project `${opentelekomcloud_identity_project_v3.this.name}` in the console's project selector.",
    ]) : join(" ", [
    "No identity provider is federated, so members sign in with their own T Cloud Public IAM user:",
    "meshStack puts the user named like the part of their email before the `@` into the groups above.",
    "Sign in at [${var.console_login_url}](${var.console_login_url}) and switch to the project",
    "`${opentelekomcloud_identity_project_v3.this.name}` in the console's project selector.",
  ])
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # T Cloud Public project `${opentelekomcloud_identity_project_v3.this.name}`

    Project ID: `${opentelekomcloud_identity_project_v3.this.id}` in region `${var.region}`.

    | meshStack role | IAM group | T Cloud Public roles |
    |---|---|---|
    ${local.summary_role_rows}

    ${local.summary_sign_in}
  EOT
}
