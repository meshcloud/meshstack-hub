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
      value    = "api://AzureADTokenExchange"
    },
    {
      item     = "sub"
      operator = "equals"
      value    = each.value
    }
  ]
}

resource "stackit_authorization_organization_role_assignment" "project_admin" {
  resource_id = var.organization_id
  role        = "resource-manager.admin"
  subject     = stackit_service_account.building_block.email
}

moved {
  from = stackit_authorization_organization_role_assignment.member_admin
  to   = stackit_authorization_organization_role_assignment.member_admin[0]
}

resource "stackit_authorization_organization_role_assignment" "member_admin" {
  count = var.organization_onboarding_enabled ? 1 : 0

  resource_id = var.organization_id
  role        = "iam.member-admin"
  subject     = stackit_service_account.building_block.email
}
