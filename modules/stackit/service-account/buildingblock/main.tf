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

# `editor` carries `iam.service-account-federation.create`. The grant is made here, once, because each
# federation block of the account would make the same one, and STACKIT rejects a duplicate.
resource "stackit_authorization_project_role_assignment" "federation_backplane" {
  resource_id = var.project_id
  role        = "editor"
  subject     = var.federation_backplane_email
}
