run "verify" {
  variables {
    parent_id     = "99f8ad5f-255e-46a5-a72d-f6d652c90525"
    globalaccount = "meshcloudgmbh"
    #workspace_identifier = "sapbtp"
    project_identifier = "testsubaccount"
    subfolder          = "test"
    users = [
      {
        meshIdentifier = "identifier1"
        username       = "testuser1@likvid.io"
        firstName      = "test"
        lastName       = "user"
        email          = "testuser1@likvid.io"
        euid           = "testuser1@likvid.io"
        roles          = ["admin", "user"]
      },

      {
        meshIdentifier = "identifier2"
        username       = "testuser2@likvid.io"
        firstName      = "test"
        lastName       = "user"
        email          = "testuser2@likvid.io"
        euid           = "testuser2@likvid.io"
        roles          = ["admin"]
      }
    ]
  }

  assert {
    condition     = length(var.users) > 0
    error_message = "No users provided"
  }
}

run "verify_with_subscriptions_and_entitlements" {
  variables {
    globalaccount = "meshcloudgmbh"
    #workspace_identifier = "sapbtp"
    project_identifier = "testsubaccount-apps"
    subfolder          = "test"

    entitlements = [
      {
        service_name = "build-code"
        plan_name    = "free"
      }
    ]

    subscriptions = [
      {
        app_name   = "build-code"
        plan_name  = "free"
        parameters = {}
      }
    ]
  }

  assert {
    condition     = length(btp_subaccount_entitlement.entitlement) > 0
    error_message = "Entitlements not created"
  }

  assert {
    condition     = length(btp_subaccount_subscription.subscription) > 0
    error_message = "Subscriptions not created"
  }
}

run "verify_with_cloudfoundry" {
  variables {
    globalaccount = "meshcloudgmbh"
    #workspace_identifier = "sapbtp"
    project_identifier = "testsubaccount-cf"
    subfolder          = "test"

    cloudfoundry_instance = {
      name      = "cf-dev"
      plan_name = "standard"
    }
  }

  assert {
    condition     = var.cloudfoundry_instance != null
    error_message = "Cloud Foundry instance configuration should be present"
  }
}

run "verify_with_trust_configuration" {
  command = plan

  override_resource {
    target = btp_subaccount_trust_configuration.custom_idp
  }

  variables {
    globalaccount = "meshcloudgmbh"
    #workspace_identifier = "sapbtp"
    project_identifier = "testsubaccount-idp"
    subfolder          = "test"

    trust_configuration = {
      identity_provider = "test.accounts.ondemand.com"
    }
  }

  assert {
    condition     = var.trust_configuration.identity_provider == "test.accounts.ondemand.com"
    error_message = "Trust configuration identity provider should be test.accounts.ondemand.com"
  }
}

run "verify_without_optional_features" {
  variables {
    globalaccount = "meshcloudgmbh"
    #workspace_identifier = "sapbtp"
    project_identifier = "testsubaccount-minimal"
    subfolder          = "test"
  }

  assert {
    condition     = length(var.entitlements) == 0
    error_message = "No entitlements should be configured when not specified"
  }

  assert {
    condition     = var.cloudfoundry_instance == null
    error_message = "Cloud Foundry should not be configured when not specified"
  }

  assert {
    condition     = var.trust_configuration == null
    error_message = "Trust configuration should not be configured when not specified"
  }
}
