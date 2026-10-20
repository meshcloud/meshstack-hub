data "http" "discovery" {
  url = "${trimsuffix(var.workload_identity_federation.issuer, "/")}/.well-known/openid-configuration"

  lifecycle {
    postcondition {
      # try: a body that is no JSON document, or one without an issuer, fails the check as well.
      condition     = self.status_code == 200 && try(jsondecode(self.response_body).issuer, null) == var.workload_identity_federation.issuer
      error_message = "The issuer's discovery document is unreachable or names a different issuer."
    }
  }
}

data "http" "jwks" {
  url = jsondecode(data.http.discovery.response_body).jwks_uri

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "The issuer's signing keys answered HTTP ${self.status_code}."
    }
  }
}

resource "opentelekomcloud_identity_group_v3" "building_block" {
  name        = var.name
  description = "meshStack OBS bucket building block runs, signed in through workload identity federation."
}

# The upstream module creates an IAM user, a group and custom roles for every bucket, which only
# Security Administrator may do.
data "opentelekomcloud_identity_role_v3" "security_administrator" {
  name = "secu_admin"
}

resource "opentelekomcloud_identity_role_assignment_v3" "security_administrator" {
  group_id  = opentelekomcloud_identity_group_v3.building_block.id
  domain_id = opentelekomcloud_identity_group_v3.building_block.domain_id
  role_id   = data.opentelekomcloud_identity_role_v3.security_administrator.id
}

# OBS is a global service: a domain-level policy takes effect through the `MOS` project, as the
# upstream module assigns its own bucket role.
data "opentelekomcloud_identity_project_v3" "obs" {
  name = "MOS"
}

resource "opentelekomcloud_identity_role_v3" "obs" {
  display_name  = "${var.name}-obs"
  description   = "Creates and deletes the OBS buckets of the meshStack OBS bucket building block."
  display_layer = "domain"

  statement {
    effect = "Allow"
    action = ["obs:*:*"]
  }
}

resource "opentelekomcloud_identity_role_assignment_v3" "obs" {
  group_id   = opentelekomcloud_identity_group_v3.building_block.id
  project_id = data.opentelekomcloud_identity_project_v3.obs.id
  role_id    = opentelekomcloud_identity_role_v3.obs.id
}

# KMS keys live in the region's project, which the provider of this module targets.
data "opentelekomcloud_identity_project_v3" "region" {}

resource "opentelekomcloud_identity_role_v3" "kms" {
  display_name  = "${var.name}-kms"
  description   = "Creates and deletes the bucket keys of the meshStack OBS bucket building block."
  display_layer = "project"

  statement {
    effect = "Allow"
    action = ["kms:*:*"]
  }
}

resource "opentelekomcloud_identity_role_assignment_v3" "kms" {
  group_id   = opentelekomcloud_identity_group_v3.building_block.id
  project_id = data.opentelekomcloud_identity_project_v3.region.id
  role_id    = opentelekomcloud_identity_role_v3.kms.id
}

# Programmatic access only: the pre-run script exchanges the run token for temporary credentials.
# Only runs of this definition match the rule, as one virtual user in the group above.
resource "opentelekomcloud_identity_provider" "building_block" {
  name        = var.name
  protocol    = "oidc"
  description = "meshStack runs of the OBS bucket building block definition."
  status      = true

  mapping_rules = jsonencode([
    {
      local  = [{ user = { name = var.name } }, { group = { name = opentelekomcloud_identity_group_v3.building_block.name } }]
      remote = [{ type = "sub", any_one_of = [var.workload_identity_federation.subject] }]
    }
  ])

  access_config {
    access_type  = "program"
    provider_url = var.workload_identity_federation.issuer
    client_id    = var.workload_identity_federation.audience
    signing_key  = data.http.jwks.response_body
  }
}
