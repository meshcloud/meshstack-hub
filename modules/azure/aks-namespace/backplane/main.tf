data "azurerm_kubernetes_cluster" "this" {
  name                = var.aks.cluster_name
  resource_group_name = var.aks.resource_group_name
}

resource "azurerm_resource_group" "backplane" {
  name     = var.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "backplane" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.backplane.name
}

resource "azurerm_federated_identity_credential" "backplane" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.backplane.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.workload_identity_federation.issuer
  subject                   = each.value
}

# Reading the cluster through the ARM provider is all the building block needs besides the
# in-cluster rights below.
resource "azurerm_role_definition" "backplane" {
  name        = "${var.name}-deploy"
  description = "Enables the ${var.name} building block to look up the AKS cluster it creates namespaces in"
  scope       = var.scope

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action",
    ]
  }

  assignable_scopes = [var.scope]
}

resource "azurerm_role_assignment" "backplane" {
  scope              = data.azurerm_kubernetes_cluster.this.id
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}

# Creating a namespace is a cluster-scoped write, so the identity needs cluster admin. The built-in
# role is the narrowest one Azure offers for that; it is scoped to this one cluster.
resource "azurerm_role_assignment" "cluster_admin" {
  scope                = data.azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.backplane.principal_id
}

resource "azurerm_role_assignment" "kubelet_acr_pull" {
  lifecycle {
    enabled = var.acr_id != null
  }

  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = data.azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
