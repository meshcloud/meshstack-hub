terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.82.0"
    }
    aws = {
      source = "hashicorp/aws"
      # v5+ (SDK Go v2) always sends LocationConstraint in CreateBucket, even for us-east-1.
      # STACKIT StorageGRID only accepts requests with NO LocationConstraint (empty = us-east-1 behavior).
      # v4 (SDK Go v1) omits LocationConstraint for us-east-1, which is what StorageGRID requires.
      version = "~> 4.0"
    }
  }
}
