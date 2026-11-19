output "building_block" {
  value = one(concat(meshstack_building_block.this[*], meshstack_building_block.released[*]))
}
