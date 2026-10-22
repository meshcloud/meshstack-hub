locals {
  registry_host = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_host"].value)
  # The registry block appends a suffix of its own, so the name it reports back is the one to use.
  registry_name = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_name"].value)

  forgejo_instance_url = jsondecode(meshstack_building_block.git.status.outputs["instance_url"].value)
  forgejo_instance_id  = jsondecode(meshstack_building_block.git.status.outputs["instance_id"].value)
  forgejo_organization = jsondecode(meshstack_building_block.git.status.outputs["forgejo_organization"].value)

  dns_zone_name = jsondecode(meshstack_building_block.dns.status.outputs["zone_name"].value)

  git_vault_secret                = jsondecode(jsondecode(meshstack_building_block.git.status.outputs["vault_secret"].value))
  ai_llm_vault_secret             = jsondecode(jsondecode(meshstack_building_block.ai_llm.status.outputs["vault_secret"].value))
  container_registry_vault_secret = jsondecode(jsondecode(meshstack_building_block.container_registry.status.outputs["vault_secret"].value))

  # The registry reports its secret only once the robots exist, and a disabled module still evaluates
  # its arguments.
  container_registry_secret_path = var.phase2_completed ? local.container_registry_vault_secret.path : ""
  connector_secrets_revision = var.phase2_completed ? parseint(substr(sha256(jsonencode([
    local.container_registry_vault_secret.secret_hash,
    local.ai_llm_vault_secret.secret_hash,
  ])), 0, 12), 16) : 1
}

module "git_repository_integration" {
  lifecycle {
    enabled = var.phase2_completed
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository?ref=${var.hub.git_ref}"

  forgejo_base_url     = local.forgejo_instance_url
  forgejo_organization = local.forgejo_organization

  vault_reader           = local.secrets_manager_reader
  forgejo_api_token_path = local.git_vault_secret.path
  registry_secret_path   = local.container_registry_secret_path

  stackit_service_account_email = local.service_account_email
  stackit_project_id            = var.stackit_project_id
  stackit_git_instance_id       = local.forgejo_instance_id

  # Read by the template repository's workflow; the starter kit adds APP_NAME.
  action_variables = {
    HARBOR_REGISTRY = local.registry_host
    HARBOR_PROJECT  = local.registry_name
  }

  approval_policies = var.starterkit_approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# Separate from the platform federation, because the Git repository definition needs its child's outputs.
resource "meshstack_building_block" "starterkit_federation" {
  wait_for_completion = true

  lifecycle {
    enabled = var.phase2_completed

    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [var.automation_identity.building_block_ref]
    building_block_definition_version_ref = var.service_account_federation_bbd_version_ref
    display_name                          = "Starter Kit Identity Federation"
    target_ref                            = local.tenant_ref

    inputs = {
      service_account_email = { value = jsonencode(local.service_account_email) }
      federated_building_block_definitions = {
        value = jsonencode(jsonencode([module.git_repository_integration.building_block_definition.uuid]))
      }
    }
  }
}

# Registered only in phase 2: without pull credentials the workloads it deploys could not start.
module "forgejo_connector_integration" {
  lifecycle {
    enabled = var.phase2_completed
  }

  source = "github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector?ref=${var.hub.git_ref}"

  kube_host       = local.kube_host
  kubeconfig_path = "${local.secrets_path_prefix}ske/cluster"

  forgejo_host                = local.forgejo_instance_url
  forgejo_repo_definition_ref = module.git_repository_integration.building_block_definition.ref

  vault_reader           = local.secrets_manager_reader
  forgejo_api_token_path = local.git_vault_secret.path
  registry_secret_path   = local.container_registry_secret_path

  # The starter kit's demo application reads its inference configuration from `stackit-ai`.
  additional_kubernetes_secrets = {
    "stackit-ai" = local.ai_llm_vault_secret.path
  }
  secrets_revision = local.connector_secrets_revision

  approval_policies = var.starterkit_approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

module "ske_starterkit_integration" {
  lifecycle {
    enabled = var.phase2_completed
  }

  # Its repositories resolve members as the platform service account, so the federation must exist first.
  depends_on = [meshstack_building_block.starterkit_federation]

  source = "github.com/meshcloud/meshstack-hub//modules/ske/ske-starterkit?ref=${var.hub.git_ref}"

  platform_ref      = module.kubernetes_integration.platform_ref
  landing_zone_refs = module.kubernetes_integration.landingzone_refs

  building_block_definition_version_refs = {
    "git-repository"    = module.git_repository_integration.building_block_definition.version_ref
    "forgejo-connector" = module.forgejo_connector_integration.building_block_definition.version_ref
  }

  app_name        = var.starterkit_app_name
  repo_clone_addr = var.starterkit_repo_clone_addr
  dns_zone_name   = local.dns_zone_name

  project_tags = {
    stages        = local.stage_project_tags
    owner_tag_key = var.tags.project_owner_tag_key == "" ? null : var.tags.project_owner_tag_key
  }

  approval_policies = var.starterkit_approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}
