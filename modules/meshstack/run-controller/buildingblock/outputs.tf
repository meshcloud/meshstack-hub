output "runner_ref" {
  description = "Reference to the registered building block runner, for `version_spec.runner_ref` of a building block definition."
  value       = jsonencode(meshstack_building_block_runner.this.ref)
}
