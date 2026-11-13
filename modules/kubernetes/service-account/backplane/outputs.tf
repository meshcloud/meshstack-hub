output "kubeconfig" {
  description = "Kubeconfig (YAML) of the deployer, which the definition creates service accounts with."
  sensitive   = true
  value = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = var.cluster_name
    clusters = [{
      name = var.cluster_name
      cluster = {
        server = var.cluster_server
        # The token secret carries the cluster's CA, so the caller only passes the server URL.
        certificate-authority-data = base64encode(kubernetes_secret_v1.deployer_token.data["ca.crt"])
      }
    }]
    users = [{
      name = var.service_account_name
      user = { token = kubernetes_secret_v1.deployer_token.data["token"] }
    }]
    contexts = [{
      name    = var.cluster_name
      context = { cluster = var.cluster_name, user = var.service_account_name }
    }]
  })
}

output "kubeconfig_version" {
  description = "Changes with the deployer token, so the definition picks up a new kubeconfig."
  value       = nonsensitive(substr(sha256(kubernetes_secret_v1.deployer_token.data["token"]), 0, 16))
}
