run "valid_aks_configuration" {
  command = plan

  variables {
    resource_group_name          = "test-aks-rg"
    location                     = "West Europe"
    aks_cluster_name             = "test-aks-cluster"
    dns_prefix                   = "testaks"
    node_count                   = 3
    vm_size                      = "Standard_DS2_v2"
    kubernetes_version           = "1.29.2"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    vnet_address_space           = "10.1.0.0/16"
    subnet_address_prefix        = "10.1.0.0/20"
    service_cidr                 = "10.2.0.0/16"
    dns_service_ip               = "10.2.0.10"
    log_analytics_workspace_name = "test-law"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.name == "test-aks-cluster"
    error_message = "AKS cluster name should match the input variable"
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.kubernetes_version == "1.29.2"
    error_message = "Kubernetes version should match the input variable"
  }

  assert {
    condition     = azurerm_virtual_network.vnet.address_space[0] == "10.1.0.0/16"
    error_message = "VNet address space should match the input variable"
  }

  assert {
    condition     = azurerm_subnet.aks_subnet.address_prefixes[0] == "10.1.0.0/20"
    error_message = "Subnet address prefix should match the input variable"
  }
}

run "valid_autoscaling_configuration" {
  command = plan

  variables {
    resource_group_name       = "test-aks-autoscale-rg"
    location                  = "West Europe"
    aks_cluster_name          = "test-aks-autoscale"
    dns_prefix                = "testaksautoscale"
    aks_admin_group_object_id = "12345678-1234-1234-1234-123456789012"
    enable_auto_scaling       = true
    min_node_count            = 2
    max_node_count            = 10
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.default_node_pool[0].enable_auto_scaling == true
    error_message = "Auto-scaling should be enabled when specified"
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
  command = plan

  variables {
    resource_group_name          = "test-aks-no-monitoring-rg"
    location                     = "West Europe"
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
    resource_group_name       = "test-aks-rg"
    location                  = "West Europe"
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
    resource_group_name       = "test-aks-rg"
    location                  = "West Europe"
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
    resource_group_name       = "test-aks-rg"
    location                  = "West Europe"
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
    resource_group_name       = "test-aks-rg"
    location                  = "West Europe"
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
    resource_group_name       = "test-aks-rg"
    location                  = "West Europe"
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
  command = plan

  variables {
    resource_group_name       = "test-aks-rg"
    location                  = "West Europe"
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
  command = plan

  variables {
    resource_group_name          = "test-aks-rg"
    location                     = "West Europe"
    aks_cluster_name             = "myapp-prod"
    dns_prefix                   = "myappprod"
    aks_admin_group_object_id    = "12345678-1234-1234-1234-123456789012"
    log_analytics_workspace_name = "test-law"
  }

  assert {
    condition     = azurerm_virtual_network.vnet.name == "myapp-prod-vnet"
    error_message = "VNet name should be derived from cluster name"
  }

  assert {
    condition     = azurerm_subnet.aks_subnet.name == "myapp-prod-subnet"
    error_message = "Subnet name should be derived from cluster name"
  }

  assert {
    condition     = azurerm_log_analytics_workspace.law[0].name == "myapp-prod-law"
    error_message = "Log Analytics Workspace name should be derived from cluster name"
  }
}
