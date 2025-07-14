provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false # This allows the deletion of the building block without having to separately delete the app resources
    }
  }

  resource_provider_registrations = "extended"

  storage_use_azuread = true
}

provider "azuread" {}
