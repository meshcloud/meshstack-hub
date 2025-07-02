output "config_tf" {
  description = "Generates a config.tf that can be dropped into meshStack's BuildingBlockDefinition as an encrypted file input to configure this building block."
  sensitive   = true
  value       = <<EOF
provider "github" {
  owner = "${var.github_org}"

  app_auth {
    id              = "${var.github_app_id}"
    installation_id = "${var.github_app_installation_id}"

    # TODO: ensure the pem file exists on disk in the BB execution environment (with meshStack: secret file input)
    pem_file = file("./github-app.private-key.pem")
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false # This allows the deletion of the building block without having to separately delete the app resources
    }
  }

  resource_provider_registrations = "core"

  storage_use_azuread        = true

  tenant_id       = "${data.azurerm_subscription.current.tenant_id}"
  subscription_id = var.subscription_id
  client_id       = "${azuread_service_principal.starterkit.client_id}"
  client_secret   = "${azuread_service_principal_password.starterkit.value}"
}

locals {
  deploy_role_definition_id = "${azurerm_role_definition.starterkit_deploy.role_definition_id}"
}

provider "azuread" {
  tenant_id       = "${data.azurerm_subscription.current.tenant_id}"
  client_id       = "${azuread_service_principal.starterkit.client_id}"
  client_secret   = "${azuread_service_principal_password.starterkit.value}"
}
EOF
}
