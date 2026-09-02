resource "random_string" "name_suffix" {
  length  = 5
  upper   = false
  numeric = false
  special = false
}

locals {
  # Strip anything a meshProject identifier cannot carry, then collapse whitespace to dashes. Same
  # sanitizing as the SKE and AKS starterkits.
  sanitized_name = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-]/", ""), "/[\\s]+/", "-"))
  name           = var.add_random_name_suffix ? "${local.sanitized_name}-${random_string.name_suffix.result}" : local.sanitized_name

  # A SINGLE_SELECT input carries only the label, so the reference is resolved here rather than by
  # meshStack. `landing_zone_refs` is validated to contain the key.
  landing_zone_ref = var.landing_zone_refs[var.landing_zone]

  # A service account or an API key has no username to bind a role to.
  creator_is_user = var.creator.type == "User" && var.creator.username != null

  owner_tags = var.tags.project_owner_tag_key == "" ? {} : { (var.tags.project_owner_tag_key) = [var.creator.displayName] }

  # The landing zone decides whether an order gets a network at all; `network` only shapes it, and is
  # null wherever the definition did not offer the input.
  network_enabled = var.network != null && contains(var.network_static.matching_landing_zones, var.landing_zone)
}

resource "meshstack_project" "this" {
  metadata = {
    name               = local.name
    owned_by_workspace = var.workspace_identifier
  }

  spec = {
    display_name = var.name
    tags         = merge(var.tags.project, local.owner_tags)
  }
}

# A project user binding is named, and there is no natural name for this one, so generate a stable
# random id instead of deriving it from inputs that can change.
resource "random_uuid" "binding" {
  lifecycle {
    enabled = local.creator_is_user
  }
}

resource "meshstack_project_user_binding" "creator_to_admin" {
  lifecycle {
    enabled = local.creator_is_user
  }

  metadata = {
    name = random_uuid.binding.result
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace_identifier
    name               = meshstack_project.this.metadata.name
  }

  subject = {
    name = var.creator.username
  }
}

resource "meshstack_tenant" "this" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.this.metadata.name
  }

  spec = {
    platform_ref     = var.platform_ref
    landing_zone_ref = local.landing_zone_ref
  }

  # This orders the destroy, not the create. Deleted in parallel, the tenant and the binding are both
  # the run's first write, so both run the same `INSERT ... ON DUPLICATE KEY UPDATE` on meshStack's
  # Author table for the run's fresh ephemeral API key. The two deadlock, the loser's transaction is
  # marked rollback-only, and its delete returns a 500 that fails the whole destroy run. Ordering them
  # means the first delete creates the Author row and the second one finds it.
  #
  # A band-aid: meshStack does not retry on a deadlock. Remove it once meshStack does.
  #
  # A block ordered on the current definition never gets here, because `deletion_mode = "PURGE"` means
  # no destroy run happens at all. This protects blocks ordered before that change, and anyone running
  # `terraform destroy` over a configuration holding these resources.
  depends_on = [meshstack_project_user_binding.creator_to_admin]
}

# The spoke network lives inside the STACKIT project, and that project is created by the landing
# zone's mandatory building block, which meshStack runs rather than this module. Ordering it here is
# safe because `meshstack_tenant` does not return until the tenant has a `platform_tenant_id`, and
# that field is the mandatory block's output — so by this point the project exists.
resource "meshstack_building_block" "network" {
  lifecycle {
    enabled = local.network_enabled

    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  spec = {
    building_block_definition_version_ref = var.network_static.bbd_version_ref
    display_name                          = "Network ${local.name}"
    target_ref                            = meshstack_tenant.this.ref

    inputs = {
      network_name          = { value = jsonencode(local.name) }
      network_prefix_length = { value = jsonencode(var.network.prefix_length) }
      ipv4_nameservers      = { value = jsonencode(jsonencode(var.network.ipv4_nameservers)) }
    }
  }

  wait_for_completion = true
}
