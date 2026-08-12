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

# postgres-flex.admin at org scope allows creating instances, users and databases in any tenant
# project under the organization. Required because this is a TENANT_LEVEL building block: the
# backplane is deployed once, before the target project of any future instance is known, so
# permissions can't be scoped to a single project ahead of time. STACKIT offers no narrower
# predefined role than postgres-flex.admin for creating instances; a custom role would be the
# least-privilege alternative once the exact permission set is stable.
resource "stackit_authorization_organization_role_assignment" "postgres_flex_admin" {
  resource_id = var.organization_id
  role        = "postgres-flex.admin"
  subject     = stackit_service_account.building_block.email
}
