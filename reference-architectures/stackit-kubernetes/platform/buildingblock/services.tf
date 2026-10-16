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
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.ingress.ref, meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.dns_integration.building_block_definition.version_ref
    display_name                          = "DNS Zone"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        subdomain                     = { value = jsonencode(var.dns_subdomain) }
        wildcard_target_ip            = { value = jsonencode(local.ingress_load_balancer_ip) }
        contact_email                 = { value = jsonencode(var.cluster_issuer_email) }
        STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
        release_on_destroy            = { value = jsonencode(var.imports.dns != null && var.playground_mode) }
      },
      var.imports.dns == null ? {} : {
        imports = { value = jsonencode(jsonencode(var.imports.dns)) }
      },
    )
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
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
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
          secret_value   = local.output_to_vault
          secret_version = nonsensitive(sha256(local.output_to_vault))
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

  # An adopted organization's existing token is read on every run, the delete run included.
  depends_on = [vault_kv_secret_v2.import_git]

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.git_integration.building_block_definition.version_ref
    display_name                          = "STACKIT Git Instance"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        instance_name                 = { value = jsonencode(var.imports.git != null ? var.imports.git.instance_name : var.platform_identifier) }
        forgejo_organization          = { value = jsonencode(var.imports.git != null ? var.imports.git.forgejo_organization : var.platform_identifier) }
        shared_runner_labels          = { value = jsonencode(jsonencode(["stackit-ubuntu-22"])) }
        STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }
        output_to_vault = {
          sensitive = {
            secret_value   = local.output_to_vault
            secret_version = nonsensitive(sha256(local.output_to_vault))
          }
        }
        release_on_destroy = { value = jsonencode(var.imports.git != null && var.playground_mode) }
      },
      var.imports.git == null ? {} : {
        imports = { value = jsonencode(jsonencode({
          instance_id                     = var.imports.git.instance_id
          existing_forgejo_api_token_path = vault_kv_secret_v2.import_git.name
        })) }
      },
    )
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
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.container_registry_integration.building_block_definition.version_ref
    display_name                          = "STACKIT Container Registry"
    target_ref                            = local.tenant_ref

    inputs = merge(
      {
        # A Harbor project name is lowercase only, while the platform identifier also allows capitals.
        registry_name                 = { value = jsonencode(var.imports.container_registry != null ? var.imports.container_registry.registry_name : lower(var.platform_identifier)) }
        STACKIT_SERVICE_ACCOUNT_EMAIL = { value = jsonencode(local.service_account_email) }

        require_robot_link   = { value = jsonencode(var.phase2_completed) }
        mirrored_base_images = { value = jsonencode(jsonencode(["docker.io/library/python:3.12.9-slim-bookworm"])) }
        output_to_vault = {
          sensitive = {
            secret_value   = local.output_to_vault
            secret_version = nonsensitive(sha256(local.output_to_vault))
          }
        }
        release_on_destroy = { value = jsonencode(var.imports.container_registry != null && var.playground_mode) }
      },
      var.imports.container_registry == null ? {} : {
        imports = { value = jsonencode(jsonencode({ artifactory_id = var.imports.container_registry.artifactory_id })) }
      },
    )
  }
}
