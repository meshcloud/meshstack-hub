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

# ske.admin is the narrowest predefined role that covers the full cluster lifecycle. The building
# block creates a cluster and a kubeconfig, and meshStack deletes the cluster again when a tenant
# deletes the building block. `ske.editor` grants ten of the eleven ske permissions but not
# `ske.cluster.delete`, so it can create a cluster and never remove it. A custom role is the
# least-privilege alternative once the exact permission set is stable.
#
# The role is assigned at folder scope rather than organization scope. The building block is
# `TENANT_LEVEL`, so it reads its `project_id` from `PLATFORM_TENANT_ID` and the platform team
# deploys this backplane long before it knows which projects tenants will order into. A folder
# covers every project below it, so it keeps that property. Organization scope is not an option
# here: STACKIT's authorization API offers no ske role on an organization, only on folders and
# projects — see backplane/README.md for the calls that establish this.
resource "stackit_authorization_folder_role_assignment" "ske_admin" {
  resource_id = var.folder_id
  role        = "ske.admin"
  subject     = stackit_service_account.building_block.email
}
