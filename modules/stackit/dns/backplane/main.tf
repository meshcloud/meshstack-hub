# ─────────────────────────────────────────────────────────────────────────────
# One identity, one or two STACKIT projects
#
# On the usual path the building block writes into one project: it creates the zone, its records
# and the DNS service account there. On the delegation path, which only works for a customer-owned
# domain, it also writes the NS record into the platform team's own project, which owns the parent
# zone.
#
# It reaches both with a single identity and a single provider configuration, because STACKIT
# credentials are not bound to a project. A service account belongs to the project it was created
# in, but every resource carries its own `project_id` and access is decided by the role assignments
# the account holds on the target resource.
#
# So the backplane creates one service account and grants it the roles below at organization scope.
# Organization scope is required because the building block is `TENANT_LEVEL`: the target project
# of a future order is unknown when the platform team deploys this backplane. It also happens to
# cover the parent zone's project on the delegation path, as long as that project lives under the
# same organization.
# ─────────────────────────────────────────────────────────────────────────────

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

# dns.admin allows creating and deleting zones and record sets. The building block needs it in the
# project the zone lives in, and on the delegation path also in the parent zone's project.
resource "stackit_authorization_organization_role_assignment" "dns_admin" {
  resource_id = var.organization_id
  role        = "dns.admin"
  subject     = stackit_service_account.building_block.email
}

# iam.member-admin allows assigning roles. The building block uses it to give the DNS service
# account it creates the `dns.admin` role on the zone's project and nothing beyond it.
# modules/stackit/project/backplane grants the same role for the same purpose.
resource "stackit_authorization_organization_role_assignment" "member_admin" {
  resource_id = var.organization_id
  role        = "iam.member-admin"
  subject     = stackit_service_account.building_block.email
}

# ── Creating service accounts in tenant projects ─────────────────────────────
#
# The building block also creates a service account and a service account key, which cert-manager
# and ExternalDNS authenticate with. STACKIT's predefined role for creating service accounts could
# not be established from public documentation, so this module does not name one — see
# backplane/README.md. Put whatever role your organization uses into
# `additional_organization_roles` rather than widening the two roles above.
resource "stackit_authorization_organization_role_assignment" "additional" {
  for_each = toset(var.additional_organization_roles)

  resource_id = var.organization_id
  role        = each.value
  subject     = stackit_service_account.building_block.email
}
