# note: this building block is expected to be executed with pre configured output by the "backplane" module in the
# parent dir, this needs to provided in the BB execution enviornment
#
# additionaly:
# there is pre_role_assignemnt Building Block which is expected to be executed before this BB

data "azurerm_subscription" "current" {}
data "azuread_client_config" "current" {}

#
# configure developer access
#

# note: this group is managed via meshStack and provided as part of the sandbox landing zone
data "azuread_group" "project_admins" {
  display_name = "${var.workspace_identifier}.${var.project_identifier}-admin"
}

# rationale: normal uses with "Project User" role should only deploy code via the pipeline and therefore don't need
# access to terraform state, but users with "Project Admin" role should be able to debug terraform issues and therefore
# work with the state directly
resource "azurerm_role_assignment" "project_admins_blobs" {
  role_definition_name = "Storage Blob Data Owner"
  description          = "Allow developer assigned the 'Project Admin' role via meshStack to work directly with terraform state"

  principal_id = data.azuread_group.project_admins.object_id
  scope        = azurerm_storage_container.tfstates.resource_manager_id
}
