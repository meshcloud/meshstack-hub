locals {
  tenant_ref = { kind = "meshTenant", uuid = var.tenant_uuid }

  service_account_email = var.automation_identity.service_account_email

  location_name = var.use_global_location ? "global" : meshstack_location.this.metadata.name

  landing_zones = {
    for stage, cfg in var.stages : stage => {
      tags = merge({ environment = [stage] }, cfg.landingzone)
    }
  }

  stage_project_tags = {
    for stage, cfg in var.stages : stage => merge(var.tags.starterkit_project, { environment = [stage] }, cfg.project)
  }

  secrets_manager_instance_id = jsondecode(meshstack_building_block.secrets_manager.status.outputs["instance_id"].value)

  # The stackit provider does not return the instance's API address. STACKIT serves every eu01
  # instance from this one.
  secrets_manager_address = "https://prod.sm.eu01.stackit.cloud"

  secrets_manager_writer = {
    address  = local.secrets_manager_address
    mount    = local.secrets_manager_instance_id
    username = stackit_secretsmanager_user.writer.username
    password = stackit_secretsmanager_user.writer.password
  }

  secrets_manager_reader = {
    address  = local.secrets_manager_address
    mount    = local.secrets_manager_instance_id
    username = stackit_secretsmanager_user.reader.username
    password = stackit_secretsmanager_user.reader.password
  }

  vault_paths = {
    cluster_kubeconfig         = "cluster/ske"
    service_account_kubeconfig = "cluster/serviceaccount"
    kubernetes_platform        = "kubernetes/platform"
    git                        = "git/forgejo-api-token"
    container_registry         = "registry"
    ai_llm                     = "ai/model-serving"
  }

  output_to_vault = {
    for block, path in local.vault_paths : block => jsonencode(merge(local.secrets_manager_writer, { path = path }))
  }
}

resource "meshstack_location" "this" {
  lifecycle {
    enabled = !var.use_global_location
  }

  metadata = {
    name               = var.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = var.platform_identifier
    description  = "STACKIT SKE location created by the STACKIT Kubernetes Platform."
  }
}

# Separate from the service account, so that the account depends on no definition below. Every block
# that acts as the account is a child of this one.
resource "meshstack_building_block" "platform_federation" {
  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [var.automation_identity.building_block_ref]
    building_block_definition_version_ref = var.service_account_federation_bbd_version_ref
    display_name                          = "Automation Identity Federation"
    target_ref                            = local.tenant_ref

    inputs = {
      service_account_email = { value = jsonencode(local.service_account_email) }
      federated_building_block_definitions = {
        value = jsonencode(jsonencode(concat([
          module.cluster_integration.building_block_definition.uuid,
          module.git_integration.building_block_definition.uuid,
          module.container_registry_integration.building_block_definition.uuid,
          module.ai_llm_integration.building_block_definition.uuid,
          module.secrets_manager_integration.building_block_definition.uuid,
        ], var.existing == null ? [module.dns_integration.building_block_definition.uuid] : [])))
      }
    }
  }
}
