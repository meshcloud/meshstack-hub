terraform {
  required_version = ">= 1.0"
  required_providers {
    # external is used to capture the AWS CLI version at apply time.
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }
  }
}
