run "valid_linux_vmss_configuration" {
  command = plan

  variables {
    vmss_name           = "test-linux-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.0.0.0/16"
    subnet_address_prefix = "10.0.1.0/24"

    tags = {
      Environment = "Test"
      OS          = "Linux"
    }
  }
}

run "valid_windows_vmss_configuration" {
  command = plan

  variables {
    vmss_name           = "test-windows-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Windows"
    admin_username = "testadmin"
    admin_password = "ComplexP@ssw0rd123!"

    image_publisher = "MicrosoftWindowsServer"
    image_offer     = "WindowsServer"
    image_sku       = "2022-Datacenter"
    image_version   = "latest"

    vnet_address_space    = "10.1.0.0/16"
    subnet_address_prefix = "10.1.1.0/24"

    tags = {
      Environment = "Test"
      OS          = "Windows"
    }
  }
}

run "vmss_with_autoscaling" {
  command = plan

  variables {
    vmss_name           = "test-autoscale-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.2.0.0/16"
    subnet_address_prefix = "10.2.1.0/24"

    enable_autoscaling      = true
    autoscale_min           = 2
    autoscale_max           = 10
    autoscale_default       = 3
    cpu_scale_out_threshold = 75
    cpu_scale_in_threshold  = 25

    tags = {
      Environment = "Test"
      Feature     = "Autoscaling"
    }
  }
}

run "vmss_with_load_balancer_public" {
  command = plan

  variables {
    vmss_name           = "test-lb-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 3

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.3.0.0/16"
    subnet_address_prefix = "10.3.1.0/24"

    enable_load_balancer  = true
    enable_public_ip      = true
    health_probe_protocol = "Http"
    health_probe_port     = 80
    health_probe_path     = "/health"

    lb_rules = [
      {
        name          = "http"
        protocol      = "Tcp"
        frontend_port = 80
        backend_port  = 80
      },
      {
        name          = "https"
        protocol      = "Tcp"
        frontend_port = 443
        backend_port  = 443
      }
    ]

    tags = {
      Environment = "Test"
      Feature     = "LoadBalancer"
    }
  }
}

run "vmss_with_load_balancer_private" {
  command = plan

  variables {
    vmss_name           = "test-lb-private-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.4.0.0/16"
    subnet_address_prefix = "10.4.1.0/24"

    enable_load_balancer  = true
    enable_public_ip      = false
    health_probe_protocol = "Tcp"
    health_probe_port     = 8080

    lb_rules = [
      {
        name          = "app"
        protocol      = "Tcp"
        frontend_port = 8080
        backend_port  = 8080
      }
    ]

    tags = {
      Environment = "Test"
      Feature     = "PrivateLoadBalancer"
    }
  }
}

run "vmss_with_spot_instances" {
  command = plan

  variables {
    vmss_name           = "test-spot-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.5.0.0/16"
    subnet_address_prefix = "10.5.1.0/24"

    enable_spot_instances = true
    spot_max_bid_price    = -1
    spot_eviction_policy  = "Deallocate"

    enable_autoscaling = true
    autoscale_min      = 0
    autoscale_max      = 20
    autoscale_default  = 2

    tags = {
      Environment = "Test"
      Feature     = "SpotInstances"
    }
  }
}

run "vmss_multi_zone_deployment" {
  command = plan

  variables {
    vmss_name           = "test-multizone-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.6.0.0/16"
    subnet_address_prefix = "10.6.1.0/24"

    zones        = ["1", "2", "3"]
    upgrade_mode = "Rolling"

    enable_autoscaling = true
    autoscale_min      = 3
    autoscale_max      = 15
    autoscale_default  = 6

    tags = {
      Environment = "Test"
      Feature     = "MultiZone"
    }
  }
}

run "vmss_with_custom_data" {
  command = plan

  variables {
    vmss_name           = "test-customdata-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.7.0.0/16"
    subnet_address_prefix = "10.7.1.0/24"

    custom_data = base64encode(<<-EOT
      #!/bin/bash
      apt-get update
      apt-get install -y nginx
      systemctl start nginx
    EOT
    )

    tags = {
      Environment = "Test"
      Feature     = "CustomData"
    }
  }
}

run "invalid_os_type" {
  command = plan

  variables {
    vmss_name           = "test-invalid-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "MacOS"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.8.0.0/16"
    subnet_address_prefix = "10.8.1.0/24"
  }

  expect_failures = [
    var.os_type,
  ]
}

run "invalid_upgrade_mode" {
  command = plan

  variables {
    vmss_name           = "test-invalid-upgrade-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.9.0.0/16"
    subnet_address_prefix = "10.9.1.0/24"

    upgrade_mode = "InvalidMode"
  }

  expect_failures = [
    var.upgrade_mode,
  ]
}

run "invalid_autoscale_min_greater_than_max" {
  command = plan

  variables {
    vmss_name           = "test-invalid-autoscale-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.10.0.0/16"
    subnet_address_prefix = "10.10.1.0/24"

    enable_autoscaling = true
    autoscale_min      = 10
    autoscale_max      = 5
    autoscale_default  = 7
  }

  expect_failures = [
    var.autoscale_min,
    var.autoscale_max,
  ]
}

run "invalid_health_probe_protocol" {
  command = plan

  variables {
    vmss_name           = "test-invalid-probe-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Linux"
    admin_username = "testadmin"
    ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7laRyN4B3YZmVrDEZLZo..."

    vnet_address_space    = "10.11.0.0/16"
    subnet_address_prefix = "10.11.1.0/24"

    enable_load_balancer  = true
    health_probe_protocol = "Https"
  }

  expect_failures = [
    var.health_probe_protocol,
  ]
}

run "linux_missing_ssh_key" {
  command = plan

  variables {
    vmss_name           = "test-nossh-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Linux"
    admin_username = "testadmin"

    vnet_address_space    = "10.12.0.0/16"
    subnet_address_prefix = "10.12.1.0/24"
  }

  expect_failures = [
    var.ssh_public_key,
  ]
}

run "windows_missing_password" {
  command = plan

  variables {
    vmss_name           = "test-nopassword-vmss"
    resource_group_name = "rg-test"
    location            = "West Europe"
    sku                 = "Standard_D2s_v3"
    instances           = 2

    os_type        = "Windows"
    admin_username = "testadmin"

    image_publisher = "MicrosoftWindowsServer"
    image_offer     = "WindowsServer"
    image_sku       = "2022-Datacenter"
    image_version   = "latest"

    vnet_address_space    = "10.13.0.0/16"
    subnet_address_prefix = "10.13.1.0/24"
  }

  expect_failures = [
    var.admin_password,
  ]
}
