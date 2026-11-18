terraform {
  required_version = ">= 1.11.0"
  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.27.1 is the first release whose create returns at once when the run waits for a dependency.
      version = ">= 0.27.1"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0, < 3.0.0"
    }
  }
}
