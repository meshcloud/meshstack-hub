terraform {
  required_providers {
    ionoscloud = {
      source  = "ionos-cloud/ionoscloud"
      version = "~> 6.4.0"
    }
  }
}

provider "ionoscloud" {
  username = var.ionos_username
  password = var.ionos_password
  token    = var.ionos_token
}