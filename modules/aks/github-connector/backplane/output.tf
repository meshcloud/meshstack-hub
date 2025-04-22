output "config_tf" {
  description = "Generates a config.tf that can be dropped into meshStack's BuildingBlockDefinition as an encrypted file input to configure this building block."
  sensitive   = true
  value       = <<-EOF
    provider "kubernetes" {
    host = "${data.azurerm_kubernetes_cluster.aks.kube_admin_config[0].host}"
    cluster_ca_certificate = base64decode("${data.azurerm_kubernetes_cluster.aks.kube_admin_config[0].cluster_ca_certificate}")
    client_certificate = base64decode("${data.azurerm_kubernetes_cluster.aks.kube_admin_config[0].client_certificate}")
    client_key = base64decode("${data.azurerm_kubernetes_cluster.aks.kube_admin_config[0].client_key}")
  }

  locals {
    aks_kubeconfig_stub = {
      apiVersion = "v1"
      kind = "Config"
      current-context = "aks"

      clusters = [
        {
          name = "aks"
          cluster = {
            server = "${data.azurerm_kubernetes_cluster.aks.kube_config[0].host}"
            certificate-authority-data = "${data.azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate}"
          }
        }
      ]
    }

    acr = {
      host =  "${azurerm_container_registry.acr.login_server}"
      username = "${azuread_service_principal.bb_github_connector_acr.client_id}"
      password = "${azuread_service_principal_password.bb_github_connector_acr.value}"
    }
  }
  EOF
}

