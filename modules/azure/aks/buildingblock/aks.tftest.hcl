run "scenario_1_new_vnet_with_hub_peering" {

  variables {
    subscription_id              = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    aks_cluster_name             = "test-aks-hub"
    resource_group_name          = "test-aks-hub-rg"
    location                     = "Germany West Central"
    dns_prefix                   = "testakshub"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    log_analytics_workspace_name = "test-law"

    private_cluster_enabled             = true
    private_dns_zone_id                 = "System"
    private_cluster_public_fqdn_enabled = false

    vnet_address_space    = "10.240.0.0/16"
    subnet_address_prefix = "10.240.0.0/20"

    hub_subscription_id     = "5066eff7-4173-4fea-8c67-268456b4a4f7"
    hub_resource_group_name = "likvid-hub-vnet-rg"
    hub_vnet_name           = "hub-vnet"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.private_cluster_enabled == true
    error_message = "AKS cluster should be private"
  }

  assert {
    condition     = length(azurerm_virtual_network.vnet) == 1
    error_message = "VNet should be created when vnet_name is null"
  }

  assert {
    condition     = contains(one(azurerm_virtual_network.vnet[*].address_space), "10.240.0.0/16")
    error_message = "VNet should have correct address space"
  }

  assert {
    condition     = length(azurerm_subnet.aks_subnet) == 1
    error_message = "Subnet should be created when subnet_name is null"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.aks_to_hub) == 1
    error_message = "Peering to hub should be created when creating new VNet"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_aks) == 1
    error_message = "Peering from hub should be created when creating new VNet"
  }

  assert {
    condition     = one(azurerm_virtual_network_peering.hub_to_aks[*].allow_gateway_transit) == false
    error_message = "Hub should not allow gateway transit when not configured"
  }

  assert {
    condition     = one(azurerm_virtual_network_peering.aks_to_hub[*].use_remote_gateways) == false
    error_message = "AKS VNet should not use remote gateways when not configured"
  }
}

run "scenario_2_existing_shared_vnet" {

  variables {
    subscription_id              = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    aks_cluster_name             = "test-aks-shared"
    resource_group_name          = "test-aks-shared-rg"
    location                     = "Germany West Central"
    dns_prefix                   = "testaksshared"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    log_analytics_workspace_name = "test-law"

    private_cluster_enabled             = true
    private_dns_zone_id                 = "System"
    private_cluster_public_fqdn_enabled = false

    vnet_name                         = "lz102-on-prem-nwk-vnet"
    existing_vnet_resource_group_name = "connectivity"
    subnet_name                       = "default"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.private_cluster_enabled == true
    error_message = "AKS cluster should be private"
  }

  assert {
    condition     = length(azurerm_virtual_network.vnet) == 0
    error_message = "VNet should NOT be created when vnet_name is provided"
  }

  assert {
    condition     = length(azurerm_subnet.aks_subnet) == 0
    error_message = "Subnet should NOT be created when subnet_name is provided"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.aks_to_hub) == 0
    error_message = "Peering to hub should NOT be created when using existing VNet"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_aks) == 0
    error_message = "Peering from hub should NOT be created when using existing VNet"
  }

  assert {
    condition     = var.existing_vnet_resource_group_name == "connectivity"
    error_message = "Should use VNet from different resource group"
  }
}



run "scenario_4_public_cluster" {

  variables {
    subscription_id              = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    aks_cluster_name             = "test-aks-public"
    resource_group_name          = "test-aks-public-rg"
    location                     = "Germany West Central"
    dns_prefix                   = "testakspublic"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    log_analytics_workspace_name = "test-law"

    private_cluster_enabled = false

    vnet_address_space    = "10.240.0.0/16"
    subnet_address_prefix = "10.240.0.0/20"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.private_cluster_enabled == false
    error_message = "AKS cluster should be public"
  }

  assert {
    condition     = length(azurerm_virtual_network.vnet) == 1
    error_message = "VNet should be created"
  }

  assert {
    condition     = length(azurerm_subnet.aks_subnet) == 1
    error_message = "Subnet should be created"
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.aks_to_hub) == 0
    error_message = "Peering should NOT be created for public cluster"
  }

  assert {
    condition     = output.oidc_issuer_url != ""
    error_message = "OIDC issuer URL should be available"
  }
}

run "valid_autoscaling_configuration" {

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-autoscale-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks-autoscale"
    dns_prefix                = "testaksautoscale"
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
    enable_auto_scaling       = true
    min_node_count            = 2
    max_node_count            = 10
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].min_count == 2
    error_message = "Min node count should match the input variable"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].max_count == 10
    error_message = "Max node count should match the input variable"
  }
}

run "no_monitoring_when_law_null" {

  variables {
    subscription_id              = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name          = "test-aks-no-monitoring-rg"
    location                     = "Germany West Central"
    aks_cluster_name             = "test-aks-no-monitoring"
    dns_prefix                   = "testaksnomon"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    log_analytics_workspace_name = null
  }

  assert {
    condition     = length(azurerm_log_analytics_workspace.law) == 0
    error_message = "Log Analytics Workspace should not be created when log_analytics_workspace_name is null"
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.aks_monitoring) == 0
    error_message = "Diagnostic settings should not be created when log_analytics_workspace_name is null"
  }
}

run "invalid_dns_prefix" {
  command = plan

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks"
    dns_prefix                = "Invalid_DNS_Prefix!"
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
  }

  expect_failures = [
    var.dns_prefix
  ]
}

run "invalid_kubernetes_version" {
  command = plan

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks"
    dns_prefix                = "testaks"
    kubernetes_version        = "invalid-version"
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
  }

  expect_failures = [
    var.kubernetes_version
  ]
}

run "invalid_admin_group_object_id" {
  command = plan

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks"
    dns_prefix                = "testaks"
    aks_admin_group_object_id = "not-a-valid-guid"
  }

  expect_failures = [
    var.aks_admin_group_object_id
  ]
}

run "invalid_node_count_too_low" {
  command = plan

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks"
    dns_prefix                = "testaks"
    node_count                = 0
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
  }

  expect_failures = [
    var.node_count
  ]
}

run "invalid_os_disk_size" {
  command = plan

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks"
    dns_prefix                = "testaks"
    os_disk_size_gb           = 20
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
  }

  expect_failures = [
    var.os_disk_size_gb
  ]
}

run "custom_network_plugin_kubenet" {

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks-kubenet"
    dns_prefix                = "testakskube"
    network_plugin            = "kubenet"
    network_policy            = "calico"
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].network_plugin == "kubenet"
    error_message = "Network plugin should be kubenet when specified"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.network_profile[0].network_policy == "calico"
    error_message = "Network policy should be calico when specified"
  }
}

run "naming_derived_from_cluster_name" {

  variables {
    subscription_id              = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name          = "test-aks-rg"
    location                     = "Germany West Central"
    aks_cluster_name             = "myapp-prod"
    dns_prefix                   = "myappprod"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    log_analytics_workspace_name = "test-law"
  }

  assert {
    condition     = one(azurerm_virtual_network.vnet[*].name) == "myapp-prod-vnet"
    error_message = "VNet name should be derived from cluster name"
  }

  assert {
    condition     = one(azurerm_subnet.aks_subnet[*].name) == "myapp-prod-subnet"
    error_message = "Subnet name should be derived from cluster name"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.law[0].name == "myapp-prod-law"
    error_message = "Log Analytics Workspace name should be derived from cluster name"
  }
}

run "workload_identity_enabled" {

  variables {
    subscription_id           = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    resource_group_name       = "test-aks-rg"
    location                  = "Germany West Central"
    aks_cluster_name          = "test-aks-wi"
    dns_prefix                = "testakswi"
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.workload_identity_enabled == true
    error_message = "Workload Identity should be enabled"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.oidc_issuer_enabled == true
    error_message = "OIDC issuer should be enabled"
  }

  assert {
    condition     = output.oidc_issuer_url != ""
    error_message = "OIDC issuer URL should be available"
  }
}

run "gateway_transit_configuration" {
  command = plan

  variables {
    subscription_id              = "ffb344c9-26d7-45f5-9ba0-806a024ae697"
    aks_cluster_name             = "test-aks-gateway"
    resource_group_name          = "test-aks-gateway-rg"
    location                     = "Germany West Central"
    dns_prefix                   = "testaksgateway"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    log_analytics_workspace_name = "test-law"

    private_cluster_enabled             = true
    private_dns_zone_id                 = "System"
    private_cluster_public_fqdn_enabled = false

    vnet_address_space    = "10.240.0.0/16"
    subnet_address_prefix = "10.240.0.0/20"

    hub_subscription_id            = "5066eff7-4173-4fea-8c67-268456b4a4f7"
    hub_resource_group_name        = "likvid-hub-vnet-rg"
    hub_vnet_name                  = "hub-vnet"
    allow_gateway_transit_from_hub = false
  }

  assert {
    condition     = one(azurerm_virtual_network_peering.hub_to_aks[*].allow_gateway_transit) == false
    error_message = "Hub should not allow gateway transit when disabled"
  }

  assert {
    condition     = one(azurerm_virtual_network_peering.aks_to_hub[*].use_remote_gateways) == false
    error_message = "AKS VNet should not use remote gateways when gateway transit disabled"
  }
}
