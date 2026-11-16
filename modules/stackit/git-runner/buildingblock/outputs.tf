output "runner_name" {
  value       = var.name
  description = "Name the runner registered under in STACKIT Git."
}

output "server_id" {
  value       = stackit_server.this.server_id
  description = "ID of the STACKIT server hosting the runner."
}

output "egress_ip" {
  value       = local.create_network ? stackit_network.this.public_ip : ""
  description = "Public SNAT IP of the runner's network router, for allowlisting. Empty on an existing network."
}

locals {
  runners_url = "${var.git_base_url}/org/${var.git_organization}/settings/actions/runners"
}

output "runners_url" {
  value       = local.runners_url
  description = "Forgejo page of the organization's runners."
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value       = <<-EOT
    # Git Runner: **${var.name}**

    The runner serves the STACKIT Git organization [`${var.git_organization}`](${var.git_base_url}/${var.git_organization}).
    A workflow picks it with `runs-on` set to one of its labels.

    | Property | Value |
    |----------|-------|
    | **Runners** | [Organization runners](${local.runners_url}) |
    | **Labels** | `${join("`, `", var.runner_labels)}` |
    | **Runner Version** | `${var.runner_version}` |
    | **Server** | `${stackit_server.this.server_id}`: `${var.machine_type}` with ${var.disk_size_gb} GB in ${var.availability_zone} |
    | **Egress IP** | ${local.create_network ? "`${stackit_network.this.public_ip}`" : "that of the network `${var.network_id}`"} |
  EOT
}
