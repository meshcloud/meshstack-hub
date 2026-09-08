terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    # Not used here: the mocked run in tests/ plans ../buildingblock, which tracks its own creation
    # time with it.
    time = {
      source = "hashicorp/time"
    }
  }
}
