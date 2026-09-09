locals {
  # `try` so that a run which produced no outputs at all fails on the status assertion, which says
  # what went wrong, rather than on evaluating this.
  resolved_tags = try(
    jsondecode(jsondecode(meshstack_building_block.this.status.outputs["resolved_tags"].value)),
    { project = null, payment_method = null, landing_zone = null }
  )
}

output "resolved_tags" {
  description = "The three TAG inputs as the building block run received them."
  value       = local.resolved_tags
}

output "building_block_status" {
  description = "Run status of the building block under test."
  value       = meshstack_building_block.this.status.status
}
