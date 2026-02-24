terraform {
  required_providers {
    ionoscloud = {
      source  = "ionos-cloud/ionoscloud"
      version = "~> 6.4.0"
    }
  }
}

provider "ionoscloud" {
  # Authentication is handled via IONOS_TOKEN environment variable
  # or ionoscloud_username and ionoscloud_password environment variables
}
