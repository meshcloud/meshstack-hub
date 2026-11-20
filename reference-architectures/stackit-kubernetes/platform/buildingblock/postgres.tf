module "postgres_integration" {
  lifecycle {
    enabled = var.postgres != null
  }

  source = "github.com/meshcloud/meshstack-hub//modules/stackit/postgres?ref=${var.hub.git_ref}"

  stackit_project_id            = var.stackit_project_id
  stackit_service_account_email = local.service_account_email

  meshstack = { owning_workspace_identifier = var.workspace, tags = var.tags.building_block, runner_ref = local.runner_ref }
  hub       = local.platform_hub
}

resource "meshstack_building_block" "postgres" {
  for_each = var.postgres == null ? {} : var.stages

  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }

  spec = {
    parent_building_block_refs            = [meshstack_building_block.cluster.ref, meshstack_building_block.platform_federation.ref]
    building_block_definition_version_ref = module.postgres_integration.building_block_definition.version_ref
    display_name                          = "Shared PostgreSQL ${each.key}"
    target_ref                            = local.tenant_ref

    inputs = {
      instance_name         = { value = jsonencode("shared-${each.key}") }
      flavor                = { value = jsonencode(var.postgres.flavor) }
      replicas              = { value = jsonencode(contains(var.postgres.ha_stages, each.key) ? "3" : "1") }
      storage_class         = { value = jsonencode("premium-perf2-stackit") }
      storage_size          = { value = jsonencode(var.postgres.storage_size) }
      postgres_version      = { value = jsonencode("17") }
      backup_schedule       = { value = jsonencode("0 2 * * *") }
      backup_retention_days = { value = jsonencode(32) }
      acl                   = { value = jsonencode(jsonencode(local.cluster_egress_address_ranges)) }
    }
  }
}

locals {
  cluster_egress_address_ranges = jsondecode(jsondecode(meshstack_building_block.cluster.status.outputs["egress_address_ranges"].value))

  postgres_instances = {
    for stage, instance in meshstack_building_block.postgres : stage => {
      building_block_uuid = instance.metadata.uuid
      instance_id         = jsondecode(instance.status.outputs["instance_id"].value)
      host                = jsondecode(instance.status.outputs["host"].value)
      port                = jsondecode(instance.status.outputs["port"].value)
    }
  }
}
