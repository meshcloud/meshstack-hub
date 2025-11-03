# Resource Group
resource "azurerm_resource_group" "aks" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  count               = var.vnet_name == null ? 1 : 0
  name                = "${var.aks_cluster_name}-vnet"
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags

  depends_on = [azurerm_resource_group.aks]
}

data "azurerm_virtual_network" "existing_vnet" {
  count               = var.vnet_name != null ? 1 : 0
  name                = var.vnet_name
  resource_group_name = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : var.resource_group_name
}

locals {
  vnet_id   = var.vnet_name != null ? data.azurerm_virtual_network.existing_vnet[0].id : azurerm_virtual_network.vnet[0].id
  vnet_name = var.vnet_name != null ? var.vnet_name : azurerm_virtual_network.vnet[0].name
}

resource "azurerm_subnet" "aks_subnet" {
  count                = var.subnet_name == null ? 1 : 0
  name                 = "${var.aks_cluster_name}-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = local.vnet_name
  address_prefixes     = [var.subnet_address_prefix]

  depends_on = [azurerm_virtual_network.vnet]
}

data "azurerm_subnet" "existing_subnet" {
  count                = var.subnet_name != null ? 1 : 0
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : var.resource_group_name
}

locals {
  subnet_id = var.subnet_name != null ? data.azurerm_subnet.existing_subnet[0].id : azurerm_subnet.aks_subnet[0].id
}

# Route table for UDR scenarios (private cluster with hub connectivity)
resource "azurerm_route_table" "aks_rt" {
  count               = var.private_cluster_enabled && var.hub_vnet_name != null && var.subnet_name == null ? 1 : 0
  name                = "${var.aks_cluster_name}-rt"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = var.tags
}

resource "azurerm_subnet_route_table_association" "aks_subnet_rt" {
  count          = var.private_cluster_enabled && var.hub_vnet_name != null && var.subnet_name == null ? 1 : 0
  subnet_id      = azurerm_subnet.aks_subnet[0].id
  route_table_id = azurerm_route_table.aks_rt[0].id
}

resource "time_sleep" "wait_for_subnet" {
  depends_on      = [azurerm_subnet.aks_subnet, azurerm_subnet_route_table_association.aks_subnet_rt]
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

  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_cluster_enabled ? var.private_dns_zone_id : null
  private_cluster_public_fqdn_enabled = var.private_cluster_enabled ? var.private_cluster_public_fqdn_enabled : false

  default_node_pool {
    name                 = "system"
    auto_scaling_enabled = var.enable_auto_scaling
    node_count           = !var.enable_auto_scaling ? var.node_count : null
    min_count            = var.enable_auto_scaling ? var.min_node_count : null
    max_count            = var.enable_auto_scaling ? var.max_node_count : null
    vm_size              = var.vm_size
    os_disk_size_gb      = var.os_disk_size_gb
    vnet_subnet_id       = local.subnet_id
    type                 = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  role_based_access_control_enabled = true

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.aks_admin_group_object_id != null ? [1] : []
    content {
      admin_group_object_ids = [var.aks_admin_group_object_id]
    }
  }

  network_profile {
    network_plugin    = var.network_plugin
    network_policy    = var.network_policy
    service_cidr      = var.service_cidr
    dns_service_ip    = var.dns_service_ip
    load_balancer_sku = "standard"
    outbound_type     = var.private_cluster_enabled && var.hub_vnet_name != null ? "userDefinedRouting" : "loadBalancer"
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

  enabled_metric {
    category = "AllMetrics"
  }
}

data "azurerm_resource_group" "hub_rg" {
  count    = var.private_cluster_enabled && var.hub_resource_group_name != null ? 1 : 0
  provider = azurerm.hub
  name     = var.hub_resource_group_name
}

data "azurerm_virtual_network" "hub_vnet" {
  count               = var.private_cluster_enabled && var.hub_vnet_name != null ? 1 : 0
  provider            = azurerm.hub
  name                = var.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_rg[0].name
}

resource "azurerm_virtual_network_peering" "aks_to_hub" {
  count                     = var.private_cluster_enabled && var.vnet_name == null && var.hub_vnet_name != null ? 1 : 0
  name                      = "${var.aks_cluster_name}-to-hub"
  resource_group_name       = azurerm_resource_group.aks.name
  virtual_network_name      = local.vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.hub_vnet[0].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.allow_gateway_transit_from_hub
}

resource "azurerm_virtual_network_peering" "hub_to_aks" {
  count                     = var.private_cluster_enabled && var.vnet_name == null && var.hub_vnet_name != null ? 1 : 0
  provider                  = azurerm.hub
  name                      = "hub-to-${var.aks_cluster_name}"
  resource_group_name       = data.azurerm_resource_group.hub_rg[0].name
  virtual_network_name      = data.azurerm_virtual_network.hub_vnet[0].name
  remote_virtual_network_id = local.vnet_id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.allow_gateway_transit_from_hub
  use_remote_gateways          = false
}
