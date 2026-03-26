locals {
  scoped_kubeconfig = {
    apiVersion      = "v1"
    kind            = "Config"
    current-context = local.kubeconfig_cluster_name

    clusters = [{
      name = local.kubeconfig_cluster_name
      cluster = {
        certificate-authority-data = local.kubeconfig_cluster["certificate-authority-data"]
        server                     = local.kubeconfig_cluster["server"]
      }
    }]

    users = [{
      name = var.service_account_name
      user = {
        token = kubernetes_secret.bb_deployer_token.data["token"]
      }
    }]

    contexts = [{
      name = local.kubeconfig_cluster_name
      context = {
        cluster = local.kubeconfig_cluster_name
        user    = var.service_account_name
      }
    }]
  }
}

output "kubeconfig" {
  description = "Scoped kubeconfig for the building block service account. Pass as kubernetes_kubeconfig to meshstack_integration.tf."
  sensitive   = true
  value       = yamlencode(local.scoped_kubeconfig)
}
