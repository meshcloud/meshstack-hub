output "provider_config" {
  description = "Generates a config.tf that can be dropped into meshStack's BuildingBlockDefinition as an encrypted file input to configure this building block."
  sensitive   = true
  value       = <<EOF

use following Environment variables to configure your Terraform AZURERM Provider:

  ARM_TENANT_ID       = "${data.azurerm_subscription.current.tenant_id}"
  ARM_SUBSCRIPTION_ID = "USE THE PLATFORM TENANT ID"
  ARM_CLIENT_ID       = "${azuread_service_principal.starterkit.client_id}"
  ARM_CLIENT_SECRET   = "${azuread_service_principal_password.starterkit.value}"
}

use following Environment variables to configure your Terraform AZUREAD Provider:

  ARM_TENANT_ID       = "${data.azurerm_subscription.current.tenant_id}"
  ARM_CLIENT_ID       = "${azuread_service_principal.starterkit.client_id}"
  ARM_CLIENT_SECRET   = "${azuread_service_principal_password.starterkit.value}"
}
EOF
}

output "deploy_role_definition_id" {
  value = azurerm_role_definition.starterkit_deploy.role_definition_id
}
