locals {
  # The nested platform takes the plain platform identifier for its own Kubernetes platform and location.
  accelerator_platform_name = "${local.platform_identifier}-stackit"
}

resource "meshstack_location" "accelerator" {
  lifecycle {
    enabled = local.accelerator && !var.use_global_location
  }

  metadata = {
    name               = local.accelerator_platform_name
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = local.accelerator_platform_name
    description  = "Location of the STACKIT Landing Zone Accelerator project of the STACKIT Kubernetes Platform ${local.platform_identifier}."
  }
}

# Of type STACKIT, so the STACKIT definitions the platform orders accept its tenant. It replicates
# nothing: the accelerator owns the project.
resource "meshstack_platform" "accelerator" {
  lifecycle {
    enabled        = local.accelerator
    ignore_changes = [spec.availability]
  }

  metadata = {
    name               = local.accelerator_platform_name
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = "STACKIT Accelerator Project ${local.platform_identifier}"
    description  = "STACKIT project of the STACKIT Landing Zone Accelerator that the STACKIT Kubernetes Platform ${local.platform_identifier} runs in."
    endpoint     = "https://portal.stackit.cloud"

    location_ref = var.use_global_location ? { name = "global" } : meshstack_location.accelerator.ref

    availability = {
      restriction              = "PRIVATE"
      publication_state        = "UNPUBLISHED"
      restricted_to_workspaces = [var.workspace]
    }

    config = {
      custom = {
        platform_type_ref = { name = "STACKIT" }
      }
    }
  }
}

resource "meshstack_landingzone" "accelerator" {
  lifecycle {
    enabled = local.accelerator
  }

  metadata = {
    name               = local.accelerator_platform_name
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name                  = "STACKIT Accelerator Project ${local.platform_identifier}"
    description                   = "Imports the STACKIT Landing Zone Accelerator project of the STACKIT Kubernetes Platform ${local.platform_identifier}."
    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_ref = meshstack_platform.accelerator.ref

    platform_properties = {
      custom = {}
    }
  }
}
