# The identity the workloads act as. Each building block federates it with the service account
# token of one Kubernetes service account, so no key exists.
resource "stackit_service_account" "workload" {
  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_authorization_organization_role_assignment" "workload" {
  for_each = toset(var.organization_roles)

  resource_id = var.organization_id
  role        = each.value
  subject     = stackit_service_account.workload.email
}

resource "stackit_authorization_project_role_assignment" "workload" {
  for_each = toset(var.project_roles)

  resource_id = var.project_id
  role        = each.value
  subject     = stackit_service_account.workload.email
}

# The identity the building block runs act as. It needs nothing but adding and removing the
# federations of the workload service account.
resource "stackit_service_account" "building_block" {
  project_id = var.project_id
  name       = "${var.service_account_name}-bb"
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

# `editor` on the service account itself carries the `iam.service-account-federation.*` permissions
# for that account only, where `editor` on the project would cover the whole project.
resource "stackit_authorization_service_account_role_assignment" "federation_admin" {
  resource_id = stackit_service_account.workload.service_account_id
  role        = "editor"
  subject     = stackit_service_account.building_block.email
}
