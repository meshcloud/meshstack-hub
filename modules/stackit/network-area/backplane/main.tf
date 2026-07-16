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

# network.admin at org scope allows managing network areas and their regions.
# Least-privilege alternative: if STACKIT introduces a narrower "network-area.editor"
# role, prefer that.
resource "stackit_authorization_organization_role_assignment" "network_admin" {
  resource_id = var.organization_id
  role        = "iaas.network.admin"
  subject     = stackit_service_account.building_block.email
}
