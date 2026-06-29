terraform {
  required_version = ">= 1.12.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = "~> 0.98.0"
    }
  }
}
