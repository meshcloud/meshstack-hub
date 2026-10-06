locals {
  # The Harbor robot is the last step still done by hand, so it is the one thing that takes a second
  # order. Only the username decides, and it is deliberately not a sensitive input: meshStack sends a
  # non-empty value for a sensitive input left blank, which read as a robot that does not exist.
  harbor_robot_linked = trimspace(var.harbor_username) != ""

  registry_host = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_host"].value)
  # The registry block appends a suffix of its own, so the name it reports back is the one to use.
  registry_name = jsondecode(meshstack_building_block.container_registry.status.outputs["registry_name"].value)

  forgejo_instance_url = jsondecode(meshstack_building_block.git.status.outputs["instance_url"].value)
  forgejo_instance_id  = jsondecode(meshstack_building_block.git.status.outputs["instance_id"].value)
  forgejo_organization = jsondecode(meshstack_building_block.git.status.outputs["forgejo_organization"].value)

  dns_zone_name = var.existing != null ? var.existing.dns.zone_name : "${var.dns_subdomain}.${var.dns_parent_domain}"

  ai_llm_vault_secret             = jsondecode(jsondecode(meshstack_building_block.ai_llm.status.outputs["vault_secret"].value))
  container_registry_vault_secret = jsondecode(jsondecode(meshstack_building_block.container_registry.status.outputs["vault_secret"].value))

  # The registry reports its robots only once they exist, and a disabled module still evaluates its
  # arguments.
  connector_secrets_revision = local.harbor_robot_linked ? parseint(substr(sha256(jsonencode([
    local.container_registry_vault_secret.pull.secret_hash,
    local.ai_llm_vault_secret.secret_hash,
  ])), 0, 12), 16) : 1
}

module "git_repository_integration" {
  lifecycle {
    enabled = local.harbor_robot_linked
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository?ref=${var.hub.git_ref}"

  forgejo_base_url     = local.forgejo_instance_url
  forgejo_organization = local.forgejo_organization

  vault_reader           = local.secrets_manager_reader
  forgejo_api_token_path = local.vault_paths.git
  registry_push_path     = "${local.vault_paths.container_registry}/push"

  # The token's technical user is restricted in Forgejo and cannot look up other users, so members
  # are resolved through the STACKIT Git API instead.
  stackit_service_account_email = local.service_account_email
  stackit_project_id            = var.stackit_project_id
  stackit_git_instance_id       = local.forgejo_instance_id

  # Read by the workflow the template repository ships. Only the platform-wide constants are set
  # here; the starter kit sets APP_NAME and the connector the push robot per repository.
  action_variables = {
    HARBOR_REGISTRY = local.registry_host
    HARBOR_PROJECT  = local.registry_name
  }

  approval_policies = var.starterkit_approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# Federates the definitions the starter kit orders. A federation of its own, because the Git
# repository definition needs the outputs of the Git block, which is a child of the platform federation.
resource "meshstack_building_block" "starterkit_federation" {
  wait_for_completion = true

  lifecycle {
    enabled = local.harbor_robot_linked

    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
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

# Not registered until the Harbor robot exists. The connector's whole job is wiring a repository to a
# namespace for CI/CD, and that pipeline pushes an image — without pull credentials the definition
# would be orderable but the workload it produces could not start. Better absent than broken.
#
# TODO: what blocks minting the first robot is Harbor, not STACKIT IAM.
# `container-registry.artifactory.admin` is assignable at project scope, and granting it is what
# makes the Harbor project visible to a user — the container registry building block does that for
# every project member. But the Harbor API still only opens to an identity Harbor already knows, and
# only the portal can create that first link between a robot and a STACKIT service account. Every
# later robot can then go through the Harbor API.
module "forgejo_connector_integration" {
  lifecycle {
    enabled = local.harbor_robot_linked
  }

  source = "github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector?ref=${var.hub.git_ref}"

  kubeconfig         = ephemeral.vault_kv_secret_v2.service_account_kubeconfig.data.kubeconfig
  kubeconfig_version = tostring(local.service_account_vault_secret.secret_hash)

  forgejo_host                 = local.forgejo_instance_url
  forgejo_repo_definition_uuid = module.git_repository_integration.building_block_definition.uuid

  harbor_host = "https://${local.registry_host}"

  vault_reader           = local.secrets_manager_reader
  forgejo_api_token_path = local.vault_paths.git
  registry_pull_path     = "${local.vault_paths.container_registry}/pull"

  # `stackit-ai` is the secret name the starter kit's demo application reads inference configuration
  # from; the AI building block already writes the key names it expects.
  additional_kubernetes_secrets = {
    "stackit-ai" = local.vault_paths.ai_llm
  }
  secrets_revision = local.connector_secrets_revision

  approval_policies = var.starterkit_approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

# The offering application teams actually order: one building block that creates a project, a
# repository from a template and a namespace per stage, out of the two definitions above. It is
# registered on the same condition as they are, because it orders them.
module "ske_starterkit_integration" {
  lifecycle {
    enabled = local.harbor_robot_linked
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
