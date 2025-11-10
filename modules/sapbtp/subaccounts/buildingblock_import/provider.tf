terraform {
  backend "azurerm" {
    resource_group_name  = "buildingblocks-tfstates"
    storage_account_name = "tfstatesw4l8d"
    container_name       = "tfstates"
    key                  = "sapbtp/subaccounts/"
    use_azuread_auth     = true
  }
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.8.0"
    }
  }
}

provider "btp" {
  globalaccount = var.globalaccount
  # using ENV vars in meshStack for username and password
}
