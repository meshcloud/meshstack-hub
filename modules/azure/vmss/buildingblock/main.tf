data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "spoke_vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

data "azurerm_subnet" "vmss_subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

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

resource "azurerm_network_security_group" "vmss_nsg" {
  name                = "${var.vmss_name}-nsg"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name

  tags = var.tags
}

resource "azurerm_network_security_rule" "allow_ssh" {
  lifecycle {
    enabled = var.os_type == "Linux" && var.enable_ssh_access
  }

  name                        = "AllowSSH"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vmss_rg.name
  network_security_group_name = azurerm_network_security_group.vmss_nsg.name
}

resource "azurerm_network_security_rule" "allow_rdp" {
  lifecycle {
    enabled = var.os_type == "Windows" && var.enable_rdp_access
  }

  name                        = "AllowRDP"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vmss_rg.name
  network_security_group_name = azurerm_network_security_group.vmss_nsg.name
}

resource "azurerm_network_security_rule" "allow_backend_port" {
  lifecycle {
    enabled = var.enable_load_balancer
  }

  name                        = "AllowBackendPort"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.backend_port
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vmss_rg.name
  network_security_group_name = azurerm_network_security_group.vmss_nsg.name
}

resource "azurerm_subnet_network_security_group_association" "vmss_nsg_association" {
  subnet_id                 = data.azurerm_subnet.vmss_subnet.id
  network_security_group_id = azurerm_network_security_group.vmss_nsg.id
}

resource "azurerm_public_ip" "lb_public_ip" {
  lifecycle {
    enabled = var.enable_load_balancer && var.enable_public_ip
  }

  name                = "${var.vmss_name}-lb-pip"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  allocation_method   = "Static"
  sku                 = var.load_balancer_sku

  tags = var.tags
}

resource "azurerm_lb" "vmss_lb" {
  lifecycle {
    enabled = var.enable_load_balancer
  }

  name                = "${var.vmss_name}-lb"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  sku                 = var.load_balancer_sku

  frontend_ip_configuration {
    name                          = "PublicIPAddress"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.lb_public_ip.id : null
    subnet_id                     = var.enable_public_ip ? null : data.azurerm_subnet.vmss_subnet.id
    private_ip_address_allocation = var.enable_public_ip ? null : "Dynamic"
  }

  tags = var.tags
}

resource "azurerm_lb_backend_address_pool" "vmss_backend_pool" {
  lifecycle {
    enabled = var.enable_load_balancer
  }

  loadbalancer_id = azurerm_lb.vmss_lb.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss_health_probe" {
  lifecycle {
    enabled = var.enable_load_balancer
  }

  loadbalancer_id     = azurerm_lb.vmss_lb.id
  name                = "health-probe"
  protocol            = var.health_probe_protocol
  port                = var.health_probe_port
  request_path        = var.health_probe_protocol != "Tcp" ? var.health_probe_request_path : null
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "vmss_lb_rule" {
  lifecycle {
    enabled = var.enable_load_balancer
  }

  loadbalancer_id                = azurerm_lb.vmss_lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = var.frontend_port
  backend_port                   = var.backend_port
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.vmss_backend_pool.id]
  probe_id                       = azurerm_lb_probe.vmss_health_probe.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  lifecycle {
    enabled = var.os_type == "Linux"
  }

  name                = var.vmss_name
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  sku                 = var.sku
  instances           = var.enable_autoscaling ? null : var.instances
  admin_username      = var.admin_username
  custom_data         = var.custom_data != null ? base64encode(var.custom_data) : null

  upgrade_mode                = var.upgrade_mode
  overprovision               = var.overprovision
  single_placement_group      = var.single_placement_group
  zones                       = var.zones
  zone_balance                = length(var.zones) > 0 ? true : false
  platform_fault_domain_count = var.single_placement_group ? 5 : 1
  priority                    = var.enable_spot_instances ? "Spot" : "Regular"
  eviction_policy             = var.enable_spot_instances ? var.spot_eviction_policy : null
  max_bid_price               = var.enable_spot_instances ? var.spot_max_bid_price : null

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
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = data.azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = var.enable_load_balancer ? [azurerm_lb_backend_address_pool.vmss_backend_pool.id] : []
    }
  }

  identity {
    type = "SystemAssigned"
  }

  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = null
    }
  }

  dynamic "automatic_instance_repair" {
    for_each = var.upgrade_mode == "Automatic" || var.upgrade_mode == "Rolling" ? [1] : []
    content {
      enabled      = true
      grace_period = "PT30M"
    }
  }

  dynamic "rolling_upgrade_policy" {
    for_each = var.upgrade_mode == "Rolling" ? [1] : []
    content {
      max_batch_instance_percent              = 20
      max_unhealthy_instance_percent          = 20
      max_unhealthy_upgraded_instance_percent = 20
      pause_time_between_batches              = "PT2M"
    }
  }

  health_probe_id = var.upgrade_mode == "Automatic" || var.upgrade_mode == "Rolling" ? azurerm_lb_probe.vmss_health_probe.id : null

  disable_password_authentication = true

  tags = var.tags
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  lifecycle {
    enabled = var.os_type == "Windows"
  }

  name                = var.vmss_name
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  sku                 = var.sku
  instances           = var.enable_autoscaling ? null : var.instances
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  custom_data         = var.custom_data != null ? base64encode(var.custom_data) : null

  upgrade_mode                = var.upgrade_mode
  overprovision               = var.overprovision
  single_placement_group      = var.single_placement_group
  zones                       = var.zones
  zone_balance                = length(var.zones) > 0 ? true : false
  platform_fault_domain_count = var.enable_spot_instances ? 1 : (var.single_placement_group ? 5 : 1)
  priority                    = var.enable_spot_instances ? "Spot" : "Regular"
  eviction_policy             = var.enable_spot_instances ? var.spot_eviction_policy : null
  max_bid_price               = var.enable_spot_instances ? var.spot_max_bid_price : null

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
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = data.azurerm_subnet.vmss_subnet.id
      load_balancer_backend_address_pool_ids = var.enable_load_balancer ? [azurerm_lb_backend_address_pool.vmss_backend_pool.id] : []
    }
  }

  identity {
    type = "SystemAssigned"
  }

  dynamic "boot_diagnostics" {
    for_each = var.enable_boot_diagnostics ? [1] : []
    content {
      storage_account_uri = null
    }
  }

  dynamic "automatic_instance_repair" {
    for_each = var.upgrade_mode == "Automatic" || var.upgrade_mode == "Rolling" ? [1] : []
    content {
      enabled      = true
      grace_period = "PT30M"
    }
  }

  dynamic "rolling_upgrade_policy" {
    for_each = var.upgrade_mode == "Rolling" ? [1] : []
    content {
      max_batch_instance_percent              = 20
      max_unhealthy_instance_percent          = 20
      max_unhealthy_upgraded_instance_percent = 20
      pause_time_between_batches              = "PT2M"
    }
  }

  health_probe_id = var.upgrade_mode == "Automatic" || var.upgrade_mode == "Rolling" ? azurerm_lb_probe.vmss_health_probe.id : null

  tags = var.tags
}

resource "azurerm_monitor_autoscale_setting" "vmss_autoscale" {
  lifecycle {
    enabled = var.enable_autoscaling
  }

  name                = "${var.vmss_name}-autoscale"
  location            = azurerm_resource_group.vmss_rg.location
  resource_group_name = azurerm_resource_group.vmss_rg.name
  target_resource_id  = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss.id : azurerm_windows_virtual_machine_scale_set.vmss.id

  profile {
    name = "defaultProfile"

    capacity {
      default = var.instances
      minimum = var.min_instances
      maximum = var.max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss.id : azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.scale_out_cpu_threshold
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
        metric_resource_id = var.os_type == "Linux" ? azurerm_linux_virtual_machine_scale_set.vmss.id : azurerm_windows_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.scale_in_cpu_threshold
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
