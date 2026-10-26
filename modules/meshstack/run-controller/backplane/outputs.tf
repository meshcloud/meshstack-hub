output "kubernetes_api" {
  description = "Kubernetes API connection data."
  sensitive   = true
  value = {
    server                 = var.api_server_url
    cluster_ca_certificate = coalesce(var.api_server_ca_certificate, kubernetes_secret_v1.backplane_token.data["ca.crt"])
    token                  = kubernetes_secret_v1.backplane_token.data["token"]
  }
}
