# ── STACKIT Model Serving token (sovereign LLM API for the sample application) ──
resource "stackit_modelserving_token" "this" {
  project_id  = local.stackit_project_id
  name        = "ske-starterkit-${var.template_name}"
  description = "ske-starterkit-${var.template_name}"
}

locals {
  # Registry host is fixed for all container images on STACKIT.
  stackit_harbor_registry = "registry.onstackit.cloud"

  # Injected by the connector into each dev/prod namespace so the sample app can reach Model Serving.
  ai_kubernetes_secrets = {
    "stackit-ai" = {
      STACKIT_AI_BASE_URL = "https://api.openai-compat.model-serving.${stackit_modelserving_token.this.region}.onstackit.cloud/v1"
      STACKIT_AI_API_KEY  = stackit_modelserving_token.this.token
      STACKIT_AI_MODEL    = var.ai_model
    }
  }
}

# ── Self-service starterkit composition (registers three building block definitions) ──

module "git_repository" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository?ref=${var.hub.git_ref}"

  # The whole starterkit composition needs the Forgejo bot token, so all three definitions are gated
  # on it together and only get registered once the token is provided on a later run.
  lifecycle {
    enabled = local.starterkit_enabled
  }

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub

  forgejo_token        = var.forgejo_token
  forgejo_organization = var.forgejo_organization
  forgejo_base_url     = local.forgejo_base_url

  action_secrets = {
    HARBOR_USERNAME = var.stackit_harbor_push_robot_user
    HARBOR_PASSWORD = var.stackit_harbor_push_robot_password
  }

  action_variables = {
    HARBOR_REGISTRY = local.stackit_harbor_registry
    HARBOR_PROJECT  = var.stackit_harbor_project
    APP_NAME        = var.template_name
  }

  depends_on = [restapi_object.forgejo_organization]
}

module "forgejo_connector" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/forgejo-connector?ref=${var.hub.git_ref}"

  lifecycle {
    enabled = local.starterkit_enabled
  }

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub

  kubeconfig = yamldecode(local.cluster_kubeconfig)

  forgejo_host                 = local.forgejo_base_url
  forgejo_api_token            = var.forgejo_token
  forgejo_repo_definition_uuid = module.git_repository.building_block_definition.uuid

  harbor_host     = local.stackit_harbor_registry
  harbor_username = var.stackit_harbor_pull_robot_user
  harbor_password = var.stackit_harbor_pull_robot_password

  additional_kubernetes_secrets = local.ai_kubernetes_secrets
}

module "ske_starterkit" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/ske-starterkit?ref=${var.hub.git_ref}"

  lifecycle {
    enabled = local.starterkit_enabled
  }

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub

  building_block_definition_version_refs = {
    "git-repository"    = module.git_repository.building_block_definition.version_ref
    "forgejo-connector" = module.forgejo_connector.building_block_definition.version_ref
  }

  platform_ref = meshstack_platform.ske.ref
  landing_zone_refs = {
    dev  = meshstack_landingzone.this["dev"].ref
    prod = meshstack_landingzone.this["prod"].ref
  }

  project_tags = var.project_tags

  repo_clone_addr        = var.template_repo_clone_url
  dns_zone_name          = stackit_dns_zone.this.dns_name
  add_random_name_suffix = var.add_random_name_suffix
}
