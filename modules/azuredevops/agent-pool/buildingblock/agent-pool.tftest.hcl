run "valid_agent_pool_configuration" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/test-org"
    key_vault_name                = "kv-test-devops"
    resource_group_name           = "rg-test-devops"
    agent_pool_name               = "test-elastic-pool"
    vmss_name                     = "vmss-test-agents"
    vmss_resource_group_name      = "rg-test-vmss"
    service_endpoint_id           = "12345678-1234-1234-1234-123456789012"
    service_endpoint_scope        = "project-12345"
    max_capacity                  = 10
    desired_idle                  = 2
  }

  assert {
    condition     = azuredevops_elastic_pool.main.name == "test-elastic-pool"
    error_message = "Agent pool name should be 'test-elastic-pool'"
  }

  assert {
    condition     = azuredevops_elastic_pool.main.max_capacity == 10
    error_message = "Max capacity should be 10"
  }
}

run "minimal_configuration" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/test-org"
    key_vault_name                = "kv-test-devops"
    resource_group_name           = "rg-test-devops"
    agent_pool_name               = "minimal-pool"
    vmss_name                     = "vmss-minimal"
    vmss_resource_group_name      = "rg-minimal-vmss"
    service_endpoint_id           = "12345678-1234-1234-1234-123456789012"
    service_endpoint_scope        = "project-12345"
  }

  assert {
    condition     = azuredevops_elastic_pool.main.max_capacity == 10
    error_message = "Max capacity should default to 10"
  }

  assert {
    condition     = azuredevops_elastic_pool.main.desired_idle == 1
    error_message = "Desired idle should default to 1"
  }
}

run "high_capacity_pool" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/test-org"
    key_vault_name                = "kv-test-devops"
    resource_group_name           = "rg-test-devops"
    agent_pool_name               = "high-capacity-pool"
    vmss_name                     = "vmss-high-capacity"
    vmss_resource_group_name      = "rg-high-capacity-vmss"
    service_endpoint_id           = "12345678-1234-1234-1234-123456789012"
    service_endpoint_scope        = "project-12345"
    max_capacity                  = 50
    desired_idle                  = 10
    recycle_after_each_use        = true
  }

  assert {
    condition     = azuredevops_elastic_pool.main.max_capacity == 50
    error_message = "Max capacity should be 50"
  }

  assert {
    condition     = azuredevops_elastic_pool.main.recycle_after_each_use == true
    error_message = "Recycle after each use should be enabled"
  }
}

run "with_project_authorization" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/test-org"
    key_vault_name                = "kv-test-devops"
    resource_group_name           = "rg-test-devops"
    agent_pool_name               = "project-pool"
    vmss_name                     = "vmss-project"
    vmss_resource_group_name      = "rg-project-vmss"
    service_endpoint_id           = "12345678-1234-1234-1234-123456789012"
    service_endpoint_scope        = "project-12345"
    project_id                    = "test-project-id"
  }

  assert {
    condition     = azuredevops_agent_queue.main[0].project_id == "test-project-id"
    error_message = "Agent queue should be created for the project"
  }
}

run "invalid_pool_name_too_long" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/test-org"
    key_vault_name                = "kv-test-devops"
    resource_group_name           = "rg-test-devops"
    agent_pool_name               = "this-is-a-very-long-pool-name-that-exceeds-the-maximum-allowed-length-of-64-characters"
    vmss_name                     = "vmss-test"
    vmss_resource_group_name      = "rg-test-vmss"
    service_endpoint_id           = "12345678-1234-1234-1234-123456789012"
    service_endpoint_scope        = "project-12345"
  }

  expect_failures = [
    var.agent_pool_name
  ]
}

run "invalid_max_capacity" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/test-org"
    key_vault_name                = "kv-test-devops"
    resource_group_name           = "rg-test-devops"
    agent_pool_name               = "test-pool"
    vmss_name                     = "vmss-test"
    vmss_resource_group_name      = "rg-test-vmss"
    service_endpoint_id           = "12345678-1234-1234-1234-123456789012"
    service_endpoint_scope        = "project-12345"
    max_capacity                  = 0
  }

  expect_failures = [
    var.max_capacity
  ]
}
