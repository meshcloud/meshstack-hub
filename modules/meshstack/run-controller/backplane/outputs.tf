output "kubernetes_api" {
  description = "Kubernetes API connection data."
  sensitive   = true
  value = {
    server                 = var.api_server_url
    cluster_ca_certificate = coalesce(var.api_server_ca_certificate, kubernetes_secret_v1.backplane_token.data["ca.crt"])
    token                  = kubernetes_secret_v1.backplane_token.data["token"]
  }
}

output "runner_api_key" {
  description = "API key the runners poll meshStack with."
  sensitive   = true
  value = {
    client_id     = meshstack_api_key.runner.status.client_id
    client_secret = meshstack_api_key.runner.status.client_secret
  }
}

output "runner_api_key_version" {
  description = "Hash of the runners' API key. It changes when the key is replaced."
  value       = nonsensitive(sha256(jsonencode([meshstack_api_key.runner.status.client_id, meshstack_api_key.runner.status.client_secret])))
}
