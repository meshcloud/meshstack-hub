output "provider_config" {
  description = "ENVIRONMENT VARIABLES for the AzureRM and AzureAD Providers, which you can use to configure your Building Block Definition."
  sensitive   = true
  value       = <<EOF

# Use the following Environment variables to configure your Building Blocki Definition for the Terraform azurerm/azuread Provider:

ARM_TENANT_ID       = "${data.azurerm_subscription.current.tenant_id}"
ARM_SUBSCRIPTION_ID = "USE THE PLATFORM TENANT ID"
ARM_CLIENT_ID       = "${azuread_service_principal.starterkit.client_id}"
ARM_CLIENT_SECRET   = "${azuread_service_principal_password.starterkit.value}"

# The Role definition ID to assign to the GitHub Actions App Service Managed Identity. This is used to deploy resources via Terraform.

var.deploy_role_definition_id = "${azurerm_role_definition.starterkit_deploy.role_definition_id}"

EOF
}
