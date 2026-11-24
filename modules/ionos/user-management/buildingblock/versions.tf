terraform {
  required_version = ">= 1.0"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0, < 3.0.0"
    }
    ionoscloud = {
      source  = "ionos-cloud/ionoscloud"
      version = ">= 6.4.0, < 7.0.0"
    }
  }
}