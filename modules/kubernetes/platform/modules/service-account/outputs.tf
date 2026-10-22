output "token" {
  value     = kubernetes_secret_v1.token[var.current_token_generation].data["token"]
  sensitive = true
}
