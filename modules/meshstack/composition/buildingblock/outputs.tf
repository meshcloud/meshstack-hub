output "created_building_block_definition_uuid" {
  value       = meshstack_building_block_definition.created.metadata.uuid
  description = "UUID of the building block definition this composition created."
}

output "created_building_block_uuid" {
  value       = meshstack_building_block.created.metadata.uuid
  description = "UUID of the building block this composition created."
}

output "summary" {
  value = chomp(<<-EOT
  Created a link building block definition and a building block from it. Both show this building
  block as their creator.

  | meshObject | Name | UUID |
  |---|---|---|
  | Building Block Definition | ${var.name} | `${meshstack_building_block_definition.created.metadata.uuid}` |
  | Building Block | ${var.name} | `${meshstack_building_block.created.metadata.uuid}` |
  EOT
  )
  description = "Markdown summary shown on the building block's detail page."
}
