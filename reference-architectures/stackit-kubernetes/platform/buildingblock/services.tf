module "dns_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/dns?ref=${var.hub.git_ref}"

  parent_domain = var.dns_parent_domain

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "dns" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.ingress.ref, meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.dns_integration.building_block_definition.version_ref
    display_name                          = "DNS Zone"
    target_ref                            = local.tenant_ref

    inputs = {
      subdomain                     = { value = jsonencode(var.dns_subdomain) }
      wildcard_target_ip            = { value = jsonencode(jsondecode(meshstack_building_block.ingress.status.outputs["haproxy_lb_ip"].value)) }
      contact_email                 = { value = jsonencode(var.cluster_issuer_email) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
    }
  }
}

module "ai_llm_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/ai-llm?ref=${var.hub.git_ref}"

  model = var.ai_model

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "ai_llm" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.ai_llm_integration.building_block_definition.version_ref
    display_name                          = "AI Model Serving"
    target_ref                            = local.tenant_ref

    inputs = {
      token_name                    = { value = jsonencode(var.platform_identifier) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
      output_to_vault = {
        sensitive = {
          secret_value   = local.output_to_vault.ai_llm
          secret_version = nonsensitive(sha256(local.output_to_vault.ai_llm))
        }
      }
    }
  }
}

module "git_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git?ref=${var.hub.git_ref}"

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "git" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.git_integration.building_block_definition.version_ref
    display_name                          = "STACKIT Git Instance"
    target_ref                            = local.tenant_ref

    inputs = {
      instance_name = { value = jsonencode(var.platform_identifier) }
      # One organization per instance, sharing its name. The Git block would take any name here;
      # this architecture is what ties the two together.
      forgejo_organization          = { value = jsonencode(var.platform_identifier) }
      shared_runner_labels          = { value = jsonencode(jsonencode(["stackit-ubuntu-22"])) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
      output_to_vault = {
        sensitive = {
          secret_value   = local.output_to_vault.git
          secret_version = nonsensitive(sha256(local.output_to_vault.git))
        }
      }
    }
  }
}

module "container_registry_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/container-registry?ref=${var.hub.git_ref}"

  approval_policies = var.approval_policies

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "container_registry" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.container_registry_integration.building_block_definition.version_ref
    display_name                          = "STACKIT Container Registry"
    target_ref                            = local.tenant_ref

    inputs = {
      # A Harbor project name is lowercase only, while the platform identifier also allows capitals.
      registry_name                 = { value = jsonencode(lower(var.platform_identifier)) }
      STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }

      bootstrap_robot_username = { value = jsonencode(var.harbor_username) }
      mirrored_base_images     = { value = jsonencode(jsonencode(["docker.io/library/python:3.12.9-slim-bookworm"])) }
      output_to_vault = {
        sensitive = {
          secret_value   = local.output_to_vault.container_registry
          secret_version = nonsensitive(sha256(local.output_to_vault.container_registry))
        }
      }
    }
  }
}
