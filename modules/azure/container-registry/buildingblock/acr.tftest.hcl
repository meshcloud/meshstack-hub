run "scenario_1_new_vnet_with_hub_peering" {
  variables {
    acr_name                      = "testacr01"
    resource_group_name           = "acr-test-rg"
    location                      = "westeurope"
    sku                           = "Premium"
    admin_enabled                 = false
    public_network_access_enabled = false

    private_endpoint_enabled = true
    private_dns_zone_id      = "System"
    vnet_address_space       = "10.250.0.0/16"
    subnet_address_prefix    = "10.250.1.0/24"

    hub_subscription_id     = "00000000-0000-0000-0000-000000000001"
    hub_resource_group_name = "hub-network-rg"
    hub_vnet_name           = "hub-vnet"
  }

  assert {
    condition     = azurerm_container_registry.acr.sku == "Premium"
    error_message = "ACR SKU should be Premium for private endpoint"
  }

  assert {
    condition     = azurerm_container_registry.acr.public_network_access_enabled == false
    error_message = "Public network access should be disabled"
  }

  assert {
    condition     = one(azurerm_virtual_network.acr_vnet[*].name) != null
    error_message = "VNet should be created when vnet_name is null"
  }

  assert {
    condition     = one(azurerm_virtual_network.acr_vnet[*].address_space[0]) == "10.250.0.0/16"
    error_message = "VNet should have correct address space"
  }

  assert {
    condition     = one(azurerm_private_endpoint.acr_pe[*].name) == "${var.acr_name}-pe"
    error_message = "Private endpoint should be created"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.acr_to_hub) > 0
    error_message = "Peering to hub should be created when creating new VNet"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_acr) > 0
    error_message = "Peering from hub should be created when creating new VNet"
  }

  assert {
    condition     = one(azurerm_private_dns_zone.acr_dns[*].name) == "privatelink.azurecr.io"
    error_message = "Private DNS zone should be created with System option"
  }
}

run "scenario_2_existing_shared_vnet" {
  variables {
    acr_name                      = "testacr02"
    resource_group_name           = "acr-test-rg"
    location                      = "westeurope"
    sku                           = "Premium"
    admin_enabled                 = false
    public_network_access_enabled = false

    private_endpoint_enabled          = true
    private_dns_zone_id               = "System"
    vnet_name                         = "shared-connectivity-vnet"
    existing_vnet_resource_group_name = "connectivity-rg"
    subnet_name                       = "acr-subnet"
  }

  assert {
    condition     = azurerm_container_registry.acr.sku == "Premium"
    error_message = "ACR SKU should be Premium for private endpoint"
  }

  assert {
    condition     = length(azurerm_virtual_network.acr_vnet) == 0
    error_message = "VNet should NOT be created when vnet_name is provided"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.acr_to_hub) == 0
    error_message = "Peering to hub should NOT be created when using existing VNet"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_acr) == 0
    error_message = "Peering from hub should NOT be created when using existing VNet"
  }

  assert {
    condition     = one(azurerm_private_endpoint.acr_pe[*].name) == "${var.acr_name}-pe"
    error_message = "Private endpoint should be created in existing VNet"
  }

  assert {
    condition     = var.existing_vnet_resource_group_name == "connectivity-rg"
    error_message = "Should use VNet from different resource group"
  }
}

run "scenario_3_private_isolated_no_hub" {
  variables {
    acr_name                      = "testacr03"
    resource_group_name           = "acr-test-rg"
    location                      = "westeurope"
    sku                           = "Premium"
    admin_enabled                 = false
    public_network_access_enabled = false

    private_endpoint_enabled = true
    private_dns_zone_id      = "System"
    vnet_address_space       = "10.250.0.0/16"
    subnet_address_prefix    = "10.250.1.0/24"
  }

  assert {
    condition     = azurerm_container_registry.acr.sku == "Premium"
    error_message = "ACR SKU should be Premium for private endpoint"
  }

  assert {
    condition     = azurerm_container_registry.acr.public_network_access_enabled == false
    error_message = "Public network access should be disabled"
  }

  assert {
    condition     = one(azurerm_virtual_network.acr_vnet[*].name) != null
    error_message = "VNet should be created"
  }

  assert {
    condition     = one(azurerm_private_endpoint.acr_pe[*].name) == "${var.acr_name}-pe"
    error_message = "Private endpoint should be created"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.acr_to_hub) == 0
    error_message = "Peering to hub should NOT be created when hub_vnet_name is null"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_acr) == 0
    error_message = "Peering from hub should NOT be created when hub_vnet_name is null"
  }
}

run "scenario_4_completely_public" {
  variables {
    acr_name                      = "testacr04"
    resource_group_name           = "acr-test-rg"
    location                      = "westeurope"
    sku                           = "Standard"
    admin_enabled                 = false
    public_network_access_enabled = true

    private_endpoint_enabled = false
  }

  assert {
    condition     = azurerm_container_registry.acr.sku == "Standard"
    error_message = "Can use cheaper SKU for public ACR"
  }

  assert {
    condition     = azurerm_container_registry.acr.public_network_access_enabled == true
    error_message = "Public network access should be enabled"
  }

  assert {
    condition     = length(azurerm_private_endpoint.acr_pe) == 0
    error_message = "Private endpoint should NOT be created"
  }

  assert {
    condition     = length(azurerm_virtual_network.acr_vnet) == 0
    error_message = "VNet should NOT be created"
  }

  assert {
    condition     = output.acr_login_server != ""
    error_message = "ACR login server should be accessible"
  }
}

run "public_acr_with_ip_filtering" {
  variables {
    acr_name                      = "testacr05"
    resource_group_name           = "acr-test-rg"
    location                      = "westeurope"
    sku                           = "Premium"
    public_network_access_enabled = true
    allowed_ip_ranges             = ["203.0.113.0/24", "198.51.100.5/32"]
  }

  assert {
    condition     = azurerm_container_registry.acr.public_network_access_enabled == true
    error_message = "Public network access should be enabled"
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
    acr_name                = "testacr06"
    resource_group_name     = "acr-premium-test-rg"
    location                = "westeurope"
    sku                     = "Premium"
    retention_days          = 30
    trust_policy_enabled    = true
    zone_redundancy_enabled = true
    data_endpoint_enabled   = true
  }

  assert {
    condition     = var.sku == "Premium"
    error_message = "Premium features require Premium SKU"
  }

  assert {
    condition     = var.retention_days == 30
    error_message = "Retention should be 30 days"
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
    acr_name                = "testacr07"
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
    acr_name            = "testacr08"
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

run "private_endpoint_subnet_network_policies" {
  variables {
    acr_name                      = "testacr09"
    resource_group_name           = "acr-test-rg"
    location                      = "westeurope"
    sku                           = "Premium"
    private_endpoint_enabled      = true
    public_network_access_enabled = false
    private_dns_zone_id           = "System"
    vnet_address_space            = "10.250.0.0/16"
    subnet_address_prefix         = "10.250.1.0/24"
  }

  assert {
    condition     = one(azurerm_subnet.acr_subnet[*].private_endpoint_network_policies) == "NetworkSecurityGroupEnabled"
    error_message = "Subnet should have NSG network policies enabled for private endpoints"
  }

  assert {
    condition     = one(azurerm_private_endpoint.acr_pe[*].name) == "${var.acr_name}-pe"
    error_message = "Private endpoint should be created"
  }
}

run "admin_enabled" {
  variables {
    acr_name            = "testacr10"
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
    acr_name            = "testacr11"
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
    acr_name                   = "testacr12"
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
    acr_name               = "testacr13"
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

run "existing_vnet_with_custom_dns_zone" {
  variables {
    acr_name                      = "testacr14"
    resource_group_name           = "acr-test-rg"
    location                      = "westeurope"
    sku                           = "Premium"
    admin_enabled                 = false
    public_network_access_enabled = false

    private_endpoint_enabled          = true
    private_dns_zone_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/dns-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
    vnet_name                         = "existing-vnet"
    existing_vnet_resource_group_name = "network-rg"
    subnet_name                       = "acr-subnet"
  }

  assert {
    condition     = var.private_dns_zone_id != "System"
    error_message = "Should use custom DNS zone ID"
  }

  assert {
    condition     = length(azurerm_private_dns_zone.acr_dns) == 0
    error_message = "Private DNS zone should NOT be created when custom ID is provided"
  }

  assert {
    condition     = one(azurerm_private_endpoint.acr_pe[*].name) == "${var.acr_name}-pe"
    error_message = "Private endpoint should be created with custom DNS zone"
  }
}
