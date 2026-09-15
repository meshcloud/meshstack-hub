resource "stackit_service_account" "this" {
  project_id = var.project_id
  name       = var.service_account_name
}

resource "stackit_authorization_project_role_assignment" "this" {
  for_each = toset(var.roles)

  resource_id = var.project_id
  role        = each.value
  subject     = stackit_service_account.this.email
}

resource "stackit_service_account_federated_identity_provider" "this" {
  for_each = { for i, f in var.federated_identities : tostring(i) => f }

  project_id            = var.project_id
  service_account_email = stackit_service_account.this.email
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
