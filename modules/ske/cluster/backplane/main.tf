resource "stackit_service_account" "building_block" {
  count = var.enabled ? 1 : 0

  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_service_account_federated_identity_provider" "building_block" {
  for_each = var.enabled ? { for i, s in var.workload_identity_federation.subjects : tostring(i) => s } : {}

  project_id            = var.project_id
  service_account_email = one(stackit_service_account.building_block[*].email)
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

# Assigned on the landing-zone folder, not the project: the SKE cluster's project is provisioned at
# order time inside this folder, so a folder-scoped grant is inherited down to it. Folder scope also
# means the platform team only needs rights on their folder, not the whole organization — and unlike
# organization scope, STACKIT service roles such as `ske.admin` are valid here.
resource "stackit_authorization_folder_role_assignment" "this" {
  for_each = var.enabled ? toset(var.roles) : toset([])

  resource_id = var.folder_id
  role        = each.value
  subject     = one(stackit_service_account.building_block[*].email)
}
