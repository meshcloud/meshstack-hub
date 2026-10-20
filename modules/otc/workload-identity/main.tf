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
  description = "meshStack building block runs signed in through workload identity federation."
}

data "opentelekomcloud_identity_role_v3" "domain" {
  for_each = toset(var.domain_roles)
  name     = each.key
}

resource "opentelekomcloud_identity_role_assignment_v3" "domain_role" {
  for_each = data.opentelekomcloud_identity_role_v3.domain

  group_id  = opentelekomcloud_identity_group_v3.building_block.id
  domain_id = opentelekomcloud_identity_group_v3.building_block.domain_id
  role_id   = each.value.id
}

resource "opentelekomcloud_identity_role_v3" "policy" {
  for_each = var.policies

  display_name = "${var.name}-${each.key}"
  description  = "Permissions of the meshStack building block that signs in as ${var.name}."
  # Global services take a domain-level policy; everything else a project-level one.
  display_layer = contains(["domain", "obs"], each.value.scope) ? "domain" : "project"

  statement {
    effect = "Allow"
    action = each.value.actions
  }
}

resource "opentelekomcloud_identity_role_assignment_v3" "policy_domain" {
  for_each = { for k, p in var.policies : k => p if p.scope == "domain" }

  group_id  = opentelekomcloud_identity_group_v3.building_block.id
  domain_id = opentelekomcloud_identity_group_v3.building_block.domain_id
  role_id   = opentelekomcloud_identity_role_v3.policy[each.key].id
}

# OBS takes effect through the `MOS` project, which is how the upstream OBS modules grant it too.
data "opentelekomcloud_identity_project_v3" "obs" {
  name = "MOS"
}

resource "opentelekomcloud_identity_role_assignment_v3" "policy_obs" {
  for_each = { for k, p in var.policies : k => p if p.scope == "obs" }

  group_id   = opentelekomcloud_identity_group_v3.building_block.id
  project_id = data.opentelekomcloud_identity_project_v3.obs.id
  role_id    = opentelekomcloud_identity_role_v3.policy[each.key].id
}

data "opentelekomcloud_identity_project_v3" "region" {}

resource "opentelekomcloud_identity_role_assignment_v3" "policy_region" {
  for_each = { for k, p in var.policies : k => p if p.scope == "region" }

  group_id   = opentelekomcloud_identity_group_v3.building_block.id
  project_id = data.opentelekomcloud_identity_project_v3.region.id
  role_id    = opentelekomcloud_identity_role_v3.policy[each.key].id
}

resource "opentelekomcloud_identity_role_assignment_v3" "policy_all_projects" {
  for_each = { for k, p in var.policies : k => p if p.scope == "all_projects" }

  group_id     = opentelekomcloud_identity_group_v3.building_block.id
  domain_id    = opentelekomcloud_identity_group_v3.building_block.domain_id
  all_projects = true
  role_id      = opentelekomcloud_identity_role_v3.policy[each.key].id
}

# Programmatic access only. The one rule matches only runs of the definition whose subject it names,
# and signs them in as one virtual user in the group above.
resource "opentelekomcloud_identity_provider" "building_block" {
  name        = var.name
  protocol    = "oidc"
  description = "meshStack runs of one building block definition."
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
