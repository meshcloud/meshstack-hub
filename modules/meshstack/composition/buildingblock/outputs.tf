output "created_building_block_definition_uuid" {
  value       = meshstack_building_block_definition.created.metadata.uuid
  description = "UUID of the building block definition this composition created."
}

output "created_building_block_uuid" {
  value       = meshstack_building_block.created.metadata.uuid
  description = "UUID of the building block this composition created."
}

output "created_platform_uuid" {
  value       = meshstack_platform.created.metadata.uuid
  description = "UUID of the platform this composition created."
}

output "created_landing_zone_identifier" {
  value       = meshstack_landingzone.created.metadata.name
  description = "Identifier of the landing zone this composition created. Landing zones have no UUID in the API."
}

output "summary" {
  value = chomp(<<-EOT
  Created a Link building block definition with a building block from it, and an empty platform with a
  landing zone on it. All of them show this building block as their creator.

  | meshObject | Name | Identifier |
  |---|---|---|
  | Building Block Definition | ${var.link_name} | `${meshstack_building_block_definition.created.metadata.uuid}` |
  | Building Block | ${var.link_name} | `${meshstack_building_block.created.metadata.uuid}` |
  | Platform Type | ${meshstack_platform_type.created.spec.display_name} | `${meshstack_platform_type.created.metadata.name}` |
  | Location | ${meshstack_location.created.spec.display_name} | `${meshstack_location.created.metadata.name}` |
  | Platform | ${var.platform_name} | `${meshstack_platform.created.identifier}` |
  | Landing Zone | ${meshstack_landingzone.created.spec.display_name} | `${meshstack_landingzone.created.metadata.name}` |
  EOT
  )
  description = "Markdown summary shown on the building block's detail page."
}
