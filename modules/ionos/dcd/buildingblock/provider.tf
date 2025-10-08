terraform {
  required_providers {
    ionoscloud = {
      source  = "ionos-cloud/ionoscloud"
      version = "~> 6.4.0"
    }
  }
}

provider "ionoscloud" {
  token = var.ionos_token
}