locals {
  kubeconfig = {
    apiVersion = "v1"
    kind       = "Config"

    users = [{
      name = kubernetes_service_account.this.metadata[0].name
      user = {
        token = kubernetes_secret.this.data["token"]
      }
    }]

    clusters = [{
      cluster = {
        certificate-authority-data = local.kubeconfig_cluster["certificate-authority-data"]
        server                     = local.kubeconfig_cluster.server
      }
      name = var.cluster_name
      }
    ]

    contexts = [{
      context = {
        cluster   = var.cluster_name
        namespace = var.namespace
        user      = kubernetes_service_account.this.metadata[0].name
      }
      name = var.context
    }]

    current-context = var.context
  }
}

output "instructions" {
  description = "Instructions for using the kubeconfig"
  value       = "Copy kubeconfig value into a file, which can be directly used. e.g. `kubectl --kubeconfig kubeconfig get pods`"
}

output "kubeconfig" {
  description = "Kubeconfig file content for authenticating with the Kubernetes cluster. Empty when `output_to_vault` is set."
  sensitive   = true
  value       = local.write_to_vault ? "" : yamlencode(local.kubeconfig)
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret written to `output_to_vault`, or `{}` when that is not set. `secret_hash` is the secret's KV version and changes with its content."
  value = {
    for key, value in {
      path        = local.write_to_vault ? nonsensitive(var.output_to_vault.path) : null
      secret_hash = local.vault_secret_hash
    } : key => value if local.write_to_vault
  }
}
