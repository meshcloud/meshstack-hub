locals {
  current_runner_uuid    = coalesce(var.runner_uuid, "current")
  original_runner_uuid   = coalesce(var.original_runner_uuid, local.current_runner_uuid)
  identity_provider_name = local.current_runner_uuid == local.original_runner_uuid ? var.name : "${var.name}-${substr(local.current_runner_uuid, 0, 8)}"

  runner_trusts = merge(
    {
      for identity in var.trusted_runner_identities : identity.runner_uuid => {
        issuer   = identity.issuer
        audience = identity.audience
        subject  = identity.subject
      }
    },
    {
      (local.current_runner_uuid) = {
        issuer   = var.workload_identity_federation.issuer
        audience = var.workload_identity_federation.audience
        subject  = var.workload_identity_federation.subject
      }
    },
  )

  runner_issuers        = { for uuid, trust in local.runner_trusts : uuid => trust.issuer }
  original_runner_trust = contains(keys(local.runner_trusts), local.original_runner_uuid) ? local.runner_trusts[local.original_runner_uuid] : null
  other_runner_trusts   = { for uuid, trust in local.runner_trusts : uuid => trust if uuid != local.original_runner_uuid }
}

data "http" "discovery" {
  for_each = local.runner_issuers

  url = "${trimsuffix(each.value, "/")}/.well-known/openid-configuration"

  lifecycle {
    postcondition {
      # try: a body that is no JSON document, or one without an issuer, fails the check as well.
      condition     = self.status_code == 200 && try(jsondecode(self.response_body).issuer, null) == each.value
      error_message = "The issuer's discovery document is unreachable or names a different issuer."
    }
  }
}

data "http" "jwks" {
  for_each = local.runner_issuers

  url = jsondecode(data.http.discovery[each.key].response_body).jwks_uri

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

data "opentelekomcloud_identity_role_v3" "project" {
  for_each = toset(var.project_roles)
  name     = each.key
}

resource "opentelekomcloud_identity_role_assignment_v3" "project_role" {
  for_each = data.opentelekomcloud_identity_role_v3.project

  group_id     = opentelekomcloud_identity_group_v3.building_block.id
  domain_id    = opentelekomcloud_identity_group_v3.building_block.domain_id
  all_projects = true
  role_id      = each.value.id
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
  lifecycle {
    enabled = local.original_runner_trust != null

    precondition {
      condition     = length(var.trusted_runner_identities) == 0 || var.original_runner_uuid != null
      error_message = "A trusted runner needs meshstack.original_runner_ref. Set it to the runner that the definition ran on before it moved to another runner, and never remove it."
    }

    precondition {
      condition     = local.original_runner_trust.subject != null
      error_message = "The building block runner ${local.original_runner_uuid} is a trusted runner, but no version of the definition runs on it, so there is nothing to trust. Remove it from meshstack.trusted_runner_refs."
    }
  }

  name        = var.name
  protocol    = "oidc"
  description = "meshStack runs of one building block definition."
  status      = true

  mapping_rules = jsonencode([
    {
      local  = [{ user = { name = var.name } }, { group = { name = opentelekomcloud_identity_group_v3.building_block.name } }]
      remote = [{ type = "sub", any_one_of = [local.original_runner_trust.subject] }]
    }
  ])

  access_config {
    access_type  = "program"
    provider_url = local.original_runner_trust.issuer
    client_id    = local.original_runner_trust.audience
    signing_key  = data.http.jwks[local.original_runner_uuid].response_body
  }
}

resource "opentelekomcloud_identity_provider" "runner" {
  for_each = local.other_runner_trusts

  lifecycle {
    precondition {
      condition     = length(var.trusted_runner_identities) == 0 || var.original_runner_uuid != null
      error_message = "A trusted runner needs meshstack.original_runner_ref. Set it to the runner that the definition ran on before it moved to another runner, and never remove it."
    }

    precondition {
      condition     = each.value.subject != null
      error_message = "The building block runner ${each.key} is a trusted runner, but no version of the definition runs on it, so there is nothing to trust. Remove it from meshstack.trusted_runner_refs."
    }
  }

  name        = "${var.name}-${substr(each.key, 0, 8)}"
  protocol    = "oidc"
  description = "meshStack runs of one building block definition on runner ${each.key}."
  status      = true

  mapping_rules = jsonencode([
    {
      local  = [{ user = { name = var.name } }, { group = { name = opentelekomcloud_identity_group_v3.building_block.name } }]
      remote = [{ type = "sub", any_one_of = [each.value.subject] }]
    }
  ])

  access_config {
    access_type  = "program"
    provider_url = each.value.issuer
    client_id    = each.value.audience
    signing_key  = data.http.jwks[each.key].response_body
  }
}
