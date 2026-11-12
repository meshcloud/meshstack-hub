locals {
  # A cloud that is no longer offered drops out instead of failing the run.
  clouds = { for cloud in var.clouds : cloud => var.metering_jobs[cloud] if contains(keys(var.metering_jobs), cloud) }
}

resource "meshstack_project" "this" {
  metadata = {
    name               = var.project_name
    owned_by_workspace = var.workspace_identifier
  }

  spec = {
    display_name              = var.project_display_name
    payment_method_identifier = var.payment_method.name
    tags                      = var.project_tags
  }
}

resource "meshstack_tenant" "this" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.this.metadata.name
  }

  spec = {
    platform_ref     = var.platform_ref
    landing_zone_ref = var.landing_zone_ref
  }
}

# The identity every metering building block deploys its CronJob with, limited to this namespace.
resource "meshstack_building_block" "service_account" {
  spec = {
    building_block_definition_version_ref = var.service_account_definition_version_ref

    display_name = "Metering Service Account"
    target_ref   = meshstack_tenant.this.ref

    inputs = {
      name         = { value = jsonencode("mesh-metering") }
      cluster_role = { value = jsonencode("edit") }
    }
  }

  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}

# Federates the Kubernetes service account of a metering CronJob that reads its cloud through workload
# identity federation, before the job first runs.
resource "meshstack_building_block" "stackit_workload_identity" {
  for_each = { for cloud, job in local.clouds : cloud => job if job.stackit_workload_identity }

  spec = {
    building_block_definition_version_ref = var.stackit_workload_identity_definition_version_ref

    display_name = "${each.key} Metering Workload Identity"
    target_ref   = meshstack_tenant.this.ref

    inputs = {
      kubernetes_service_account_name = { value = jsonencode(each.value.name) }
    }
  }

  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}

# Deselecting a cloud later deletes its metering, selecting one adds it next to the others.
resource "meshstack_building_block" "metering" {
  for_each   = local.clouds
  depends_on = [meshstack_building_block.stackit_workload_identity]

  spec = {
    building_block_definition_version_ref = var.cronjob_definition_version_ref

    display_name               = "${each.key} Metering"
    target_ref                 = meshstack_tenant.this.ref
    parent_building_block_refs = [meshstack_building_block.service_account.ref]

    inputs = merge(
      {
        name                = { value = jsonencode(each.value.name) }
        image               = { value = jsonencode(each.value.image) }
        schedule            = { value = jsonencode(var.schedule) }
        env                 = { value = jsonencode(jsonencode(each.value.env)) }
        secret_env_revision = { value = jsonencode(var.credentials_revision) }
        secret_env = { sensitive = {
          secret_value   = jsonencode(var.metering_secrets[each.key])
          secret_version = tostring(var.credentials_revision)
        } }
      },
      each.value.service_account_token == null ? {} : {
        service_account_token = { value = jsonencode(jsonencode(each.value.service_account_token)) }
      },
    )
  }

  wait_for_completion = true

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}
