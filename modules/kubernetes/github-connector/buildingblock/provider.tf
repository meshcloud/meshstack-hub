provider "kubernetes" {
  host                   = var.kubernetes_api.server
  cluster_ca_certificate = var.kubernetes_api.cluster_ca_certificate
  token                  = var.kubernetes_api.token
}

# Authenticates as the GitHub App from GITHUB_OWNER, GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID and
# GITHUB_APP_PEM_FILE in the run's environment.
provider "github" {
  app_auth {}
}
