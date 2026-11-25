output "project_id" {
  value       = ovh_cloud_project.this.project_id
  description = "ID of the created Public Cloud project."
}

output "project_urn" {
  value       = ovh_cloud_project.this.urn
  description = "IAM resource URN of the created Public Cloud project."
}

output "project_url" {
  value       = "https://www.ovh.com/manager/#/public-cloud/pci/projects/${ovh_cloud_project.this.project_id}"
  description = "Link to the project in the OVHcloud Control Panel."
}

locals {
  # Built outside the heredoc: template directives inside `<<-EOT` throw off its indentation
  # stripping, which indents these lines into a code block.
  summary_role_rows = join("\n", [
    for role in sort(keys(var.role_mapping)) :
    "| ${role} | ${length(local.role_identities[role])} | ${contains(keys(local.role_policies), role) ? "`${local.policy_name_prefix}-${role}`" : "–"} |"
  ])

  summary_unknown_members = length(local.unknown_members) == 0 ? "Every project member has an OVHcloud user." : join(" ", [
    "These project members have no OVHcloud user named like the part of their email before the `@`",
    "in the `DEFAULT` group, so they got no access: ${join(", ", local.unknown_members)}.",
  ])
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # OVHcloud Public Cloud project `${local.project_description}`

    Project ID: `${ovh_cloud_project.this.project_id}`. Open it in the
    [OVHcloud Control Panel](https://www.ovh.com/manager/#/public-cloud/pci/projects/${ovh_cloud_project.this.project_id}).

    | meshStack role | Members with access | IAM policy |
    |---|---|---|
    ${local.summary_role_rows}

    ${local.summary_unknown_members}
  EOT
}
