variables {
  vmss_name                = "hcl-test-vmss"
  resource_group_name      = "hcl-test-vmss-rg"
  location                 = "germanywestcentral"
  vnet_name                = "spoke-vnet"
  vnet_resource_group_name = "rg-vmss-test"
  subnet_name              = "default"
  ssh_public_key           = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMj8wxyAbcTkUt60GnyDKE5i5e6dXZQJMVgdg4F5KzzA testkey"
}

run "valid_linux_vmss" {
  variables {
    vmss_name = "linux-vmss"
    os_type   = "Linux"
    sku       = "Standard_B2s"
    instances = 2
  }

  assert {
    condition     = azurerm_resource_group.vmss_rg.name == "test-vmss-rg"
    error_message = "Resource group name should match input"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].name == "linux-vmss"
    error_message = "VMSS name should match input"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].instances == 2
    error_message = "Instance count should be 2"
  }
}

run "windows_vmss" {
  variables {
    vmss_name       = "win-vmss"
    os_type         = "Windows"
    sku             = "Standard_B2s"
    instances       = 3
    admin_password  = "P@ssw0rd1234!"
    image_publisher = "MicrosoftWindowsServer"
    image_offer     = "WindowsServer"
    image_sku       = "2022-Datacenter"
    os_disk_size_gb = 128
  }

  assert {
    condition     = azurerm_windows_virtual_machine_scale_set.vmss[0].name == "win-vmss"
    error_message = "Windows VMSS name should match input"
  }

  assert {
    condition     = azurerm_windows_virtual_machine_scale_set.vmss[0].instances == 3
    error_message = "Windows instance count should be 3"
  }
}

run "vmss_with_autoscaling" {
  variables {
    vmss_name               = "autoscale-vmss"
    instances               = 2
    enable_autoscaling      = true
    min_instances           = 2
    max_instances           = 10
    scale_out_cpu_threshold = 80
    scale_in_cpu_threshold  = 20
  }

  assert {
    condition     = length(azurerm_monitor_autoscale_setting.vmss_autoscale) == 1
    error_message = "Autoscale setting should be created when enabled"
  }

  assert {
    condition     = azurerm_monitor_autoscale_setting.vmss_autoscale[0].profile[0].capacity[0].minimum == 2
    error_message = "Min instances should be 2"
  }

  assert {
    condition     = azurerm_monitor_autoscale_setting.vmss_autoscale[0].profile[0].capacity[0].maximum == 10
    error_message = "Max instances should be 10"
  }
}

run "vmss_without_autoscaling" {
  variables {
    vmss_name          = "no-autoscale-vmss"
    instances          = 3
    enable_autoscaling = false
  }

  assert {
    condition     = length(azurerm_monitor_autoscale_setting.vmss_autoscale) == 0
    error_message = "Autoscale setting should not be created when disabled"
  }
}

run "vmss_with_load_balancer" {
  variables {
    vmss_name            = "lb-vmss"
    enable_load_balancer = true
    enable_public_ip     = true
    frontend_port        = 80
    backend_port         = 8080
  }

  assert {
    condition     = length(azurerm_lb.vmss_lb) == 1
    error_message = "Load balancer should be created when enabled"
  }

  assert {
    condition     = length(azurerm_public_ip.lb_public_ip) == 1
    error_message = "Public IP should be created when enabled"
  }

  assert {
    condition     = azurerm_lb_rule.vmss_lb_rule[0].frontend_port == 80
    error_message = "Frontend port should be 80"
  }

  assert {
    condition     = azurerm_lb_rule.vmss_lb_rule[0].backend_port == 8080
    error_message = "Backend port should be 8080"
  }
}

run "vmss_without_load_balancer" {
  variables {
    vmss_name            = "no-lb-vmss"
    enable_load_balancer = false
  }

  assert {
    condition     = length(azurerm_lb.vmss_lb) == 0
    error_message = "Load balancer should not be created when disabled"
  }
}

run "vmss_with_availability_zones" {
  variables {
    vmss_name = "zone-vmss"
    zones     = ["1", "2", "3"]
  }

  assert {
    condition     = length(azurerm_linux_virtual_machine_scale_set.vmss[0].zones) == 3
    error_message = "VMSS should be deployed across 3 zones"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].zone_balance == true
    error_message = "Zone balancing should be enabled"
  }
}

run "vmss_with_spot_instances" {
  variables {
    vmss_name             = "spot-vmss"
    enable_spot_instances = true
    spot_eviction_policy  = "Deallocate"
    spot_max_bid_price    = -1
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].priority == "Spot"
    error_message = "VMSS should use Spot priority"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].eviction_policy == "Deallocate"
    error_message = "Eviction policy should be Deallocate"
  }
}

run "vmss_with_rolling_upgrade" {
  variables {
    vmss_name                 = "rolling-vmss"
    upgrade_mode              = "Rolling"
    enable_load_balancer      = true
    health_probe_protocol     = "Http"
    health_probe_port         = 80
    health_probe_request_path = "/health"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].upgrade_mode == "Rolling"
    error_message = "Upgrade mode should be Rolling"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].health_probe_id != null
    error_message = "Health probe should be configured for Rolling upgrade"
  }
}

run "invalid_vmss_name" {
  variables {
    vmss_name = "INVALID_NAME_123"
  }

  expect_failures = [
    var.vmss_name
  ]
}

run "invalid_instances_too_high" {
  variables {
    vmss_name = "test-vmss"
    instances = 1001
  }

  expect_failures = [
    var.instances
  ]
}

run "invalid_os_type" {
  variables {
    vmss_name = "test-vmss"
    os_type   = "MacOS"
  }

  expect_failures = [
    var.os_type
  ]
}

run "vmss_with_custom_data" {
  variables {
    vmss_name   = "custom-data-vmss"
    custom_data = "#!/bin/bash\napt-get update\napt-get install -y nginx"
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.vmss[0].custom_data != null
    error_message = "Custom data should be set"
  }
}

run "vmss_with_ssh_access" {
  command = plan

  variables {
    vmss_name         = "ssh-vmss"
    os_type           = "Linux"
    enable_ssh_access = true
  }

  assert {
    condition     = length(azurerm_network_security_rule.allow_ssh) == 1
    error_message = "SSH rule should be created when enabled"
  }

  assert {
    condition     = azurerm_network_security_rule.allow_ssh[0].destination_port_range == "22"
    error_message = "SSH rule should allow port 22"
  }
}

run "vmss_with_rdp_access" {
  variables {
    vmss_name         = "rdp-vmss"
    os_type           = "Windows"
    admin_password    = "P@ssw0rd1234!"
    enable_rdp_access = true
    image_publisher   = "MicrosoftWindowsServer"
    image_offer       = "WindowsServer"
    image_sku         = "2022-Datacenter"
    os_disk_size_gb   = 127
  }

  assert {
    condition     = length(azurerm_network_security_rule.allow_rdp) == 1
    error_message = "RDP rule should be created when enabled"
  }

  assert {
    condition     = azurerm_network_security_rule.allow_rdp[0].destination_port_range == "3389"
    error_message = "RDP rule should allow port 3389"
  }
}
