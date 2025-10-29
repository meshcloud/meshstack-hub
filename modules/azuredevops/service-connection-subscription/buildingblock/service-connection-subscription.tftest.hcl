variables {
  azure_devops_organization_url = "https://dev.azure.com/test-org"
  key_vault_name                = "test-kv"
  resource_group_name           = "test-rg"
  pat_secret_name               = "azdo-pat"
  project_id                    = "12345678-1234-1234-1234-123456789012"
  service_connection_name       = "test-service-connection"
  azure_subscription_id         = "11111111-2222-3333-4444-555555555555"
  service_principal_id          = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_principal_key         = "test-secret-value"
  azure_tenant_id               = "87654321-4321-4321-4321-210987654321"
}

run "valid_service_connection_basic" {
  command = plan

  variables {
    service_connection_name = "valid-service-connection"
    authorize_all_pipelines = false
  }
}

run "valid_service_connection_with_auto_authorize" {
  command = plan

  variables {
    service_connection_name = "auto-auth-connection"
    authorize_all_pipelines = true
  }
}

run "valid_service_connection_with_description" {
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

run "service_connection_with_custom_description" {
  command = plan

  variables {
    service_connection_name = "custom-desc-connection"
    description             = "Custom service connection for staging environment"
  }
}

