# The automation principal for this building block: one admin-scoped API key, owned by the
# workspace that deploys the starterkit.
#
# It has to be admin-scoped. The building block creates a workspace, a payment method, a project
# and a tenant, and meshStack never grants a building block run's own ephemeral token the `ADM_*`
# permissions those need — the payment method endpoints do not even have a workspace-scoped SAVE.
# An ephemeral, per-run key is therefore not an option either: the authority has to outlive a
# single run, so it belongs to the backplane the platform team applies.
#
# It cannot outlive the backplane, though. meshStack requires an expiry on every API key and caps
# how far out it may sit — 90 days on the instance this was written against, and an instance may
# cap it lower; the 409 it answers with names its own maximum. So the key has to be rolled forward,
# and time_rotating is what makes any apply past half the lifetime roll it: no diff in between, and
# a deployment that applies at least that often never lets the key lapse.
resource "time_rotating" "api_key" {
  rotation_days = floor(var.api_key_lifetime_days / 2)
}

resource "meshstack_api_key" "automation" {
  metadata = {
    owned_by_workspace = var.meshstack_workspace_identifier
  }

  spec = {
    display_name = var.api_key_display_name
    permissions  = local.permissions
    expires_at   = formatdate("YYYY-MM-DD", timeadd(time_rotating.api_key.rfc3339, "${var.api_key_lifetime_days * 24}h"))
  }
}

locals {
  # One triple per meshObject the building block manages. Grouped rather than sorted so a reader
  # can check the list against buildingblock/main.tf resource by resource.
  permissions = concat([
    "ADM_WORKSPACE_LIST", "ADM_WORKSPACE_SAVE", "ADM_WORKSPACE_DELETE",
    "ADM_PAYMENTMETHOD_LIST", "ADM_PAYMENTMETHOD_SAVE", "ADM_PAYMENTMETHOD_DELETE",
    "ADM_PROJECT_LIST", "ADM_PROJECT_SAVE", "ADM_PROJECT_DELETE",
    "ADM_TENANT_LIST", "ADM_TENANT_SAVE", "ADM_TENANT_DELETE",
    "ADM_WORKSPACEPRINCIPALBINDING_LIST", "ADM_WORKSPACEPRINCIPALBINDING_SAVE", "ADM_WORKSPACEPRINCIPALBINDING_DELETE",
    "ADM_PROJECTPRINCIPALROLE_LIST", "ADM_PROJECTPRINCIPALROLE_SAVE", "ADM_PROJECTPRINCIPALROLE_DELETE",
  ], var.additional_api_key_permissions)
}
