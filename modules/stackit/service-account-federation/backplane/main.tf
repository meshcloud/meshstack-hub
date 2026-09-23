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

# No organization-scope role below `organization.admin` carries `iam.service-account-federation.create`.
# This role only lets the run grant itself `editor` on the one project it federates in.
resource "stackit_authorization_organization_role_assignment" "member_admin" {
  resource_id = var.organization_id
  role        = "iam.member-admin"
  subject     = stackit_service_account.building_block.email
}
