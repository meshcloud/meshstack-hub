provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "this" {
  name                = var.aks_cluster_name
  resource_group_name = var.aks_resource_group_name
}

# Exchanges the runner's federated token for an Entra token for the AKS API server. This is what
# `kubelogin get-token --login workloadidentity` does; doing it here keeps the run free of any
# tool on the runner host (see module-layout.md, Pre-run Scripts). The token is valid for about an
# hour and lands in the run's state, which is why it is the only credential this block handles.
data "http" "aks_token" {
  url    = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/oauth2/v2.0/token"
  method = "POST"

  request_headers = {
    Content-Type = "application/x-www-form-urlencoded"
  }

  request_body = join("&", [
    "grant_type=client_credentials",
    "client_id=${data.azurerm_client_config.current.client_id}",
    # Well-known application ID of AKS's Entra server app, the audience every AKS cluster accepts.
    "scope=6dae42f8-4368-4678-94ff-3960e28e3630/.default",
    "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
    "client_assertion=${urlencode(trimspace(file(var.oidc_token_file_path)))}",
  ])

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Entra rejected the token exchange with HTTP ${self.status_code}. Check the backplane's federated credential."
    }
  }
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.this.kube_config[0].host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  token                  = sensitive(jsondecode(data.http.aks_token.response_body).access_token)
}

provider "azuread" {}
