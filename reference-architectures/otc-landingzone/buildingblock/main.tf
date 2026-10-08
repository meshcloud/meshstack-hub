locals {
  # The identifier is unique across the whole meshStack instance and lands in the landing zone name,
  # so a playground deployment suffixes it instead of occupying the plain name.
  platform_identifier = var.playground_mode ? "${var.platform_identifier}-${random_string.playground_suffix.result}" : var.platform_identifier

  # IAM is global to the domain, but each region serves its own endpoint.
  auth_url = "https://iam.${var.otc_region}.otc.t-systems.com/v3"

  # The meshPanel Tags form sends each tag map as a list of {key, values} entries.
  tags = {
    landingzone    = { for e in var.tags.landingzone : e.key => e.values }
    building_block = { for e in var.tags.building_block : e.key => e.values }
    project        = { for e in var.tags.project : e.key => e.values }
  }

  owner_tags = var.tags.project_owner_tag_key == "" ? {} : { (var.tags.project_owner_tag_key) = [var.creator.displayName] }

  # The workspace is the source of truth rather than the creator: a landing zone ordered through the
  # meshStack API is authored by a service account, not a person.
  platform_admins = toset([
    for member in var.workspace_members : member.username
    if contains(member.roles, "Workspace Owner") || contains(member.roles, "Workspace Manager")
  ])

  # The form is flat so that meshPanel can render it; the integration takes the nested shape.
  federation_enabled = var.identity_provider != null && var.identity_provider.protocol != null

  identity_provider = !local.federation_enabled ? null : {
    name            = var.identity_provider.name
    protocol        = var.identity_provider.protocol
    email_attribute = var.identity_provider.email_attribute
    metadata        = var.identity_provider.saml_metadata
    oidc = var.identity_provider.protocol != "oidc" ? null : {
      provider_url           = var.identity_provider.oidc_provider_url
      client_id              = var.identity_provider.oidc_client_id
      signing_key            = var.identity_provider.oidc_signing_key
      authorization_endpoint = var.identity_provider.oidc_authorization_endpoint
    }
  }
}

resource "random_string" "playground_suffix" {
  lifecycle {
    enabled = var.playground_mode
  }

  length  = 6
  special = false
  upper   = false
}

resource "meshstack_location" "this" {
  lifecycle {
    enabled = !var.use_global_location
  }

  metadata = {
    name               = local.platform_identifier
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name = local.platform_identifier
    description  = "T Cloud Public location created by the T Cloud Public Landing Zone."
  }
}

module "otc_integration" {
  source = "github.com/meshcloud/meshstack-hub//modules/otc?ref=${var.hub.git_ref}"

  otc_domain_name         = var.otc_domain_name
  otc_region              = var.otc_region
  otc_auth_url            = local.auth_url
  otc_backplane_user_name = "mesh-${local.platform_identifier}"

  # A platform type of its own, named after the platform: its name is unique across the meshStack
  # instance, so a shared `OTC` would make a second landing zone in the same instance fail.
  otc_platform_type        = upper("OTC-${local.platform_identifier}")
  otc_platform_type_create = true
  otc_identity_provider    = local.identity_provider
  role_mapping             = var.role_mapping

  hub = var.hub

  meshstack = {
    owning_workspace_identifier = var.workspace
    location_name               = var.use_global_location ? "global" : meshstack_location.this.metadata.name
    platform_identifier         = local.platform_identifier
    tags = {
      landingzone    = local.tags.landingzone
      building_block = local.tags.building_block
    }
  }
}

# The management project holds what the platform itself runs, starting with the federation mapping
# function. It is an ordinary tenant of the platform this landing zone creates, so the project
# building block provisions it like any other and the platform team reaches it through meshStack.
resource "meshstack_project" "management" {
  metadata = {
    name               = "${local.platform_identifier}-mgmt"
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name              = "T Cloud Public Management: ${local.platform_identifier}"
    payment_method_identifier = var.payment_method_identifier
    tags                      = merge(local.tags.project, local.owner_tags)
  }
}

resource "meshstack_project_user_binding" "management_admin" {
  for_each = local.platform_admins

  # A binding name is capped at 45 characters and unique across the whole meshStack; the hash keeps
  # two platforms sharing a truncated prefix apart.
  metadata = {
    name = format(
      "%s-mgmt-%s",
      substr(local.platform_identifier, 0, 20),
      substr(sha256("${local.platform_identifier}:${each.value}"), 0, 12),
    )
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace
    name               = meshstack_project.management.metadata.name
  }

  subject = {
    name = each.value
  }
}

# wait_for_completion blocks until the project building block has created the T Cloud Public
# project, so the federation mapping building block below has a project to run in.
resource "meshstack_tenant" "management" {
  wait_for_completion = true

  metadata = {
    owned_by_workspace = var.workspace
    owned_by_project   = meshstack_project.management.metadata.name
  }

  spec = {
    platform_ref     = module.otc_integration.platform_ref
    landing_zone_ref = module.otc_integration.landingzone_ref
  }

  # Destroying this tenant deletes the management project and the function in it. Guard a real
  # deployment against an accidental replacement; a playground stays destroyable.
  lifecycle {
    prevent_destroy = !var.playground_mode
  }

  depends_on = [meshstack_project_user_binding.management_admin]
}

module "federation_mapping_integration" {
  lifecycle {
    enabled = local.federation_enabled
  }

  source = "github.com/meshcloud/meshstack-hub//modules/otc/federation-mapping?ref=${var.hub.git_ref}"

  otc_domain_name                       = var.otc_domain_name
  otc_region                            = var.otc_region
  otc_auth_url                          = local.auth_url
  otc_access_key                        = module.otc_integration.backplane_credentials.access_key
  otc_secret_key                        = module.otc_integration.backplane_credentials.secret_key
  otc_mapping_bucket                    = module.otc_integration.federation.mapping_bucket
  otc_identity_provider_name            = module.otc_integration.federation.identity_provider_name
  otc_identity_provider_email_attribute = module.otc_integration.federation.email_attribute
  otc_platform_type                     = module.otc_integration.platform_type_name

  meshstack = { owning_workspace_identifier = var.workspace, tags = local.tags.building_block }
  hub       = var.hub
}

resource "meshstack_building_block" "federation_mapping" {
  lifecycle {
    enabled = local.federation_enabled

    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = {
      uuid = module.federation_mapping_integration.building_block_definition.version_ref.uuid
    }
    display_name = "Federation Mapping"
    target_ref   = meshstack_tenant.management.ref

    # The definition sets every input itself, from the management tenant and as static arguments.
    inputs = {}
  }
}
