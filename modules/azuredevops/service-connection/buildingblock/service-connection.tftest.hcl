variables {
  azuredevops_org_service_url = "https://dev.azure.com/test-org"
  azuredevops_project_name    = "test-project"
  service_connection_name     = "test-service-connection"
  azure_subscription_id       = "12345678-1234-1234-1234-123456789012"
  azure_subscription_name     = "test-subscription"
  azure_tenant_id             = "87654321-4321-4321-4321-210987654321"
}

run "valid_service_connection_with_contributor" {
  command = plan

  variables {
    service_connection_name = "valid-service-connection"
    azure_role              = "Contributor"
    auto_authorize          = false
  }
}

run "valid_service_connection_with_reader" {
  command = plan

  variables {
    service_connection_name = "reader-service-connection"
    azure_role              = "Reader"
    auto_authorize          = true
  }
}

run "valid_service_connection_with_owner" {
  command = plan

  variables {
    service_connection_name = "owner-service-connection"
    azure_role              = "Owner"
    auto_authorize          = false
  }
}

run "valid_service_connection_with_auto_authorize" {
  command = plan

  variables {
    service_connection_name = "auto-auth-service-connection"
    auto_authorize          = true
  }
}

run "invalid_azure_role" {
  command = plan

  variables {
    service_connection_name = "invalid-role-connection"
    azure_role              = "InvalidRole"
  }

  expect_failures = [
    var.azure_role,
  ]
}

run "service_connection_with_description" {
  command = plan

  variables {
    service_connection_name = "documented-connection"
    description             = "Service connection for production deployments"
  }
}

run "minimal_required_variables" {
  command = plan

  variables {
    service_connection_name = "minimal-connection"
  }
}

run "service_connection_naming_collision" {
  command = plan

  variables {
    service_connection_name = "test-service-connection"
  }
}

run "valid_service_connection_with_custom_description" {
  command = plan

  variables {
    service_connection_name = "custom-desc-connection"
    description             = "Custom service connection for staging environment"
    azure_role              = "Reader"
  }
}

run "service_connection_with_all_options" {
  command = plan

  variables {
    service_connection_name = "full-options-connection"
    description             = "Fully configured service connection"
    azure_role              = "Contributor"
    auto_authorize          = true
  }
}
