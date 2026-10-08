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

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # T Cloud Public project `${opentelekomcloud_identity_project_v3.this.name}`

    Project ID: `${opentelekomcloud_identity_project_v3.this.id}` in region `${var.region}`.

    | meshStack role | IAM group | T Cloud Public roles |
    |---|---|---|
    %{for role, group in local.groups~}
    | ${role} | `${group}` | ${join(", ", [for r in var.role_mapping[role] : "`${r}`"])} |
    %{endfor~}

    %{if var.mapping_bucket != null~}
    Sign in at [${var.console_login_url}](${var.console_login_url}) with your company account; your
    project roles apply from your next sign-in after the change. After signing in, switch to the project
    `${opentelekomcloud_identity_project_v3.this.name}` in the console's project selector.
    %{else~}
    No identity provider is federated, so no user is mapped into the groups yet. Ask your platform
    team to add IAM users to the groups above.
    %{endif~}
  EOT
}
