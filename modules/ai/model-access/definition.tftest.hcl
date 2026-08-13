variables {
  litellm_api_base      = "https://litellm.example.com"
  litellm_admin_api_key = "sk-admin-mock"

  ai_platform_cluster_kubeconfig = "current-context: ai-platform\n"
  demo_app_cluster_kubeconfig    = "current-context: demo-app\n"
  demo_app_platform_identifier   = "kubernetes.eu01"

  langfuse_domain = "ai.example.com"

  stackit_project_id                     = "6e8c1f30-6c4d-4b1f-9f7a-2c9d8e5f1a2b"
  stackit_service_account_key            = "{\"id\":\"mock-key\"}"
  stackit_s3_admin_access_key            = "AKIAMOCKADMINKEY"
  stackit_s3_admin_secret_access_key     = "mock-admin-secret-access-key"
  stackit_s3_admin_credentials_group_urn = "urn:sgws:identity::12345678901234567890:group/mock-admin-group"

  langfuse_postgres_instance_id = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"

  langfuse_clickhouse_host = "clickhouse-clickhouse-headless.clickhouse.svc.cluster.local"

  langfuse_valkey_host     = "valkey.valkey.svc.cluster.local"
  langfuse_valkey_password = "valkey-password"

  oidc_issuer_url    = "https://idp.example.com/realms/ai"
  oidc_client_id     = "langfuse"
  oidc_client_secret = "mock-client-secret"

  meshstack = {
    owning_workspace_identifier = "platform-team"
  }
}

mock_provider "meshstack" {}

run "the_definition_is_a_mandatory_landing_zone_block" {
  command = plan

  assert {
    # Named for the capability. The products behind it are not part of what the application team
    # ordered, so neither may appear in the name.
    condition     = meshstack_building_block_definition.this.spec.display_name == "AI Model Access"
    error_message = "the display name has to name the capability, not the products that deliver it"
  }

  assert {
    condition     = meshstack_building_block_definition.this.spec.target_type == "TENANT_LEVEL"
    error_message = "the block runs on the AI model tenant, so it has to be TENANT_LEVEL"
  }

  assert {
    condition     = meshstack_building_block_definition.this.spec.use_in_landing_zones_only == true
    error_message = "the application team never orders this block by hand, so it may only be used from a landing zone"
  }

  assert {
    condition     = meshstack_building_block_definition.this.version_spec.only_apply_once_per_tenant == true
    error_message = "a second apply in the same tenant would create a second team, a second credential and a second tracing instance"
  }

  assert {
    # The run looks up the sibling tenant of the same meshProject with an ephemeral API token.
    condition     = contains(meshstack_building_block_definition.this.version_spec.permissions, "TENANT_LIST")
    error_message = "the run needs TENANT_LIST to look up the sibling tenant it delivers the credential to"
  }

  assert {
    condition     = meshstack_building_block_definition.this.version_spec.implementation.terraform.repository_path == "modules/ai/model-access/buildingblock"
    error_message = "the definition has to point at this module's buildingblock directory"
  }
}

run "no_input_asks_a_human_and_none_reaches_the_namespace_decision_from_the_tenant" {
  command = plan

  assert {
    # A mandatory block that stops to ask a human defeats its purpose, and API-driven tenant creation
    # only succeeds when every input is defaulted or static. The four assignment types below are the
    # only ones this definition may use: STATIC is fixed by the platform team, and the other three are
    # injected by meshStack from the tenant, so the tenant cannot forge them.
    condition = alltrue([
      for name, input in meshstack_building_block_definition.this.version_spec.inputs :
      contains(
        ["STATIC", "WORKSPACE_IDENTIFIER", "PROJECT_IDENTIFIER", "MESHSTACK_TENANT_UUID"],
        input.assignment_type
      )
    ])
    error_message = "every input has to be STATIC or assigned from tenant context, and no input may be a USER_INPUT"
  }

  assert {
    condition = alltrue([
      for name in ["workspace_identifier", "project_identifier", "demo_app_platform_identifier", "secret_name"] :
      contains(keys(meshstack_building_block_definition.this.version_spec.inputs), name)
    ])
    error_message = "the four inputs that decide which namespace receives the credential have to be declared"
  }
}

run "no_definition_output_can_carry_the_credential" {
  command = plan

  assert {
    # A building block output is always cleartext in meshPanel, because `version_spec.outputs` has no
    # `sensitive` block. The set is asserted in full, so adding an output is a deliberate change that
    # this test has to be updated for.
    condition = toset(keys(meshstack_building_block_definition.this.version_spec.outputs)) == toset([
      "team_id",
      "team_alias",
      "key_id",
      "api_base",
      "secret_name",
      "secret_namespace",
      "langfuse_url",
      "langfuse_namespace",
      "langfuse_oidc_callback_url",
      "summary",
    ])
    error_message = "the set of definition outputs changed; every one of them is cleartext in meshPanel, so check that the new one carries no credential"
  }

  assert {
    condition     = meshstack_building_block_definition.this.version_spec.outputs["team_id"].assignment_type == "PLATFORM_TENANT_ID"
    error_message = "the team id is the platform tenant id, so building blocks ordered later can bind to it"
  }

  assert {
    condition     = meshstack_building_block_definition.this.version_spec.outputs["langfuse_url"].assignment_type == "SIGN_IN_URL"
    error_message = "the tracing URL is a login URL, which SIGN_IN_URL is the assignment type for"
  }

  assert {
    condition     = meshstack_building_block_definition.this.version_spec.outputs["summary"].assignment_type == "SUMMARY"
    error_message = "the summary has to be published as the summary of the building block"
  }
}
