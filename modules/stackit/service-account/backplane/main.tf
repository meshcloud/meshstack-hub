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

# Both roles are granted at organization scope because this is a TENANT_LEVEL
# building block: the backplane is deployed once, before the target project of
# any future instance is known, so permissions can't be scoped to a single
# project ahead of time. STACKIT cascades org-level assignments to every project
# under the organization.

# iam.service-account-admin lets the automation identity create and delete the
# application team's service accounts. It does NOT cover their federated identity
# providers: it carries iam.service-account.{create,delete,get,list} and nothing
# else, and no organization-scope role below `organization.admin` carries
# iam.service-account-federation.create. The building block grants itself the
# project role it needs for that; see its main.tf.
resource "stackit_authorization_organization_role_assignment" "service_account_admin" {
  resource_id = var.organization_id
  role        = "iam.service-account-admin"
  subject     = stackit_service_account.building_block.email
}

# iam.member-admin lets the automation identity assign project roles to the
# created service accounts. It can assign any project role, including broad ones
# like "owner"; constrain the roles offered to application teams via the
# building block definition input, not here.
resource "stackit_authorization_organization_role_assignment" "member_admin" {
  resource_id = var.organization_id
  role        = "iam.member-admin"
  subject     = stackit_service_account.building_block.email
}
