variables {
  azuredevops_org_url         = "https://dev.azure.com/test-org"
  azuredevops_project_id      = "12345678-1234-1234-1234-123456789012"
  azuredevops_pat             = "test-pat-token"
  service_endpoint_id         = "87654321-4321-4321-4321-210987654321"
  agent_pool_name             = "test-vmss-pool"
  vmss_name                   = "test-vmss-runners"
  azure_subscription_id       = "11111111-2222-3333-4444-555555555555"
  azure_resource_group_name   = "test-rg"
  azure_location              = "eastus"
  spoke_vnet_name             = "spoke-vnet"
  spoke_subnet_name           = "spoke-subnet"
  spoke_resource_group_name   = "spoke-rg"
  ssh_public_key              = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC test@example.com"
}

run "valid_vmss_runner_minimal" {
  command = plan

  variables {
    agent_pool_name = "minimal-vmss-pool"
    vmss_name       = "minimal-vmss"
  }
}

run "valid_vmss_runner_with_custom_capacity" {
  command = plan

  variables {
    agent_pool_name      = "custom-capacity-pool"
    vmss_name            = "custom-capacity-vmss"
    desired_idle_agents  = 2
    max_capacity         = 20
  }
}

run "valid_vmss_runner_with_recycle" {
  command = plan

  variables {
    agent_pool_name        = "recycle-pool"
    vmss_name              = "recycle-vmss"
    recycle_after_each_use = true
    time_to_live_minutes   = 15
  }
}

run "valid_vmss_runner_with_premium_storage" {
  command = plan

  variables {
    agent_pool_name = "premium-storage-pool"
    vmss_name       = "premium-storage-vmss"
    vm_sku          = "Standard_D4s_v3"
    os_disk_type    = "Premium_LRS"
  }
}

run "valid_vmss_runner_with_standard_storage" {
  command = plan

  variables {
    agent_pool_name = "standard-storage-pool"
    vmss_name       = "standard-storage-vmss"
    os_disk_type    = "Standard_LRS"
  }
}

run "valid_vmss_runner_with_custom_image" {
  command = plan

  variables {
    agent_pool_name = "custom-image-pool"
    vmss_name       = "custom-image-vmss"
    image_publisher = "Canonical"
    image_offer     = "0001-com-ubuntu-server-focal"
    image_sku       = "20_04-lts-gen2"
    image_version   = "latest"
  }
}

run "valid_vmss_runner_with_tags" {
  command = plan

  variables {
    agent_pool_name = "tagged-pool"
    vmss_name       = "tagged-vmss"
    tags = {
      environment = "production"
      team        = "devops"
      cost_center = "engineering"
    }
  }
}

run "invalid_os_disk_type" {
  command = plan

  variables {
    agent_pool_name = "invalid-disk-pool"
    vmss_name       = "invalid-disk-vmss"
    os_disk_type    = "InvalidDiskType"
  }

  expect_failures = [
    var.os_disk_type,
  ]
}

run "invalid_desired_idle_greater_than_max" {
  command = plan

  variables {
    agent_pool_name     = "invalid-capacity-pool"
    vmss_name           = "invalid-capacity-vmss"
    desired_idle_agents = 15
    max_capacity        = 10
  }

  expect_failures = [
    var.desired_idle_agents,
  ]
}

run "invalid_max_capacity_zero" {
  command = plan

  variables {
    agent_pool_name = "zero-capacity-pool"
    vmss_name       = "zero-capacity-vmss"
    max_capacity    = 0
  }

  expect_failures = [
    var.max_capacity,
  ]
}

run "valid_vmss_runner_high_capacity" {
  command = plan

  variables {
    agent_pool_name     = "high-capacity-pool"
    vmss_name           = "high-capacity-vmss"
    desired_idle_agents = 5
    max_capacity        = 50
    vm_sku              = "Standard_D8s_v3"
  }
}

run "valid_vmss_runner_zero_idle" {
  command = plan

  variables {
    agent_pool_name     = "zero-idle-pool"
    vmss_name           = "zero-idle-vmss"
    desired_idle_agents = 0
    max_capacity        = 10
  }
}
