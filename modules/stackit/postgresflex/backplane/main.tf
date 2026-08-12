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

# postgres-flex.admin allows creating and deleting instances, databases and users. The building
# block runs with deletion_mode DELETE, so it needs the delete permissions as well, and
# postgres-flex.editor grants none of them: it can create an instance, a database and a user, but
# it cannot remove any of the three. A custom role would be the least-privilege alternative once
# the exact permission set is stable.
#
# The role is assigned at folder scope rather than organization scope. The building block is
# `TENANT_LEVEL`, so it reads its `project_id` from `PLATFORM_TENANT_ID` and the platform team
# deploys this backplane long before it knows which projects tenants will order into. A folder
# covers every project below it, so it keeps that property. Organization scope is not an option
# here: STACKIT's authorization API offers no postgres-flex role on an organization, only on
# folders and projects — see backplane/README.md for the calls that establish this.
resource "stackit_authorization_folder_role_assignment" "postgres_flex_admin" {
  resource_id = var.folder_id
  role        = "postgres-flex.admin"
  subject     = stackit_service_account.building_block.email
}
