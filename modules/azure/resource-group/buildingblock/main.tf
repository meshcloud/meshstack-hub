locals {
  resource_group_name = "rg-${var.workspace_identifier}-${var.project_identifier}"
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
}
