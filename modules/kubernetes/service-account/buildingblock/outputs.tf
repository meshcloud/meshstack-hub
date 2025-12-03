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
        certificate-authority-data = var.cluster_ca_certificate
        server                     = "https://${var.cluster_endpoint}"
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
  description = "Kubeconfig file content for authenticating with the Kubernetes cluster"
  sensitive   = true
  value       = yamlencode(local.kubeconfig)
}
