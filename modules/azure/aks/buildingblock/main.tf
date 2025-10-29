# Resource Group
resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.aks_cluster_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

# Subnet
resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.aks_cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "time_sleep" "wait_for_subnet" {
  depends_on      = [azurerm_subnet.aks_subnet]
  create_duration = "30s"
}

# Log Analytics
resource "azurerm_log_analytics_workspace" "law" {
  count               = var.log_analytics_workspace_name != null ? 1 : 0
  name                = "${var.aks_cluster_name}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = var.tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  depends_on = [time_sleep.wait_for_subnet]

  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.enable_auto_scaling ? null : var.node_count
    min_count           = var.enable_auto_scaling ? var.min_node_count : null
    max_count           = var.enable_auto_scaling ? var.max_node_count : null
    enable_auto_scaling = var.enable_auto_scaling
    vm_size             = var.vm_size
    os_disk_size_gb     = var.os_disk_size_gb
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    type                = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    admin_group_object_ids = [var.aks_admin_group_object_id]
  }

  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
    }
  )

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count,
      default_node_pool[0].upgrade_settings
    ]
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks_monitoring" {
  count                      = var.log_analytics_workspace_name != null ? 1 : 0
  name                       = "${azurerm_kubernetes_cluster.aks.name}-diag"
  target_resource_id         = azurerm_kubernetes_cluster.aks.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law[0].id

  enabled_log {
    category = "kube-apiserver"
  }
  enabled_log {
    category = "kube-controller-manager"
  }
  enabled_log {
    category = "kube-scheduler"
  }
  enabled_log {
    category = "cluster-autoscaler"
  }
  enabled_log {
    category = "kube-audit"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
