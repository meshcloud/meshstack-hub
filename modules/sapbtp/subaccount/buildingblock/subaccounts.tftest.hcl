run "verify_basic_subaccount" {
  variables {
    globalaccount      = "meshcloudgmbh"
    project_identifier = "testsubaccount-basic"
    subfolder          = "test"
    region             = "eu10"
    users = [
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Livkid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
      },
      {
        meshIdentifier = "likvid-daniela-user"
        username       = "likvid-daniela@meshcloud.io"
        firstName      = "Daniela"
        lastName       = "Livkid"
        email          = "likvid-daniela@meshcloud.io"
        euid           = "likvid-daniela@meshcloud.io"
        roles          = ["user", "Workspace Manager"]
      },
      {
        meshIdentifier = "likvid-anna-user"
        username       = "likvid-anna@meshcloud.io"
        firstName      = "Anna"
        lastName       = "Livkid"
        email          = "likvid-anna@meshcloud.io"
        euid           = "likvid-anna@meshcloud.io"
        roles          = ["reader", "Workspace Member"]
      }
    ]
  }

  assert {
    condition     = length(var.users) == 3
    error_message = "Should have 3 users configured"
  }

  assert {
    condition     = btp_subaccount.subaccount.name == "testsubaccount-basic"
    error_message = "Subaccount name should match project_identifier"
  }

  assert {
    condition     = btp_subaccount.subaccount.region == "eu10"
    error_message = "Subaccount region should be eu10"
  }
}

run "verify_role_assignments" {
  variables {
    globalaccount      = "meshcloudgmbh"
    project_identifier = "testsubaccount-roles"
    users = [
      {
        meshIdentifier = "admin-user"
        username       = "admin@meshcloud.io"
        firstName      = "Admin"
        lastName       = "User"
        email          = "admin@meshcloud.io"
        euid           = "admin@meshcloud.io"
        roles          = ["admin"]
      },
      {
        meshIdentifier = "service-admin-user"
        username       = "service@meshcloud.io"
        firstName      = "Service"
        lastName       = "User"
        email          = "service@meshcloud.io"
        euid           = "service@meshcloud.io"
        roles          = ["user"]
      },
      {
        meshIdentifier = "viewer-user"
        username       = "viewer@meshcloud.io"
        firstName      = "Viewer"
        lastName       = "User"
        email          = "viewer@meshcloud.io"
        euid           = "viewer@meshcloud.io"
        roles          = ["reader"]
      }
    ]
  }

  assert {
    condition     = length(btp_subaccount_role_collection_assignment.subaccount_admin) == 1
    error_message = "Should have 1 Subaccount Administrator assignment"
  }

  assert {
    condition     = length(btp_subaccount_role_collection_assignment.subaccount_service_admininstrator) == 1
    error_message = "Should have 1 Subaccount Service Administrator assignment"
  }

  assert {
    condition     = length(btp_subaccount_role_collection_assignment.subaccount_viewer) == 1
    error_message = "Should have 1 Subaccount Viewer assignment"
  }
}

run "verify_minimal_configuration" {
  variables {
    globalaccount      = "meshcloudgmbh"
    project_identifier = "testsubaccount-minimal"
  }

  assert {
    condition     = btp_subaccount.subaccount.name == "testsubaccount-minimal"
    error_message = "Subaccount should be created even with minimal config"
  }

  assert {
    condition     = var.region == "eu10"
    error_message = "Should use default region eu10"
  }

  assert {
    condition     = var.subfolder == ""
    error_message = "Should use empty subfolder by default"
  }

  assert {
    condition     = length(var.users) == 0
    error_message = "Should have no users by default"
  }
}

run "verify_subfolder_selection" {
  variables {
    globalaccount      = "meshcloudgmbh"
    project_identifier = "testsubaccount-folder"
    subfolder          = "Development"
    region             = "us10"
  }

  assert {
    condition     = var.subfolder == "Development"
    error_message = "Subfolder should be set to Development"
  }

  assert {
    condition     = btp_subaccount.subaccount.region == "us10"
    error_message = "Subaccount region should be us10"
  }
}

run "verify_outputs" {
  variables {
    globalaccount      = "meshcloudgmbh"
    project_identifier = "testsubaccount-outputs"
  }

  assert {
    condition     = output.subaccount_id != ""
    error_message = "Should output subaccount_id"
  }

  assert {
    condition     = output.subaccount_name == "testsubaccount-outputs"
    error_message = "Should output correct subaccount_name"
  }

  assert {
    condition     = output.subaccount_subdomain == "testsubaccount-outputs"
    error_message = "Should output correct subaccount_subdomain"
  }

  assert {
    condition     = output.subaccount_region != ""
    error_message = "Should output subaccount_region"
  }

  assert {
    condition     = can(regex("^https://.*", output.subaccount_login_link))
    error_message = "Should output valid login link URL"
  }
}

run "verify_parent_id_import_pattern" {
  variables {
    globalaccount      = "meshcloudgmbh"
    project_identifier = "testsubaccount-import"
    parent_id          = "9b8960a6-b80a-4096-80e5-a61bea98ac48"
    region             = "eu30"
  }

  assert {
    condition     = var.parent_id != ""
    error_message = "Parent ID should be set for import pattern"
  }

  assert {
    condition     = btp_subaccount.subaccount.parent_id == "9b8960a6-b80a-4096-80e5-a61bea98ac48"
    error_message = "Subaccount should use parent_id directly when provided"
  }

  assert {
    condition     = var.subfolder == ""
    error_message = "Subfolder should be empty when using parent_id"
  }
}
