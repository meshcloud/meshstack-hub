terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}

provider "stackit" {
  # Authentication comes entirely from the environment the probe definition sets up.
}
