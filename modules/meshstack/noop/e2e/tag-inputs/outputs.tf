locals {
  # Every building block output arrives JSON-encoded, and a CODE output carries JSON of its own — so
  # the debug map decodes twice. `try` so that a run which produced no outputs at all fails on the
  # status assertion, which says what went wrong, rather than on evaluating this.
  received_inputs = try(
    jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value)),
    {}
  )
}

output "resolved_tags" {
  description = "The three TAG inputs as the building block run received them, decoded."
  value = {
    project        = try(local.received_inputs["project_tag"], null)
    payment_method = try(local.received_inputs["payment_method_tag"], null)
    landing_zone   = try(local.received_inputs["landing_zone_tag"], null)
  }
}

output "building_block_status" {
  description = "Run status of the building block under test."
  value       = meshstack_building_block.this.status.status
}
