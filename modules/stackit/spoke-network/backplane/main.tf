resource "stackit_service_account" "backplane" {
  project_id = var.project_id
  name       = "mesh-spoke-network"
}

resource "stackit_service_account_federated_identity_provider" "backplane" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  project_id            = var.project_id
  service_account_email = stackit_service_account.backplane.email
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

# network.admin at org scope allows managing routing tables in the network area
# and routed networks in tenant projects. Least-privilege alternative: if STACKIT
# introduces a narrower "network.editor" role, prefer that.
resource "stackit_authorization_organization_role_assignment" "network_admin" {
  resource_id = var.organization_id
  role        = "iaas.network.admin"
  subject     = stackit_service_account.backplane.email
}
