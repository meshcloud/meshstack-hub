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
  }

  # The form is flat so that meshPanel can render it; the integration takes the nested shape.
  identity_provider = var.identity_provider == null ? null : {
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
  otc_identity_provider   = local.identity_provider
  role_mapping            = var.role_mapping

  hub = var.hub

  meshstack = {
    owning_workspace_identifier = var.workspace
    location_name               = var.use_global_location ? "global" : meshstack_location.this.metadata.name
    platform_identifier         = local.platform_identifier
    tags                        = local.tags
  }
}
