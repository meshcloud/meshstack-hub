terraform {
  required_version = ">= 1.0"

  required_providers {
    github = {
      source = "integrations/github"
    }
  }

  backend "gcs" {
    bucket = "meshcloud-tf-states"
    prefix = "meshstack-hub/infra/github"
  }
}

provider "github" {
  owner = "meshcloud"
}
