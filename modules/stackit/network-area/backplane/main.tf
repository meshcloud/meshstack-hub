resource "stackit_service_account" "building_block" {
  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_service_account_federated_identity_provider" "building_block" {
  for_each = { for index, identity in var.workload_identity_federations : tostring(index) => identity }

  project_id            = var.project_id
  service_account_email = stackit_service_account.building_block.email
  name                  = "meshstack-${each.key}"
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

# iaas.network-area.admin (org scope) manages network areas; iaas.network.admin only covers project networks.
resource "stackit_authorization_organization_role_assignment" "network_admin" {
  resource_id = var.organization_id
  role        = "iaas.network-area.admin"
  subject     = stackit_service_account.building_block.email
}
