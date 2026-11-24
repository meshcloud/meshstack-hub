output "acr_id" {
  description = "The ID of the Azure Container Registry"
  value       = azurerm_container_registry.acr.id
}

output "acr_name" {
  description = "The name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "acr_login_server" {
  description = "The login server URL for the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_portal_url" {
  description = "Azure Portal URL of the Azure Container Registry"
  value       = local.portal_url
}

output "resource_group_name" {
  description = "Name of the resource group containing the ACR"
  value       = azurerm_resource_group.acr.name
}

output "private_endpoint_ip" {
  description = "Private IP address of the ACR private endpoint"
  value       = var.private_endpoint_enabled && var.sku == "Premium" ? azurerm_private_endpoint.acr_pe[0].private_service_connection[0].private_ip_address : null
}

output "vnet_id" {
  description = "ID of the virtual network used for private endpoint"
  value       = local.vnet_id
}

output "subnet_id" {
  description = "ID of the subnet used for private endpoint"
  value       = local.subnet_id
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone (when System-managed)"
  value       = var.private_endpoint_enabled && var.sku == "Premium" && var.private_dns_zone_id == "System" ? azurerm_private_dns_zone.acr_dns[0].id : null
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # Azure Container Registry

    Registry **${azurerm_container_registry.acr.name}** (${var.sku}) is ready.

    - **Login server**: `${azurerm_container_registry.acr.login_server}`
    - **Resource group**: ${azurerm_resource_group.acr.name}
    - **Network access**: ${var.private_endpoint_enabled && var.sku == "Premium" ? "private endpoint" : "public"}
    - [Open in Azure Portal](${local.portal_url})

    Log in with your Entra ID account and push an image:

    ```bash
    az acr login --name ${azurerm_container_registry.acr.name}
    docker tag myapp:v1 ${azurerm_container_registry.acr.login_server}/myapp:v1
    docker push ${azurerm_container_registry.acr.login_server}/myapp:v1
    ```

    You need the `AcrPush` role on the registry to push and `AcrPull` to pull.
  EOT
}
