terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.management, aws.meshcloud]
    }
    meshstack = {
      source = "meshcloud/meshstack"
    }
  }
}
