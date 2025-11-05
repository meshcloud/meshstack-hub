run "scenario_1_new_vnet_with_hub_peering" {
  variables {
    key_vault_name                = "testkv01"
    key_vault_resource_group_name = "kv-test-rg01"
    location                      = "Germany West Central"
    public_network_access_enabled = false

    private_endpoint_enabled = true
    private_dns_zone_id      = "System"
    vnet_address_space       = "10.250.0.0/16"
    subnet_address_prefix    = "10.250.1.0/24"

    hub_subscription_id     = "5066eff7-4173-4fea-8c67-268456b4a4f7"
    hub_resource_group_name = "likvid-hub-vnet-rg"
    hub_vnet_name           = "hub-vnet"
  }

  assert {
    condition     = azurerm_key_vault.key_vault.public_network_access_enabled == false
    error_message = "Public network access should be disabled"
  }

  assert {
    condition     = length(azurerm_virtual_network.vnet) == 1
    error_message = "VNet should be created when vnet_name is null"
  }

  assert {
    condition     = contains(one(azurerm_virtual_network.vnet[*].address_space), "10.250.0.0/16")
    error_message = "VNet should have correct address space"
  }

  assert {
    condition     = length(azurerm_private_endpoint.key_vault_pe) == 1
    error_message = "Private endpoint should be created"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.key_vault_to_hub) == 1
    error_message = "Peering to hub should be created when creating new VNet"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_key_vault) == 1
    error_message = "Peering from hub should be created when creating new VNet"
  }

  assert {
    condition     = length(azurerm_private_dns_zone.key_vault_dns) == 1
    error_message = "Private DNS zone should be created with System option"
  }

  assert {
    condition     = azurerm_key_vault.key_vault.enable_rbac_authorization == true
    error_message = "RBAC authorization should be enabled"
  }
}

run "scenario_2_existing_shared_vnet" {
  variables {
    key_vault_name                = "testkv02"
    key_vault_resource_group_name = "kv-test-rg02"
    location                      = "Germany West Central"
    public_network_access_enabled = false

    private_endpoint_enabled          = true
    private_dns_zone_id               = "System"
    vnet_name                         = "lz102-on-prem-nwk-vnet"
    existing_vnet_resource_group_name = "connectivity"
    subnet_name                       = "default"
  }

  assert {
    condition     = length(azurerm_virtual_network.vnet) == 0
    error_message = "VNet should NOT be created when vnet_name is provided"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.key_vault_to_hub) == 0
    error_message = "Peering to hub should NOT be created when using existing VNet"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_key_vault) == 0
    error_message = "Peering from hub should NOT be created when using existing VNet"
  }

  assert {
    condition     = length(azurerm_private_endpoint.key_vault_pe) == 1
    error_message = "Private endpoint should be created in existing VNet"
  }

  assert {
    condition     = var.existing_vnet_resource_group_name == "connectivity"
    error_message = "Should use VNet from different resource group"
  }
}

run "scenario_3_private_isolated_no_hub" {
  variables {
    key_vault_name                = "testkv03"
    key_vault_resource_group_name = "kv-test-rg03"
    location                      = "Germany West Central"
    public_network_access_enabled = false

    private_endpoint_enabled = true
    private_dns_zone_id      = "System"
    vnet_address_space       = "10.250.0.0/16"
    subnet_address_prefix    = "10.250.1.0/24"

    hub_vnet_name           = null
    hub_resource_group_name = null
    hub_subscription_id     = null
  }

  assert {
    condition     = azurerm_key_vault.key_vault.public_network_access_enabled == false
    error_message = "Public network access should be disabled"
  }

  assert {
    condition     = length(azurerm_virtual_network.vnet) == 1
    error_message = "VNet should be created"
  }

  assert {
    condition     = length(azurerm_private_endpoint.key_vault_pe) == 1
    error_message = "Private endpoint should be created"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.key_vault_to_hub) == 0
    error_message = "Peering to hub should NOT be created when hub_vnet_name is null"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_key_vault) == 0
    error_message = "Peering from hub should NOT be created when hub_vnet_name is null"
  }
}

run "scenario_4_completely_public" {
  variables {
    key_vault_name                = "testkv04"
    key_vault_resource_group_name = "kv-test-rg04"
    location                      = "Germany West Central"
    public_network_access_enabled = true

    private_endpoint_enabled = false
  }

  assert {
    condition     = azurerm_key_vault.key_vault.public_network_access_enabled == true
    error_message = "Public network access should be enabled"
  }

  assert {
    condition     = length(azurerm_private_endpoint.key_vault_pe) == 0
    error_message = "Private endpoint should NOT be created"
  }

  assert {
    condition     = length(azurerm_virtual_network.vnet) == 0
    error_message = "VNet should NOT be created"
  }

  assert {
    condition     = output.key_vault_uri != ""
    error_message = "Key Vault URI should be accessible"
  }
}

run "private_endpoint_subnet_network_policies" {
  variables {
    key_vault_name                = "testkv05"
    key_vault_resource_group_name = "kv-test-rg05"
    location                      = "Germany West Central"
    private_endpoint_enabled      = true
    public_network_access_enabled = false
    private_dns_zone_id           = "System"
    vnet_address_space            = "10.250.0.0/16"
    subnet_address_prefix         = "10.250.1.0/24"
  }

  assert {
    condition     = length(azurerm_subnet.pe_subnet) == 1
    error_message = "Subnet should be created"
  }

  assert {
    condition     = one(azurerm_subnet.pe_subnet[*].private_endpoint_network_policies) == "NetworkSecurityGroupEnabled"
    error_message = "Subnet should have NSG network policies enabled for private endpoints"
  }

  assert {
    condition     = length(azurerm_private_endpoint.key_vault_pe) == 1
    error_message = "Private endpoint should be created"
  }
}

run "tags_applied" {
  variables {
    key_vault_name                = "testkv06"
    key_vault_resource_group_name = "kv-test-rg06"
    location                      = "Germany West Central"
    tags = {
      Environment = "test"
      CostCenter  = "engineering"
    }
  }

  assert {
    condition     = azurerm_key_vault.key_vault.tags["Environment"] == "test"
    error_message = "Environment tag should be set to test"
  }

  assert {
    condition     = azurerm_key_vault.key_vault.tags["CostCenter"] == "engineering"
    error_message = "CostCenter tag should be set to engineering"
  }
}

run "rbac_authorization_enabled" {
  variables {
    key_vault_name                = "testkv07"
    key_vault_resource_group_name = "kv-test-rg07"
    location                      = "Germany West Central"
  }

  assert {
    condition     = azurerm_key_vault.key_vault.enable_rbac_authorization == true
    error_message = "RBAC authorization should be enabled"
  }

  assert {
    condition     = azurerm_key_vault.key_vault.purge_protection_enabled == true
    error_message = "Purge protection should be enabled"
  }

  assert {
    condition     = azurerm_key_vault.key_vault.soft_delete_retention_days == 7
    error_message = "Soft delete retention should be 7 days"
  }
}

run "existing_vnet_with_custom_dns_zone" {
  command = plan
  variables {
    key_vault_name                = "testkv08"
    key_vault_resource_group_name = "kv-test-rg08"
    location                      = "Germany West Central"
    public_network_access_enabled = false

    private_endpoint_enabled          = true
    private_dns_zone_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/dns-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    vnet_name                         = "lz102-on-prem-nwk-vnet"
    existing_vnet_resource_group_name = "connectivity"
    subnet_name                       = "default"
  }

  assert {
    condition     = var.private_dns_zone_id != "System"
    error_message = "Should use custom DNS zone ID"
  }

  assert {
    condition     = length(azurerm_private_dns_zone.key_vault_dns) == 0
    error_message = "Private DNS zone should NOT be created when custom ID is provided"
  }

  assert {
    condition     = length(azurerm_private_endpoint.key_vault_pe) == 1
    error_message = "Private endpoint should be created with custom DNS zone"
  }
}

run "private_endpoint_subresource_name" {
  variables {
    key_vault_name                = "testkv09"
    key_vault_resource_group_name = "kv-test-rg09"
    location                      = "Germany West Central"
    private_endpoint_enabled      = true
    public_network_access_enabled = false
    private_dns_zone_id           = "System"
    vnet_address_space            = "10.250.0.0/16"
    subnet_address_prefix         = "10.250.1.0/24"
  }

  assert {
    condition     = length(azurerm_private_endpoint.key_vault_pe) == 1
    error_message = "Private endpoint should be created"
  }

  assert {
    condition     = contains(one(azurerm_private_endpoint.key_vault_pe[*].private_service_connection[*].subresource_names), "vault")
    error_message = "Private endpoint should use 'vault' subresource name"
  }
}

run "dns_zone_name_validation" {
  variables {
    key_vault_name                = "testkv10"
    key_vault_resource_group_name = "kv-test-rg10"
    location                      = "Germany West Central"
    private_endpoint_enabled      = true
    private_dns_zone_id           = "System"
    vnet_address_space            = "10.250.0.0/16"
    subnet_address_prefix         = "10.250.1.0/24"
  }

  assert {
    condition     = length(azurerm_private_dns_zone.key_vault_dns) == 1
    error_message = "Private DNS zone should be created"
  }

  assert {
    condition     = one(azurerm_private_dns_zone.key_vault_dns[*].name) == "privatelink.vaultcore.azure.net"
    error_message = "Private DNS zone should use correct naming for Key Vault"
  }
}
