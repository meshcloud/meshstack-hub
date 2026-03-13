# BB creates
# - service account with permissions to
#   - manage a "github-image-pull-secret"
#   - manage pods and deployments
#
# BB puts kubeconfig for this SA into GH
#
# GHA workflow uses this SA to
# - update image pull secret
# - deployment
#
locals {
  acr_resource_group_name = coalesce(var.acr.resource_group_name, azurerm_resource_group.bb_github_connector.name)
}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks.cluster_name
  resource_group_name = var.aks.resource_group_name
}

resource "azurerm_resource_group" "bb_github_connector" {
  name     = var.resource_prefix
  location = var.acr.location
}

# Container registry
# A shared ACR is used for all building block consumers by default.
# Set var.acr.resource_group_name to place the ACR in an existing resource group.

resource "azurerm_container_registry" "acr" {
  name                = replace(var.resource_prefix, "-", "")
  resource_group_name = local.acr_resource_group_name
  location            = var.acr.location
  sku                 = "Basic"
}

# Service principal used by GitHub Actions to push images to ACR.
# Granted AcrPush (not Contributor) — scoped to this registry only.

resource "azuread_application" "bb_github_connector_acr" {
  display_name = "${var.resource_prefix}-acr"
}

resource "azuread_service_principal" "bb_github_connector_acr" {
  client_id = azuread_application.bb_github_connector_acr.client_id
}

resource "azuread_service_principal_password" "bb_github_connector_acr" {
  service_principal_id = azuread_service_principal.bb_github_connector_acr.id
}

resource "azurerm_role_assignment" "bb_github_connector_acr" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.bb_github_connector_acr.object_id
}

# The ClusterIssuer is needed so that SSL certificates can be issued for projects using the GitHub Actions Connector.
resource "kubernetes_cluster_role" "clusterissuer_reader" {
  metadata {
    name = "clusterissuer-reader"
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["clusterissuers"]
    verbs      = ["get"]
  }
}
