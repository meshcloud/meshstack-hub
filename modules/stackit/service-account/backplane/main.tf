resource "stackit_service_account" "building_block" {
  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_service_account_federated_identity_provider" "building_block" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
  name                  = "meshstack-${each.key}"
  issuer                = var.workload_identity_federation.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = var.workload_identity_federation.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value
    }
  ]
}

resource "stackit_service_account_federated_identity_provider" "trusted_runner" {
  for_each = { for identity in var.trusted_runner_identities : identity.runner_uuid => identity }

  depends_on = [stackit_service_account_federated_identity_provider.building_block]

  lifecycle {
    precondition {
      condition     = each.value.subject != null
      error_message = "The building block runner ${each.key} is a trusted runner, but no version of the definition runs on it, so there is nothing to trust. Remove it from meshstack.trusted_runner_refs."
    }
  }

  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
  name                  = "trusted-runner-${each.key}"
  issuer                = each.value.issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = each.value.audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value.subject
    }
  ]
}

# Both roles are granted at organization scope because this is a TENANT_LEVEL
# building block: the backplane is deployed once, before the target project of
# any future instance is known, so permissions can't be scoped to a single
# project ahead of time. STACKIT cascades org-level assignments to every project
# under the organization.

# iam.service-account-admin lets the automation identity create and delete the
# application team's service accounts. Federating them is the job of the
# stackit/service-account-federation module.
resource "stackit_authorization_organization_role_assignment" "service_account_admin" {
  resource_id = var.organization_id
  role        = "iam.service-account-admin"
  subject     = stackit_service_account.building_block.email
}

# iam.member-admin lets the automation identity assign project roles to the
# created service accounts. It can assign any project role, including broad ones
# like "owner"; constrain the roles offered to application teams via the
# building block definition input, not here.
resource "stackit_authorization_organization_role_assignment" "member_admin" {
  resource_id = var.organization_id
  role        = "iam.member-admin"
  subject     = stackit_service_account.building_block.email
}
