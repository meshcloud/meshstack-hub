run "setup" {
  command = plan

  variables {
    datacenter_name        = "test-datacenter"
    datacenter_location    = "de/fra"
    datacenter_description = "Test datacenter for Terraform validation"

    ionos_token           = "test-token"
    default_user_password = "TestPassword123!"
    force_sec_auth        = false

    users = [
      {
        meshIdentifier = "test-user-001"
        username       = "testuser1"
        firstName      = "Test"
        lastName       = "User1"
        email          = "testuser1@example.com"
        euid           = "test.user1"
        roles          = ["reader"]
      },
      {
        meshIdentifier = "test-user-002"
        username       = "testuser2"
        firstName      = "Test"
        lastName       = "User2"
        email          = "testuser2@example.com"
        euid           = "test.user2"
        roles          = ["user"]
      },
      {
        meshIdentifier = "test-admin-001"
        username       = "testadmin1"
        firstName      = "Test"
        lastName       = "Admin1"
        email          = "testadmin1@example.com"
        euid           = "test.admin1"
        roles          = ["admin", "user"]
      }
    ]
  }
}

run "validate_outputs" {
  command = plan

  assert {
    condition     = output.datacenter_name == "test-datacenter"
    error_message = "Datacenter name should match input variable"
  }

  assert {
    condition     = output.datacenter_location == "de/fra"
    error_message = "Datacenter location should match input variable"
  }

  assert {
    condition     = length(output.user_assignments.readers) == 1
    error_message = "Should have exactly 1 reader user"
  }

  assert {
    condition     = length(output.user_assignments.users) == 1
    error_message = "Should have exactly 1 standard user"
  }

  assert {
    condition     = length(output.user_assignments.administrators) == 1
    error_message = "Should have exactly 1 administrator user"
  }
}