terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    # For the mocked run against ../buildingblock, not for anything here.
    time = {
      source = "hashicorp/time"
    }
  }
}
