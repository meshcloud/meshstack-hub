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
