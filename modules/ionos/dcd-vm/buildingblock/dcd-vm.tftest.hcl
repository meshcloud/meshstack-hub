run "valid_small_template" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-small-vm"
    template             = "small"
    create_network_interface = true
    public_ip_required   = true
  }

  assert {
    condition     = ionoscloud_server.main.cores == 2
    error_message = "Small template should have 2 CPU cores"
  }

  assert {
    condition     = ionoscloud_server.main.ram == 4096
    error_message = "Small template should have 4096 MB RAM"
  }
}

run "valid_medium_template" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-medium-vm"
    template             = "medium"
    create_network_interface = true
    public_ip_required   = true
  }

  assert {
    condition     = ionoscloud_server.main.cores == 4
    error_message = "Medium template should have 4 CPU cores"
  }

  assert {
    condition     = ionoscloud_server.main.ram == 8192
    error_message = "Medium template should have 8192 MB RAM"
  }
}

run "valid_large_template" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-large-vm"
    template             = "large"
    create_network_interface = true
    public_ip_required   = true
  }

  assert {
    condition     = ionoscloud_server.main.cores == 8
    error_message = "Large template should have 8 CPU cores"
  }

  assert {
    condition     = ionoscloud_server.main.ram == 16384
    error_message = "Large template should have 16384 MB RAM"
  }
}

run "valid_custom_template" {
  command = apply

  variables {
    datacenter_id  = "test-dc-123"
    vm_name       = "test-custom-vm"
    template      = "custom"
    vm_specs = {
      cpu_cores    = 4
      memory_mb    = 8192
      storage_gb   = 100
      storage_type = "SSD"
      os_image     = "ubuntu-22.04"
    }
    create_network_interface = true
    public_ip_required   = true
  }

  assert {
    condition     = ionoscloud_server.main.cores == 4
    error_message = "Custom template should respect vm_specs cpu_cores"
  }

  assert {
    condition     = ionoscloud_server.main.ram == 8192
    error_message = "Custom template should respect vm_specs memory_mb"
  }
}

run "valid_with_data_disks" {
  command = apply

  variables {
    datacenter_id  = "test-dc-123"
    vm_name       = "test-with-disks"
    template      = "medium"
    additional_data_disks = [
      {
        name     = "data-1"
        size_gb  = 100
        storage_type = "SSD"
      },
      {
        name     = "data-2"
        size_gb  = 500
        storage_type = "SSD"
      }
    ]
    create_network_interface = true
    public_ip_required   = true
  }

  assert {
    condition     = length(ionoscloud_volume.data) == 2
    error_message = "Should have 2 data volumes attached"
  }
}

run "valid_without_public_ip" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-private-vm"
    template             = "medium"
    create_network_interface = true
    public_ip_required   = false
  }

  assert {
    condition     = ionoscloud_server.main.name == "test-private-vm"
    error_message = "VM should be created without public IP"
  }
}

run "valid_with_existing_network" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-existing-network"
    template             = "small"
    create_network_interface = true
    network_id           = "existing-lan-123"
    public_ip_required   = false
  }

  assert {
    condition     = ionoscloud_server.main.name == "test-existing-network"
    error_message = "VM should attach to existing network"
  }
}

run "invalid_template_name" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-invalid-template"
    template             = "invalid-template"
    create_network_interface = true
    public_ip_required   = true
  }

  expect_failure = true
}

run "invalid_vm_name_empty" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = ""
    template             = "small"
    create_network_interface = true
    public_ip_required   = true
  }

  expect_failure = true
}

run "invalid_vm_name_too_long" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "this-is-a-very-very-very-very-very-very-very-very-long-vm-name-that-exceeds-63-characters"
    template             = "small"
    create_network_interface = true
    public_ip_required   = true
  }

  expect_failure = true
}

run "invalid_custom_specs_cpu_zero" {
  command = apply

  variables {
    datacenter_id  = "test-dc-123"
    vm_name       = "test-invalid-cpu"
    template      = "custom"
    vm_specs = {
      cpu_cores    = 0
      memory_mb    = 8192
      storage_gb   = 100
      storage_type = "SSD"
      os_image     = "ubuntu-22.04"
    }
    create_network_interface = true
    public_ip_required   = true
  }

  expect_failure = true
}

run "invalid_custom_specs_memory_zero" {
  command = apply

  variables {
    datacenter_id  = "test-dc-123"
    vm_name       = "test-invalid-memory"
    template      = "custom"
    vm_specs = {
      cpu_cores    = 4
      memory_mb    = 0
      storage_gb   = 100
      storage_type = "SSD"
      os_image     = "ubuntu-22.04"
    }
    create_network_interface = true
    public_ip_required   = true
  }

  expect_failure = true
}

run "invalid_custom_specs_storage_zero" {
  command = apply

  variables {
    datacenter_id  = "test-dc-123"
    vm_name       = "test-invalid-storage"
    template      = "custom"
    vm_specs = {
      cpu_cores    = 4
      memory_mb    = 8192
      storage_gb   = 0
      storage_type = "SSD"
      os_image     = "ubuntu-22.04"
    }
    create_network_interface = true
    public_ip_required   = true
  }

  expect_failure = true
}

run "invalid_custom_specs_cpu_too_high" {
  command = apply

  variables {
    datacenter_id  = "test-dc-123"
    vm_name       = "test-cpu-too-high"
    template      = "custom"
    vm_specs = {
      cpu_cores    = 200
      memory_mb    = 8192
      storage_gb   = 100
      storage_type = "SSD"
      os_image     = "ubuntu-22.04"
    }
    create_network_interface = true
    public_ip_required   = true
  }

  expect_failure = true
}

run "invalid_no_network_interface_no_network_id" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-no-network"
    template             = "small"
    create_network_interface = false
    network_id           = null
    public_ip_required   = true
  }

  expect_failure = true
}

run "valid_multiple_data_disks" {
  command = apply

  variables {
    datacenter_id  = "test-dc-123"
    vm_name       = "test-many-disks"
    template      = "large"
    additional_data_disks = [
      {
        name     = "disk-1"
        size_gb  = 100
      },
      {
        name     = "disk-2"
        size_gb  = 200
      },
      {
        name     = "disk-3"
        size_gb  = 500
      }
    ]
    create_network_interface = true
    public_ip_required   = true
  }

  assert {
    condition     = length(ionoscloud_volume.data) == 3
    error_message = "Should have 3 data volumes"
  }
}

run "valid_outputs_available" {
  command = apply

  variables {
    datacenter_id         = "test-dc-123"
    vm_name              = "test-outputs"
    template             = "medium"
    create_network_interface = true
    public_ip_required   = true
  }

  assert {
    condition     = output.server_id != ""
    error_message = "server_id output should not be empty"
  }

  assert {
    condition     = output.server_name != ""
    error_message = "server_name output should not be empty"
  }

  assert {
    condition     = output.boot_volume_id != ""
    error_message = "boot_volume_id output should not be empty"
  }
}
