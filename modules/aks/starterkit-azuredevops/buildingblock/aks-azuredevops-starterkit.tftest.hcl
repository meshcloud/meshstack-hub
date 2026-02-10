variables {
  workspace_identifier                                = "likvid-workspace"
  name                                                = "MyApp"
  full_platform_identifier                            = "aks.eu-de-central"
  landing_zone_dev_identifier                         = "aks-dev-lz"
  landing_zone_prod_identifier                        = "aks-prod-lz"
  azdevops_project_definition_version_uuid            = "00000000-0000-0000-0000-000000000001"
  azdevops_project_definition_uuid                    = "00000000-0000-0000-0000-000000000002"
  azdevops_repository_definition_version_uuid         = "00000000-0000-0000-0000-000000000003"
  azdevops_repository_definition_uuid                 = "00000000-0000-0000-0000-000000000004"
  azdevops_pipeline_definition_version_uuid           = "00000000-0000-0000-0000-000000000005"
  azdevops_pipeline_definition_uuid                   = "00000000-0000-0000-0000-000000000006"
  azdevops_service_connection_definition_version_uuid = "00000000-0000-0000-0000-000000000007"
  azdevops_service_connection_definition_uuid         = "00000000-0000-0000-0000-000000000008"
  azdevops_organization_name                          = "likvid-bank"
  dev_azure_subscription_id                           = "11111111-1111-1111-1111-111111111111"
  dev_service_principal_id                            = "22222222-2222-2222-2222-222222222222"
  dev_application_object_id                           = "33333333-3333-3333-3333-333333333333"
  prod_azure_subscription_id                          = "44444444-4444-4444-4444-444444444444"
  prod_service_principal_id                           = "55555555-5555-5555-5555-555555555555"
  prod_application_object_id                          = "66666666-6666-6666-6666-666666666666"
  azure_tenant_id                                     = "77777777-7777-7777-7777-777777777777"

  creator = {
    type        = "User"
    identifier  = "likvid-tom-user"
    displayName = "Tom Livkid"
    username    = "likvid-tom@meshcloud.io"
    email       = "likvid-tom@meshcloud.io"
    euid        = "likvid-tom@meshcloud.io"
  }
}

run "valid_starter_kit_creation" {
  command = plan

  assert {
    condition     = meshstack_project.dev.metadata.name == "myapp-dev"
    error_message = "Dev project name should be normalized and suffixed with -dev"
  }

  assert {
    condition     = meshstack_project.prod.metadata.name == "myapp-prod"
    error_message = "Prod project name should be normalized and suffixed with -prod"
  }

  assert {
    condition     = meshstack_tenant_v4.dev.spec.platform_identifier == var.full_platform_identifier
    error_message = "Dev tenant should use correct platform identifier"
  }

  assert {
    condition     = meshstack_tenant_v4.prod.spec.platform_identifier == var.full_platform_identifier
    error_message = "Prod tenant should use correct platform identifier"
  }

  assert {
    condition     = meshstack_building_block_v2.azdevops_project.spec.target_ref.kind == "meshWorkspace"
    error_message = "Azure DevOps project should target workspace"
  }

  assert {
    condition     = length(meshstack_building_block_v2.repository.spec.parent_building_blocks) == 1
    error_message = "Repository should have Azure DevOps project as parent"
  }

  assert {
    condition     = length(meshstack_building_block_v2.service_connection_dev.spec.parent_building_blocks) == 1
    error_message = "Dev service connection should have Azure DevOps project as parent"
  }

  assert {
    condition     = length(meshstack_building_block_v2.service_connection_prod.spec.parent_building_blocks) == 1
    error_message = "Prod service connection should have Azure DevOps project as parent"
  }

  assert {
    condition     = length(meshstack_building_block_v2.pipeline_dev.spec.parent_building_blocks) == 2
    error_message = "Dev pipeline should have repository and service connection as parents"
  }

  assert {
    condition     = length(meshstack_building_block_v2.pipeline_prod.spec.parent_building_blocks) == 2
    error_message = "Prod pipeline should have repository and service connection as parents"
  }

  assert {
    condition     = meshstack_building_block_v2.service_connection_dev.spec.inputs.authorize_all_pipelines.value_bool == true
    error_message = "Dev service connection should auto-authorize pipelines"
  }

  assert {
    condition     = meshstack_building_block_v2.service_connection_prod.spec.inputs.authorize_all_pipelines.value_bool == false
    error_message = "Prod service connection should require manual authorization"
  }
}

run "creator_assigned_as_project_admin" {
  command = plan

  variables {
    creator = {
      type        = "User"
      identifier  = "likvid-daniela-user"
      displayName = "Daniela Livkid"
      username    = "likvid-daniela@meshcloud.io"
      email       = "likvid-daniela@meshcloud.io"
      euid        = "likvid-daniela@meshcloud.io"
    }
  }

  assert {
    condition     = length(meshstack_project_user_binding.creator_dev_admin) == 1
    error_message = "Creator should be assigned as Project Admin on dev project"
  }

  assert {
    condition     = length(meshstack_project_user_binding.creator_prod_admin) == 1
    error_message = "Creator should be assigned as Project Admin on prod project"
  }

  assert {
    condition     = meshstack_project_user_binding.creator_dev_admin[0].role_ref.name == "Project Admin"
    error_message = "Creator should have Project Admin role on dev project"
  }

  assert {
    condition     = meshstack_project_user_binding.creator_prod_admin[0].role_ref.name == "Project Admin"
    error_message = "Creator should have Project Admin role on prod project"
  }

  assert {
    condition     = meshstack_project_user_binding.creator_dev_admin[0].subject.name == "likvid-daniela@meshcloud.io"
    error_message = "Creator username should be correctly assigned"
  }
}

run "non_user_creator_skips_bindings" {
  command = plan

  variables {
    creator = {
      type        = "ServiceAccount"
      identifier  = "system-account"
      displayName = "System Account"
    }
  }

  assert {
    condition     = length(meshstack_project_user_binding.creator_dev_admin) == 0
    error_message = "Non-user creator should not have user bindings created"
  }

  assert {
    condition     = length(meshstack_project_user_binding.creator_prod_admin) == 0
    error_message = "Non-user creator should not have user bindings created"
  }
}

run "custom_project_tags" {
  command = plan

  variables {
    project_tags_yaml = <<EOF
dev:
  costCenter:
    - "CC-123"
  environment:
    - "development"
prod:
  costCenter:
    - "CC-456"
  environment:
    - "production"
  criticalityLevel:
    - "high"
EOF
  }

  assert {
    condition     = length(meshstack_project.dev.spec.tags) == 2
    error_message = "Dev project should have tags from YAML config"
  }

  assert {
    condition     = length(meshstack_project.prod.spec.tags) == 3
    error_message = "Prod project should have tags from YAML config"
  }
}

run "branch_policies_disabled" {
  command = plan

  variables {
    enable_branch_policies = false
  }

  assert {
    condition     = meshstack_building_block_v2.repository.spec.inputs.enable_branch_policies.value_bool == false
    error_message = "Branch policies should be disabled when explicitly set to false"
  }
}

run "custom_minimum_reviewers" {
  command = plan

  variables {
    minimum_reviewers = 2
  }

  assert {
    condition     = meshstack_building_block_v2.repository.spec.inputs.minimum_reviewers.value_number == 2
    error_message = "Minimum reviewers should be configurable"
  }
}

run "pipeline_variables_include_namespace" {
  command = plan

  assert {
    condition     = can(jsondecode(meshstack_building_block_v2.pipeline_dev.spec.inputs.pipeline_variables.value_code)[0].name)
    error_message = "Pipeline variables should be valid JSON"
  }

  assert {
    condition     = contains([for v in jsondecode(meshstack_building_block_v2.pipeline_dev.spec.inputs.pipeline_variables.value_code) : v.name], "AKS_NAMESPACE")
    error_message = "Dev pipeline should include AKS_NAMESPACE variable"
  }

  assert {
    condition     = contains([for v in jsondecode(meshstack_building_block_v2.pipeline_prod.spec.inputs.pipeline_variables.value_code) : v.name], "AKS_NAMESPACE")
    error_message = "Prod pipeline should include AKS_NAMESPACE variable"
  }

  assert {
    condition     = contains([for v in jsondecode(meshstack_building_block_v2.pipeline_dev.spec.inputs.pipeline_variables.value_code) : v.name], "SERVICE_CONNECTION")
    error_message = "Dev pipeline should include SERVICE_CONNECTION variable"
  }
}

run "invalid_repository_init_type" {
  command = plan

  variables {
    repository_init_type = "Invalid"
  }

  expect_failures = [
    var.repository_init_type,
  ]
}

run "invalid_minimum_reviewers" {
  command = plan

  variables {
    minimum_reviewers = 15
  }

  expect_failures = [
    var.minimum_reviewers,
  ]
}

run "special_characters_in_name" {
  command = plan

  variables {
    name = "My Awesome App! 🚀"
  }

  assert {
    condition     = length(regexall("[^a-z0-9-]", local.identifier)) == 0
    error_message = "Identifier should normalize special characters and spaces"
  }

  assert {
    condition     = local.identifier == "my-awesome-app"
    error_message = "Identifier should be lowercase with hyphens"
  }
}
