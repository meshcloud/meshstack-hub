output "runner_ref" {
  description = "Reference to the registered building block runner, for `version_spec.runner_ref` of a building block definition."
  value       = jsonencode(meshstack_building_block_runner.this.ref)
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value       = <<-EOT
    # Building Block Run Controller: **${local.display_name}**

    The runner `${meshstack_building_block_runner.this.metadata.uuid}` runs building blocks as Kubernetes Jobs in the namespace `${var.namespace}`.

    To run a building block definition of your workspace here, set its `version_spec.runner_ref` to the output **Runner Reference**.
  EOT
}
