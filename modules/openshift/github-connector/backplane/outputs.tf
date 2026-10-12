output "kubernetes_api" {
  description = "API server URL, CA bundle and service account token the building block connects with."
  sensitive   = true
  value = {
    server                 = var.api_server_url
    cluster_ca_certificate = coalesce(var.api_server_ca_certificate, kubernetes_secret.connector_token.data["ca.crt"])
    token                  = kubernetes_secret.connector_token.data["token"]
  }
}
