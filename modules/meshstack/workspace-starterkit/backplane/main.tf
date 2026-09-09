# meshStack requires an expiry on every API key and caps how far out it may sit, so the key cannot
# simply outlive the backplane. Rotating at half the lifetime means any apply in that window rolls
# the expiry forward, with no diff in between. See ./README.md.
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
  # Grouped per meshObject, so the list reads against ../buildingblock/main.tf resource by resource.
  permissions = concat([
    "ADM_WORKSPACE_LIST", "ADM_WORKSPACE_SAVE", "ADM_WORKSPACE_DELETE",
    "ADM_PAYMENTMETHOD_LIST", "ADM_PAYMENTMETHOD_SAVE", "ADM_PAYMENTMETHOD_DELETE",
    "ADM_PROJECT_LIST", "ADM_PROJECT_SAVE", "ADM_PROJECT_DELETE",
    "ADM_TENANT_LIST", "ADM_TENANT_SAVE", "ADM_TENANT_DELETE",
    "ADM_WORKSPACEPRINCIPALBINDING_LIST", "ADM_WORKSPACEPRINCIPALBINDING_SAVE", "ADM_WORKSPACEPRINCIPALBINDING_DELETE",
    "ADM_PROJECTPRINCIPALROLE_LIST", "ADM_PROJECTPRINCIPALROLE_SAVE", "ADM_PROJECTPRINCIPALROLE_DELETE",
  ], var.additional_api_key_permissions)
}
