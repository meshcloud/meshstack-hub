terraform {
  required_version = ">= 1.11.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    stackit = {
      source = "stackitcloud/stackit"
    }
  }
}
