output "token" {
  value     = one(concat(kubernetes_secret_v1.this[*], kubernetes_secret_v1.released[*])).data["token"]
  sensitive = true
}
