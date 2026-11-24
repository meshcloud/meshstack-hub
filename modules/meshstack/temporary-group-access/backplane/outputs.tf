output "sweeper_building_block" {
  description = "The sweeper building block in the owning workspace. Its runs show which access blocks were deleted."
  value = {
    uuid = meshstack_building_block.sweeper.metadata.uuid
    ref  = meshstack_building_block.sweeper.ref
  }
}
