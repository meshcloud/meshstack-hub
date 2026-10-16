# Mocked unit runs against ../buildingblock: which identity each federation trusts, and which
# definitions it refuses. They run offline, alongside the live case.
#
# Override values take literals only, so every definition is spelled out.

mock_provider "stackit" {}
mock_provider "meshstack" {}

variables {
  project_id            = "11111111-2222-3333-4444-555555555555"
  service_account_email = "sa@example.com"
  workspace_identifier  = "platform-ws"
}

override_data {
  target = data.meshstack_building_block_definitions.federated
  values = {
    building_block_definitions = [
      {
        # Released v1 on the hosted runner, newer draft v2 on another runner. Runs present v2's identity.
        metadata = { uuid = "aaaaaaaa-0000-0000-0000-000000000001", owned_by_workspace = "platform-ws" }
        spec     = { display_name = "a", target_type = "TENANT_LEVEL" }
        ref      = { kind = "meshBuildingBlockDefinition", uuid = "aaaaaaaa-0000-0000-0000-000000000001" }
        versions = null
        version_latest = {
          uuid = "a-v2", number = 2, state = "DRAFT", content_hash = null
          workload_identity_federation = {
            issuer  = "https://oidc-other.example.com"
            subject = "system:serviceaccount:other:workspace.platform-ws.buildingblockdefinition.aaaaaaaa-0000-0000-0000-000000000001"
            gcp     = null
            aws     = null
            azure   = { audience = "api://AzureADTokenExchange", token_path = "/t" }
          }
        }
        version_latest_release = {
          uuid = "a-v1", number = 1, state = "RELEASED", content_hash = null
          workload_identity_federation = {
            issuer  = "https://oidc.example.com"
            subject = "system:serviceaccount:meshfed:workspace.platform-ws.buildingblockdefinition.aaaaaaaa-0000-0000-0000-000000000001"
            gcp     = null
            aws     = null
            azure   = { audience = "api://AzureADTokenExchange", token_path = "/t" }
          }
        }
      },
      {
        metadata               = { uuid = "bbbbbbbb-0000-0000-0000-000000000002", owned_by_workspace = "platform-ws" }
        spec                   = { display_name = "b", target_type = "TENANT_LEVEL" }
        ref                    = { kind = "meshBuildingBlockDefinition", uuid = "bbbbbbbb-0000-0000-0000-000000000002" }
        versions               = null
        version_latest_release = null
        version_latest = {
          uuid = "b-v1", number = 1, state = "DRAFT", content_hash = null
          workload_identity_federation = {
            issuer  = "https://oidc.example.com"
            subject = "system:serviceaccount:meshfed:workspace.platform-ws.buildingblockdefinition.bbbbbbbb-0000-0000-0000-000000000002"
            gcp     = null
            aws     = null
            azure   = { audience = "api://AzureADTokenExchange", token_path = "/t" }
          }
        }
      },
      {
        # Its runner leaves workload identity federation unset.
        metadata               = { uuid = "cccccccc-0000-0000-0000-000000000003", owned_by_workspace = "platform-ws" }
        spec                   = { display_name = "c", target_type = "TENANT_LEVEL" }
        ref                    = { kind = "meshBuildingBlockDefinition", uuid = "cccccccc-0000-0000-0000-000000000003" }
        versions               = null
        version_latest         = { uuid = "c-v1", number = 1, state = "RELEASED", content_hash = null, workload_identity_federation = null }
        version_latest_release = { uuid = "c-v1", number = 1, state = "RELEASED", content_hash = null, workload_identity_federation = null }
      },
      {
        # Its runner federates with GCP only, and STACKIT needs the Azure audience.
        metadata = { uuid = "dddddddd-0000-0000-0000-000000000004", owned_by_workspace = "platform-ws" }
        spec     = { display_name = "d", target_type = "TENANT_LEVEL" }
        ref      = { kind = "meshBuildingBlockDefinition", uuid = "dddddddd-0000-0000-0000-000000000004" }
        versions = null
        version_latest = {
          uuid = "d-v1", number = 1, state = "RELEASED", content_hash = null
          workload_identity_federation = {
            issuer  = "https://oidc.example.com"
            subject = "gcp-only"
            gcp     = { audience = "g", token_path = "/g" }
            aws     = null
            azure   = null
          }
        }
        version_latest_release = null
      },
    ]
  }
}

run "trusts_the_identity_of_the_latest_version" {
  command = plan

  module {
    source = "../buildingblock"
  }

  variables {
    federated_building_block_definitions = ["aaaaaaaa-0000-0000-0000-000000000001", "bbbbbbbb-0000-0000-0000-000000000002"]
  }

  assert {
    condition     = stackit_service_account_federated_identity_provider.this["aaaaaaaa-0000-0000-0000-000000000001"].issuer == "https://oidc-other.example.com"
    error_message = "The issuer comes from version_latest."
  }

  assert {
    condition     = stackit_service_account_federated_identity_provider.this["aaaaaaaa-0000-0000-0000-000000000001"].assertions[1].value == "system:serviceaccount:other:workspace.platform-ws.buildingblockdefinition.aaaaaaaa-0000-0000-0000-000000000001"
    error_message = "The subject comes from version_latest."
  }

  assert {
    condition     = stackit_service_account_federated_identity_provider.this["bbbbbbbb-0000-0000-0000-000000000002"].assertions[0].value == "api://AzureADTokenExchange"
    error_message = "The audience comes from the identity's azure block."
  }

  assert {
    condition     = stackit_service_account_federated_identity_provider.this["aaaaaaaa-0000-0000-0000-000000000001"].name == "meshstack-aaaaaaaa"
    error_message = "Federations stay keyed by uuid, so existing state keeps its addresses."
  }
}

run "an_empty_list_creates_no_federation" {
  command = plan

  module {
    source = "../buildingblock"
  }

  variables {
    federated_building_block_definitions = []
  }

  assert {
    condition     = length(stackit_service_account_federated_identity_provider.this) == 0
    error_message = "An empty list creates zero federations."
  }
}

run "refuses_a_definition_the_workspace_does_not_own" {
  command = plan

  module {
    source = "../buildingblock"
  }

  variables {
    federated_building_block_definitions = ["eeeeeeee-0000-0000-0000-000000000005"]
  }

  expect_failures = [stackit_service_account_federated_identity_provider.this]
}

run "refuses_a_runner_without_workload_identity_federation" {
  command = plan

  module {
    source = "../buildingblock"
  }

  variables {
    federated_building_block_definitions = ["cccccccc-0000-0000-0000-000000000003"]
  }

  expect_failures = [stackit_service_account_federated_identity_provider.this]
}

run "refuses_an_identity_without_an_azure_audience" {
  command = plan

  module {
    source = "../buildingblock"
  }

  variables {
    federated_building_block_definitions = ["dddddddd-0000-0000-0000-000000000004"]
  }

  expect_failures = [stackit_service_account_federated_identity_provider.this]
}
