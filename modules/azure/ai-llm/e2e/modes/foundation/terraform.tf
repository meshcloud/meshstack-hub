terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      # Needs >= 0.25.0 for the `meshstack_building_block_definitions` data source.
      source = "meshcloud/meshstack"
    }
  }
}
