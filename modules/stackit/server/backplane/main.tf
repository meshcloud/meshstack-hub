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

# `editor` is the broad project role that covers every IaaS resource the building block creates —
# servers, networks, network interfaces, public IPs, security groups and key pairs. No narrower
# predefined STACKIT role spans all of those, so scoping is done per project (resource_id) rather
# than by role: a tenant-level block only ever touches the one project it is ordered in.
resource "stackit_authorization_project_role_assignment" "editor" {
  resource_id = var.project_id
  role        = "editor"
  subject     = stackit_service_account.building_block.email
}
