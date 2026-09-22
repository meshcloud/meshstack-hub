terraform {
  required_version = ">= 1.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
    aws = {
      source = "hashicorp/aws"
      # Same major as the building block, which found v5 incompatible with STACKIT's StorageGRID.
      version = ">= 4.0, < 5.0"
    }
  }
}
