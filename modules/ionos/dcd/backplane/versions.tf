terraform {
  required_version = ">= 1.0"
  required_providers {
    ionoscloud = {
      source  = "ionos-cloud/ionoscloud"
      version = "~> 6.4.0"
    }
  }
}