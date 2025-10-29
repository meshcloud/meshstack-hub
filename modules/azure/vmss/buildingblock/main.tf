data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

resource "random_string" "resource_code" {
  length  = 5
  special = false
  upper   = false
}

resource "azurerm_resource_group" "vmss_rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vmss_vnet" {
  name                = "${var.vmss_name}-vnet"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags
}

resource "azurerm_subnet" "vmss_subnet" {
  name                 = "${var.vmss_name}-subnet"
  resource_group_name  = azurerm_resource_group.vmss_rg.name
  virtual_network_name = azurerm_virtual_network.vmss_vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

resource "azurerm_public_ip" "lb_public_ip" {
  count               = var.enable_load_balancer && var.enable_public_ip ? 1 : 0
  name                = "${var.vmss_name}-lb-pip"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_lb" "vmss_lb" {
  count               = var.enable_load_balancer ? 1 : 0
  name                = "${var.vmss_name}-lb"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "LoadBalancerFrontEnd"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.lb_public_ip[0].id : null
    subnet_id                     = !var.enable_public_ip ? azurerm_subnet.vmss_subnet.id : null
    private_ip_address_allocation = !var.enable_public_ip ? "Dynamic" : null
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "vmss_backend_pool" {
  count           = var.enable_load_balancer ? 1 : 0
  name            = "${var.vmss_name}-backend-pool"
  loadbalancer_id = azurerm_lb.vmss_lb[0].id
}

resource "azurerm_lb_probe" "vmss_health_probe" {
  count               = var.enable_load_balancer ? 1 : 0
  name                = "${var.vmss_name}-health-probe"
  loadbalancer_id     = azurerm_lb.vmss_lb[0].id
  protocol            = var.health_probe_protocol
  port                = var.health_probe_port
  request_path        = var.health_probe_protocol == "Http" ? var.health_probe_path : null
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "vmss_lb_rule" {
  count                          = var.enable_load_balancer ? length(var.lb_rules) : 0
  name                           = var.lb_rules[count.index].name
  loadbalancer_id                = azurerm_lb.vmss_lb[0].id
  protocol                       = var.lb_rules[count.index].protocol
  frontend_port                  = var.lb_rules[count.index].frontend_port
  backend_port                   = var.lb_rules[count.index].backend_port
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss_backend_pool[0].id]
  probe_id                       = azurerm_lb_probe.vmss_health_probe[0].id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  count               = var.os_type == "Linux" ? 1 : 0
  name                = var.vmss_name
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  sku                 = var.sku
  instances           = var.enable_autoscaling ? null : var.instances
  admin_username      = var.admin_username
  upgrade_mode        = var.upgrade_mode
  zones               = var.zones

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_type
    disk_size_gb         = var.os_disk_size_gb
  }

  network_interface {
    name    = "${var.vmss_name}-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = var.enable_load_balancer ? [azurerm_lb_backend_address_pool.vmss_backend_pool[0].id] : []
    }
  }

  identity {
    type = "SystemAssigned"
  }

  priority        = var.enable_spot_instances ? "Spot" : "Regular"
  eviction_policy = var.enable_spot_instances ? var.spot_eviction_policy : null
  max_bid_price   = var.enable_spot_instances ? var.spot_max_bid_price : null

  custom_data = var.custom_data

  disable_password_authentication = true

  tags = var.tags
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  count               = var.os_type == "Windows" ? 1 : 0
  name                = var.vmss_name
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  sku                 = var.sku
  instances           = var.enable_autoscaling ? null : var.instances
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  upgrade_mode        = var.upgrade_mode
  zones               = var.zones

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_type
    disk_size_gb         = var.os_disk_size_gb
  }

  network_interface {
    name    = "${var.vmss_name}-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = var.enable_load_balancer ? [azurerm_lb_backend_address_pool.vmss_backend_pool[0].id] : []
    }
  }

  identity {
    type = "SystemAssigned"
  }

  priority        = var.enable_spot_instances ? "Spot" : "Regular"
  eviction_policy = var.enable_spot_instances ? var.spot_eviction_policy : null
  max_bid_price   = var.enable_spot_instances ? var.spot_max_bid_price : null

  custom_data = var.custom_data

  tags = var.tags
}

resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  count               = var.enable_autoscaling ? 1 : 0
  name                = "${var.vmss_name}-autoscale"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  target_resource_id  = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].id : azurerm_windows_virtual_machine_scale_set.vmss[0].id

  profile {
    name = "AutoScale"

    capacity {
      default = var.autoscale_default
      minimum = var.autoscale_min
      maximum = var.autoscale_max
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].id : azurerm_windows_virtual_machine_scale_set.vmss[0].id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.cpu_scale_out_threshold
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss[0].id : azurerm_windows_virtual_machine_scale_set.vmss[0].id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.cpu_scale_in_threshold
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  tags = var.tags
}
