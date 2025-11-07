terraform {
  backend "azurerm" {
    resource_group_name  = "buildingblocks-tfstates"
    storage_account_name = "tfstatesw4l8d"
    container_name       = "tfstates"
    key                  = "sapbtp/subaccounts/terraform.tfstate"
    subscription_id      = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    client_id            = var.client_id
    client_secret        = var.client_secret
    tenant_id            = "5f0e994b-6436-4f58-be96-4dc7bebff827"
    use_azuread_auth     = true
  }
}

provider "btp" {
  globalaccount = var.globalaccount
  # using ENV vars in meshStack for username and password
}
