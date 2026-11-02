locals {
  tenant_ref = { kind = "meshTenant", uuid = var.tenant_uuid }

  service_account_email = var.automation_identity.service_account_email

  kubernetes_platform_imports = var.imports.kubernetes_platform != null ? var.imports.kubernetes_platform : {
    platform_name     = null
    location_name     = null
    landingzone_names = {}
  }

  platform_name = coalesce(local.kubernetes_platform_imports.platform_name, var.platform_identifier)

  create_location = !var.use_global_location && local.kubernetes_platform_imports.location_name == null
  location_name   = local.create_location ? meshstack_location.this.metadata.name : coalesce(local.kubernetes_platform_imports.location_name, "global")

  stage_names = { dev = "Development", prod = "Production" }

  landing_zones = {
    for stage, cfg in var.stages : stage => {
      name         = lookup(local.kubernetes_platform_imports.landingzone_names, stage, "${var.platform_identifier}-namespace-${stage}")
      display_name = "SKE Kubernetes Namespace – ${lookup(local.stage_names, stage, title(stage))}"
      description  = "Landing zone for ${lower(lookup(local.stage_names, stage, stage))} workloads."
      tags         = cfg.landingzone
      quotas       = cfg.quotas
    }
  }

  stage_project_tags = {
    for stage, cfg in var.stages : stage => merge(var.tags.starterkit_project, cfg.project)
  }

  secrets_manager_instance_id = terraform_data.secrets_manager_instance_id.output

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

  secrets_path_prefix = "${var.platform_identifier}/"

  output_to_vault = jsonencode(merge(local.secrets_manager_writer, { path_prefix = local.secrets_path_prefix }))
}

resource "meshstack_location" "this" {
  lifecycle {
    enabled = local.create_location
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
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
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
          module.dns_integration.building_block_definition.uuid,
        ])))
      }
    }
  }
}
