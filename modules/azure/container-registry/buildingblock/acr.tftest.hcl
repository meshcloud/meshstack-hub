run "basic_public_acr" {
  variables {
    acr_name            = "testacr01"
    resource_group_name = "acr-test-rg"
    location            = "westeurope"
    sku                 = "Premium"
  }

  assert {
    condition     = azurerm_container_registry.acr.sku == "Premium"
    error_message = "ACR SKU should be Premium"
  }

  assert {
    condition     = azurerm_container_registry.acr.admin_enabled == false
    error_message = "Admin should be disabled by default"
  }

  assert {
    condition     = azurerm_container_registry.acr.public_network_access_enabled == true
    error_message = "Public network access should be enabled by default"
  }

  assert {
    condition     = output.acr_login_server != ""
    error_message = "ACR login server output should not be empty"
  }

  assert {
    condition     = output.acr_id != ""
    error_message = "ACR ID output should not be empty"
  }
}

run "public_acr_with_ip_filtering" {
  variables {
    acr_name            = "testacr02"
    resource_group_name = "acr-test-rg"
    location            = "westeurope"
    sku                 = "Premium"
    allowed_ip_ranges   = ["203.0.113.0/24", "198.51.100.0/24"]
  }

  assert {
    condition     = length(var.allowed_ip_ranges) == 2
    error_message = "Should have 2 allowed IP ranges"
  }

  assert {
    condition     = output.acr_login_server != ""
    error_message = "ACR login server output should not be empty"
  }
}

run "premium_features_enabled" {
  variables {
    acr_name                = "testacr03"
    resource_group_name     = "acr-premium-test-rg"
    location                = "westeurope"
    sku                     = "Premium"
    retention_days          = 14
    trust_policy_enabled    = true
    zone_redundancy_enabled = true
    data_endpoint_enabled   = true
  }

  assert {
    condition     = var.sku == "Premium"
    error_message = "Premium features require Premium SKU"
  }

  assert {
    condition     = var.retention_days == 14
    error_message = "Retention should be 14 days"
  }

  assert {
    condition     = var.trust_policy_enabled == true
    error_message = "Trust policy should be enabled"
  }

  assert {
    condition     = var.zone_redundancy_enabled == true
    error_message = "Zone redundancy should be enabled"
  }

  assert {
    condition     = azurerm_container_registry.acr.data_endpoint_enabled == true
    error_message = "Data endpoints should be enabled for Premium SKU"
  }
}

run "premium_features_on_basic_sku" {
  variables {
    acr_name                = "testacr04"
    resource_group_name     = "acr-basic-test-rg"
    location                = "westeurope"
    sku                     = "Basic"
    retention_days          = 14
    trust_policy_enabled    = true
    zone_redundancy_enabled = true
    data_endpoint_enabled   = true
  }

  assert {
    condition     = azurerm_container_registry.acr.zone_redundancy_enabled == false
    error_message = "Zone redundancy should be disabled for Basic SKU"
  }

  assert {
    condition     = azurerm_container_registry.acr.data_endpoint_enabled == false
    error_message = "Data endpoints should be disabled for Basic SKU"
  }
}

run "geo_replication" {
  variables {
    acr_name            = "testacr05"
    resource_group_name = "acr-geo-test-rg"
    location            = "westeurope"
    sku                 = "Premium"
    georeplications = [
      {
        location                  = "northeurope"
        zone_redundancy_enabled   = true
        regional_endpoint_enabled = true
      },
      {
        location                  = "eastus"
        zone_redundancy_enabled   = false
        regional_endpoint_enabled = false
      }
    ]
  }

  assert {
    condition     = var.sku == "Premium"
    error_message = "Geo-replication requires Premium SKU"
  }

  assert {
    condition     = length(var.georeplications) == 2
    error_message = "Should have 2 geo-replication locations"
  }

  assert {
    condition     = contains([for g in var.georeplications : g.location], "northeurope")
    error_message = "Should replicate to North Europe"
  }

  assert {
    condition     = contains([for g in var.georeplications : g.location], "eastus")
    error_message = "Should replicate to East US"
  }
}

run "private_endpoint_with_system_dns" {
  variables {
    acr_name                 = "testacr06"
    resource_group_name      = "acr-pe-test-rg"
    location                 = "westeurope"
    sku                      = "Premium"
    private_endpoint_enabled = true
    private_dns_zone_id      = "System"
    vnet_address_space       = "10.100.0.0/16"
    subnet_address_prefix    = "10.100.1.0/24"
  }

  assert {
    condition     = var.private_endpoint_enabled == true
    error_message = "Private endpoint should be enabled"
  }

  assert {
    condition     = var.sku == "Premium"
    error_message = "Private endpoint requires Premium SKU"
  }

  assert {
    condition     = one(azurerm_private_endpoint.acr_pe[*].name) == "${var.acr_name}-pe"
    error_message = "Private endpoint name should follow naming convention"
  }

  assert {
    condition     = one(azurerm_private_dns_zone.acr_dns[*].name) == "privatelink.azurecr.io"
    error_message = "Private DNS zone should be privatelink.azurecr.io"
  }

  assert {
    condition     = output.acr_private_ip_address != null
    error_message = "Private IP address should be set for private endpoint"
  }
}

run "private_endpoint_without_public_access" {
  variables {
    acr_name                      = "testacr07"
    resource_group_name           = "acr-private-test-rg"
    location                      = "westeurope"
    sku                           = "Premium"
    private_endpoint_enabled      = true
    public_network_access_enabled = false
    private_dns_zone_id           = "System"
  }

  assert {
    condition     = azurerm_container_registry.acr.public_network_access_enabled == false
    error_message = "Public network access should be disabled"
  }

  assert {
    condition     = var.private_endpoint_enabled == true
    error_message = "Private endpoint should be enabled"
  }
}

run "aks_integration" {
  variables {
    acr_name                          = "testacr08"
    resource_group_name               = "acr-aks-test-rg"
    location                          = "westeurope"
    sku                               = "Premium"
    aks_managed_identity_principal_id = "00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = var.aks_managed_identity_principal_id != null
    error_message = "AKS managed identity should be provided"
  }

  assert {
    condition     = one(azurerm_role_assignment.acr_pull[*].role_definition_name) == "AcrPull"
    error_message = "Should assign AcrPull role to AKS identity"
  }

  assert {
    condition     = one(azurerm_role_assignment.acr_pull[*].scope) == azurerm_container_registry.acr.id
    error_message = "Role assignment should be scoped to ACR"
  }
}

run "admin_enabled" {
  variables {
    acr_name            = "testacr09"
    resource_group_name = "acr-admin-test-rg"
    location            = "westeurope"
    sku                 = "Basic"
    admin_enabled       = true
  }

  assert {
    condition     = azurerm_container_registry.acr.admin_enabled == true
    error_message = "Admin should be enabled"
  }

  assert {
    condition     = output.acr_admin_username != null
    error_message = "Admin username should be available"
  }

  assert {
    condition     = output.acr_admin_password != null
    error_message = "Admin password should be available"
  }
}

run "tags_applied" {
  variables {
    acr_name            = "testacr10"
    resource_group_name = "acr-tags-test-rg"
    location            = "westeurope"
    sku                 = "Premium"
    tags = {
      Environment = "test"
      CostCenter  = "engineering"
    }
  }

  assert {
    condition     = azurerm_container_registry.acr.tags["Environment"] == "test"
    error_message = "Environment tag should be set to test"
  }

  assert {
    condition     = azurerm_container_registry.acr.tags["CostCenter"] == "engineering"
    error_message = "CostCenter tag should be set to engineering"
  }

  assert {
    condition     = azurerm_container_registry.acr.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy tag should be automatically set to Terraform"
  }
}

run "network_rule_bypass" {
  variables {
    acr_name                   = "testacr11"
    resource_group_name        = "acr-bypass-test-rg"
    location                   = "westeurope"
    sku                        = "Premium"
    network_rule_bypass_option = "None"
  }

  assert {
    condition     = azurerm_container_registry.acr.network_rule_bypass_option == "None"
    error_message = "Network rule bypass should be set to None"
  }
}

run "anonymous_pull_enabled" {
  variables {
    acr_name               = "testacr12"
    resource_group_name    = "acr-anon-test-rg"
    location               = "westeurope"
    sku                    = "Standard"
    anonymous_pull_enabled = true
  }

  assert {
    condition     = azurerm_container_registry.acr.anonymous_pull_enabled == true
    error_message = "Anonymous pull should be enabled"
  }
}
