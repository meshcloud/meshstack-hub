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
      error_message = "No version of the building block definition uses the trusted runner ${each.key}. So the subject of its tokens is unknown. Remove the runner from meshstack.additional_trusted_runner_refs for this definition. Either the definition has only a draft version, whose runner meshStack changes in place. Or other modules get the same list, and this definition never used the runner."
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

# Granted at organization scope: the backplane is deployed before any target project is known, and
# STACKIT cascades organization-level assignments to every project below it. The built-in
# secrets-manager.admin role exists only at project scope, so we define an equivalent custom role.
resource "stackit_authorization_organization_custom_role" "secrets_manager" {
  resource_id = var.organization_id
  name        = var.custom_role_name
  description = "Lets meshStack manage STACKIT Secrets Manager instances in all projects."
  permissions = [
    "secrets-manager.instance.create",
    "secrets-manager.instance.get",
    "secrets-manager.instance.list",
    "secrets-manager.instance.update",
    "secrets-manager.instance.delete",
  ]
}

resource "stackit_authorization_organization_role_assignment" "secrets_manager" {
  resource_id = var.organization_id
  role        = stackit_authorization_organization_custom_role.secrets_manager.name
  subject     = stackit_service_account.building_block.email
}
