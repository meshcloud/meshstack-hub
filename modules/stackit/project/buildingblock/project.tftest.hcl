# terraform test is cool because it does the apply and destroy lifecycle
# what it doesn't test though is the backend storage. if we want to test that, we need to that via terragrunt

run "verify" {
  variables {
    parent_container_id = "organization-test123"
    project_name        = "test-project"
    service_account_email = "test-sa@sa.stackit.cloud"
    labels = {
      environment = "test"
      team        = "platform"
    }
    users = [
      {
        meshIdentifier = "identifier0"
        username       = "admin-user"
        firstName      = "Admin"
        lastName       = "User"
        email          = "admin@stackit.cloud"
        euid           = "admin@stackit.cloud"
        roles          = ["admin"]
      },
      {
        meshIdentifier = "identifier1"
        username       = "regular-user"
        firstName      = "Regular"
        lastName       = "User"
        email          = "user@stackit.cloud"
        euid           = "user@stackit.cloud"
        roles          = ["user"]
      },
      {
        meshIdentifier = "identifier2"
        username       = "reader-user"
        firstName      = "Reader"
        lastName       = "User"
        email          = "reader@stackit.cloud"
        euid           = "reader@stackit.cloud"
        roles          = ["reader"]
      }
    ]
  }
}

run "verify_minimal" {
  variables {
    parent_container_id = "organization-test123"
    project_name        = "minimal-project"
    service_account_email = "minimal-sa@sa.stackit.cloud"
  }
}

run "verify_environment_based" {
  variables {
    parent_container_id = "organization-default"
    project_name        = "env-based-project"
    service_account_email = "env-sa@sa.stackit.cloud"
    environment         = "production"
    parent_container_ids = {
      production  = "organization-prod-123"
      staging     = "organization-staging-456"
      development = "organization-dev-789"
    }
  }
}