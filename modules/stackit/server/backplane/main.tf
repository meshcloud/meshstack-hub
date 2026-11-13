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

# iaas.admin at org scope lets the building block create a VM and its network, security group,
# public IP and key pair in any tenant project under the organization. Required because this is a
# TENANT_LEVEL building block: the backplane is deployed once, before the target project of any
# future VM is known, so permissions can't be scoped to a single project ahead of time. iaas.admin
# is the narrowest predefined role that spans both compute and network and exists at org scope
# (compute.admin is project-only); prefer a narrower role here if STACKIT ever introduces one.
resource "stackit_authorization_organization_role_assignment" "iaas_admin" {
  resource_id = var.organization_id
  role        = "iaas.admin"
  subject     = stackit_service_account.building_block.email
}
