variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    meshstack = object({
      project_identifier_suffix = string
    })
  })
  nullable = false

  # Only the hub mode exists. The building block creates the tenant's OVHcloud project, so every run
  # needs a fresh tenant: a tenant's platform tenant id is set once and never changes, so a
  # long-lived fixture tenant would point at the project the first run deleted. The invocation
  # protocol cannot hand a foundation's platform and landing zone to the test to create one there.
}

# The runner exports them as TF_VAR_<name>. The OVHcloud provider is not configured here: the
# building block receives them as static inputs of the definition.
variable "ovh_application_key" {
  type      = string
  default   = null
  sensitive = true
}

variable "ovh_application_secret" {
  type      = string
  default   = null
  sensitive = true
}

variable "ovh_consumer_key" {
  type      = string
  default   = null
  sensitive = true

  validation {
    condition     = alltrue([for secret in [var.ovh_application_key, var.ovh_application_secret, var.ovh_consumer_key] : secret != null])
    error_message = "ovh_application_key, ovh_application_secret and ovh_consumer_key must be set; the runner exports them as TF_VAR_<name>."
  }
}

locals {
  # Capped at 30 characters, and the instance requires a stage suffix, which the test context
  # publishes.
  project_identifier = "${var.test_context.run_id}-prj${var.test_context.meshstack.project_identifier_suffix}"

  # A platform identifier can never be reused in meshStack, not even after deletion.
  platform_identifier = "${var.test_context.run_id}-ovh"

  # Tags the test workspace requires. The landing zone offers every value so it accepts the
  # project's narrower selection.
  landingzone_tags = {
    confidentiality = ["Public", "Internal", "Confidential"]
    environment     = ["dev", "qa", "prod"]
  }

  project_tags = {
    confidentiality = ["Public"]
    environment     = ["dev"]
  }
}

module "ovh_project" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      landingzone    = local.landingzone_tags
      building_block = {}
    }
    platform_identifier = local.platform_identifier
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} OVHcloud Project"

  # Created per run rather than assumed to exist, so the test does not depend on the instance.
  # Both name and display name are unique across the instance.
  ovh_platform_type_create       = true
  ovh_platform_type              = upper("${var.test_context.run_id}-OVH")
  ovh_platform_type_display_name = "${var.test_context.run_id} OVHcloud"

  ovh_application_key     = var.ovh_application_key
  ovh_application_secret  = var.ovh_application_secret
  ovh_consumer_key        = var.ovh_consumer_key
  ovh_credentials_version = "1"
}

resource "meshstack_project" "this" {
  metadata = {
    name               = local.project_identifier
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name = "${var.test_context.run_id} OVHcloud Project"
    tags         = local.project_tags
  }
}

# The project has no user bindings, so `users` arrives empty and the building block creates no IAM
# policy. Matching members to local OVHcloud users needs a meshStack user and an OVHcloud user that
# belong together, which the smoke-test instance does not have; that path is not covered here.

resource "meshstack_tenant" "this" {
  # The landing zone has to outlive the tenant's delete run.
  depends_on = [module.ovh_project]

  # The platform tenant id comes from the building block ordered below, so there is nothing to wait
  # for on create. On destroy, wait: meshStack deletes tenants asynchronously and refuses to delete
  # the project while its tenant is still being deleted.
  wait_for_completion = false
  wait_for_deletion   = true

  metadata = {
    owned_by_workspace = var.test_context.workspace
    owned_by_project   = meshstack_project.this.metadata.name
  }

  spec = {
    platform_ref     = module.ovh_project.platform_ref
    landing_zone_ref = module.ovh_project.landingzone_ref
  }
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run deletes the OVHcloud project and needs the definition, its
  # credentials and the tenant to still exist.
  depends_on = [module.ovh_project, meshstack_tenant.this]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.ovh_project.building_block_definition.version_ref

    display_name = "${var.test_context.run_id} OVHcloud Project"
    target_ref   = meshstack_tenant.this.ref

    # Every input is static or assigned by meshStack.
    inputs = {}
  }
}

output "project_building_block" {
  description = "The OVHcloud Project building block ordered for the test tenant."
  value       = meshstack_building_block.this
}

output "expected_project_description" {
  description = "Description the building block gives the OVHcloud project."
  value       = "${var.test_context.workspace}-${local.project_identifier}"
}

# Read back after the run: the tenant resource's own state predates the building block, which is
# what reports the platform tenant id.
data "meshstack_tenant" "this" {
  depends_on = [meshstack_building_block.this]

  metadata = {
    owned_by_workspace  = var.test_context.workspace
    owned_by_project    = meshstack_project.this.metadata.name
    platform_identifier = "${local.platform_identifier}.global"
  }
}

output "platform_tenant_id" {
  description = "OVHcloud project id the building block reported back to meshStack as the tenant's platform tenant id."
  value       = data.meshstack_tenant.this.spec.platform_tenant_id
}
