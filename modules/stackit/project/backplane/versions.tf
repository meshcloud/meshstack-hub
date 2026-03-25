terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = "~> 0.88.0"
    }
  }
}
