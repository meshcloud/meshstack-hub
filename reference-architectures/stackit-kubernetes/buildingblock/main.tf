locals {
  # The identifier is unique across the whole meshStack instance and lands in the platform name, the
  # location and the STACKIT project, so a playground deployment suffixes it instead of occupying the
  # plain name.
  platform_identifier = var.playground_mode ? "${var.platform_identifier}-${random_string.playground_suffix.result}" : var.platform_identifier

  # STACKIT caps a service account name at 20 characters and rejects one ending in a dash, so cutting
  # the identifier to length can produce an invalid name. Cut shorter instead, drop whatever dashes
  # the cut exposed, and end with a hash of the full identifier so two names sharing a prefix stay
  # apart. A name that already fits passes through untouched.
  platform_service_account_name = length(local.platform_identifier) <= 20 ? local.platform_identifier : format(
    "%s-%s",
    replace(substr(local.platform_identifier, 0, 15), "/-+$/", ""),
    substr(sha256(local.platform_identifier), 0, 4)
  )

  project_identifier = coalesce(var.project_identifier, "${local.platform_identifier}-ske")

  project_display_name = coalesce(
    local.imports.project == null ? null : local.imports.project.display_name,
    "STACKIT Kubernetes Platform: ${local.platform_identifier}"
  )

  # Deleting a playground leaves what it adopted in place. A production platform deletes it like
  # anything it created.
  release_imports_on_destroy = var.playground_mode && local.imports.project != null

  owner_tags = var.tags.project_owner_tag_key == "" ? {} : { (var.tags.project_owner_tag_key) = [var.creator.displayName] }

  platform_admins = toset([
    for member in var.workspace_members : member.username
    if contains(member.roles, "Workspace Owner") || contains(member.roles, "Workspace Manager")
  ])

  stackit_project_id = module.tenant.tenant.spec.platform_tenant_id
}

resource "random_string" "playground_suffix" {
  lifecycle {
    enabled = var.playground_mode
  }

  length  = 6
  special = false
  upper   = false
}

module "project" {
  source = "./modules/project"

  release_on_destroy = local.release_imports_on_destroy

  metadata = {
    name               = local.project_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name              = local.project_display_name
    payment_method_identifier = var.payment_method_identifier
    tags                      = merge(var.tags.project, local.owner_tags)
  }
}

moved {
  from = meshstack_project.platform
  to   = module.project.meshstack_project.this
}

# Without these the platform's own project has no human members, and everything the architecture
# creates below onboards its project users: the container registry grants them a STACKIT registry
# role, which is what makes the Harbor project visible to them.
#
# The workspace is the source of truth rather than the creator: `AUTHOR` reports whoever ordered the
# building block, and a platform ordered through the meshStack API — from a foundation repository,
# say — is authored by a service account, not a person.
resource "meshstack_project_user_binding" "admin" {
  for_each = local.platform_admins

  # A binding name is capped at 45 characters and has to be unique across the whole meshStack, which
  # a username spelled out does not fit into. The identifier stays in front so the binding is still
  # recognisable, and the hash covers the full identifier and username so two platforms sharing a
  # truncated prefix cannot collide.
  metadata = {
    name = format(
      "%s-admin-%s",
      substr(local.platform_identifier, 0, 20),
      substr(sha256("${local.platform_identifier}:${each.value}"), 0, 12),
    )
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace
    name               = module.project.project.metadata.name
  }

  subject = {
    name = each.value
  }
}

# Provisions the STACKIT project through the landing zone platform's replication. wait_for_completion makes
# the run block until the project exists, so spec.platform_tenant_id (the STACKIT project id) is set.
module "tenant" {
  source = "./modules/tenant"

  release_on_destroy = local.release_imports_on_destroy

  # Destroying this tenant deletes the STACKIT project the whole platform runs in. Guard a real
  # deployment against an accidental replacement; a playground stays destroyable.
  prevent_destroy = !var.playground_mode

  wait_for_completion = true

  metadata = {
    owned_by_workspace = var.workspace
    owned_by_project   = module.project.project.metadata.name
  }

  spec = {
    platform_ref     = var.landingzone.platform_ref
    landing_zone_ref = var.landingzone.landingzone_refs[var.landingzone_variant]
  }
}

moved {
  from = meshstack_tenant.stackit_project
  to   = module.tenant.meshstack_tenant.this
}
