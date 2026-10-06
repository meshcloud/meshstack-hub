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
