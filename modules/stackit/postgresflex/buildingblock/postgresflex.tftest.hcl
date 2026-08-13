mock_provider "stackit" {
  mock_data "stackit_postgresflex_flavors" {
    defaults = {
      flavors = [
        {
          id              = "flavor-4-8-replica"
          cpu             = 4
          memory          = 8
          node_type       = "Replica"
          description     = "4 vCPU / 8 GiB / Replica"
          max_gb          = 1000
          min_gb          = 5
          storage_classes = []
        },
        {
          id              = "flavor-2-4-single"
          cpu             = 2
          memory          = 4
          node_type       = "Single"
          description     = "2 vCPU / 4 GiB / Single"
          max_gb          = 1000
          min_gb          = 5
          storage_classes = []
        },
      ]
    }
  }

  mock_data "stackit_postgresflex_instance" {
    defaults = {
      name    = "ai-platform-shared"
      version = "17"
      network = {
        acl              = ["193.148.160.0/19", "203.0.113.17/32"]
        access_scope     = "PUBLIC"
        instance_address = "10.0.0.5"
        router_address   = "10.0.0.1"
      }
      connection_info = {
        write = {
          host = "shared.postgresflex.eu01.onstackit.cloud"
          port = 5432
        }
      }
    }
  }

  mock_resource "stackit_postgresflex_instance" {
    defaults = {
      instance_id = "11111111-2222-3333-4444-555555555555"
      connection_info = {
        write = {
          host = "own.postgresflex.eu01.onstackit.cloud"
          port = 5432
        }
      }
    }
  }

  mock_resource "stackit_postgresflex_user" {
    defaults = {
      user_id  = "99999999-8888-7777-6666-555555555555"
      password = "pa/ss+wo?rd"
      host     = "own.postgresflex.eu01.onstackit.cloud"
      port     = 5432
    }
  }
}

run "creates_the_instance_the_database_and_the_user" {
  command = plan

  variables {
    project_id     = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    stackit_region = "eu01"

    instance_name    = "litellm-db"
    flavor_cpu       = 4
    flavor_ram       = 8
    replicas         = 3
    storage_size     = 40
    postgres_version = "17"
    acl              = ["193.148.160.0/19", "203.0.113.17/32"]

    database_name       = "litellm"
    database_username   = "litellm"
    database_user_roles = ["login"]
  }

  assert {
    condition     = output.instance_id == "11111111-2222-3333-4444-555555555555"
    error_message = "create-instance mode must report the created instance's id"
  }

  assert {
    condition     = output.host == "own.postgresflex.eu01.onstackit.cloud"
    error_message = "create-instance mode must report the created instance's write host"
  }

  assert {
    condition     = output.port == 5432
    error_message = "create-instance mode must report the created instance's write port"
  }

  assert {
    condition     = output.connection_string == "postgresql://litellm:pa%2Fss%2Bwo%3Frd@own.postgresflex.eu01.onstackit.cloud:5432/litellm?sslmode=require"
    error_message = "create-instance mode must assemble the connection string from the created instance"
  }

  assert {
    condition     = output.direct_connection_string == output.connection_string
    error_message = "DIRECT_URL equals the pooled URL while no pooler sits in front of the instance"
  }

  assert {
    condition     = strcontains(output.summary, "litellm-db")
    error_message = "the summary must name the created instance"
  }

  assert {
    condition     = strcontains(output.summary, "193.148.160.0/19, 203.0.113.17/32")
    error_message = "the summary must report the ACL the module applies"
  }
}

run "creates_only_the_database_and_the_user" {
  command = plan

  variables {
    project_id     = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    stackit_region = "eu01"

    existing_instance_id = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"

    database_name       = "langfuse_acme"
    database_username   = "langfuse_acme"
    database_user_roles = ["login"]
  }

  assert {
    condition     = output.instance_id == "3f2504e0-4f89-11d3-9a0c-0305e82c3301"
    error_message = "database-only mode must report the existing instance's id"
  }

  assert {
    condition     = output.host == "shared.postgresflex.eu01.onstackit.cloud"
    error_message = "database-only mode must read the host from the existing instance"
  }

  assert {
    condition     = output.port == 5432
    error_message = "database-only mode must read the port from the existing instance"
  }

  assert {
    condition     = output.database_name == "langfuse_acme"
    error_message = "database-only mode must report the database it creates"
  }

  assert {
    condition     = output.username == "langfuse_acme"
    error_message = "database-only mode must report the owner user it creates"
  }

  assert {
    condition     = output.password == "pa/ss+wo?rd"
    error_message = "database-only mode must report the generated password"
  }

  assert {
    condition     = output.connection_string == "postgresql://langfuse_acme:pa%2Fss%2Bwo%3Frd@shared.postgresflex.eu01.onstackit.cloud:5432/langfuse_acme?sslmode=require"
    error_message = "database-only mode must assemble the connection string from the existing instance"
  }

  assert {
    condition     = output.direct_connection_string == output.connection_string
    error_message = "DIRECT_URL equals the pooled URL while no pooler sits in front of the instance"
  }

  assert {
    condition     = strcontains(output.summary, "ai-platform-shared")
    error_message = "the summary must name the shared instance"
  }

  assert {
    condition     = strcontains(output.summary, "193.148.160.0/19, 203.0.113.17/32")
    error_message = "the summary must report the ACL the shared instance actually carries"
  }

  assert {
    condition     = strcontains(output.summary, "3f2504e0-4f89-11d3-9a0c-0305e82c3301")
    error_message = "the summary must name the shared instance's id"
  }
}

# The submodule is the entry point a composition sources when it creates one database per tenant
# with for_each. It has to work on its own, with the provider configured by the caller — here the
# mock above — rather than by a provider block of its own.
run "the_submodule_works_without_a_provider_block_of_its_own" {
  command = plan

  module {
    source = "./database"
  }

  variables {
    project_id     = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    stackit_region = "eu01"

    existing_instance_id = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"

    database_name       = "langfuse_acme"
    database_username   = "langfuse_acme"
    database_user_roles = ["login"]
  }

  assert {
    condition     = output.connection_string == "postgresql://langfuse_acme:pa%2Fss%2Bwo%3Frd@shared.postgresflex.eu01.onstackit.cloud:5432/langfuse_acme?sslmode=require"
    error_message = "the submodule must assemble the same connection string as the root"
  }

  assert {
    condition     = output.instance_id == "3f2504e0-4f89-11d3-9a0c-0305e82c3301"
    error_message = "the submodule must report the shared instance it created the database in"
  }
}

run "rejects_an_empty_existing_instance_id" {
  command = plan

  variables {
    project_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    existing_instance_id = ""
  }

  expect_failures = [var.existing_instance_id]
}

run "rejects_both_modes_at_once" {
  command = plan

  variables {
    project_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    instance_name        = "litellm-db"
    existing_instance_id = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"
  }

  expect_failures = [var.instance_name]
}

run "rejects_neither_mode" {
  command = plan

  variables {
    project_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  }

  expect_failures = [var.instance_name]
}
