variables {
  azure_devops_organization_url = "https://dev.azure.com/meshcloud-prod"
  key_vault_name                = "ado-demo"
  resource_group_name           = "rg-devops"
  pat_secret_name               = "ado-pat"
  project_id                    = "eece6ccc-c821-46a1-9214-80df6da9e13f"

  service_connection_name = "test-service-connection"
  azure_subscription_id   = "f808fff2-adda-415a-9b77-2833c041aacf"
  service_principal_id    = "53cc4637-18e2-44f6-8721-dfc08c030dde"
  application_id          = "53cc4637-18e2-44f6-8721-dfc08c030dde"
  azure_tenant_id         = "5f0e994b-6436-4f58-be96-4dc7bebff827"
}

run "valid_service_connection_basic" {

  variables {
    service_connection_name = "valid-service-connection"
    authorize_all_pipelines = false
  }
}

run "valid_service_connection_with_auto_authorize" {

  variables {
    service_connection_name = "auto-auth-connection"
    authorize_all_pipelines = true
  }
}

run "valid_service_connection_with_description" {

  variables {
    service_connection_name = "documented-connection"
    description             = "Service connection for production deployments"
  }
}

run "minimal_required_variables" {

  variables {
    service_connection_name = "minimal-connection"
  }
}

run "service_connection_with_custom_description" {

  variables {
    service_connection_name = "custom-desc-connection"
    description             = "Custom service connection for staging environment"
  }
}

