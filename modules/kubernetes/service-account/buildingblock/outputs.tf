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
  description = "Kubeconfig with the service account token. Sensitive, but in plain view to everyone who can see the building block; prefer `output_to_vault`, which leaves this empty."
  # "" because meshStack fails a run whose declared output is missing.
  value = local.write_to_vault ? "" : nonsensitive(yamlencode(local.kubeconfig))
}

output "vault_secret" {
  description = "`{path, secret_hash}` of the secret in Vault, where `secret_hash` changes with its content; `{}` without `output_to_vault`."
  value = {
    for key, value in {
      path        = local.vault_secret_path
      secret_hash = local.vault_secret_hash
    } : key => value if local.write_to_vault
  }
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value       = <<-EOT
    # Kubernetes Service Account: **${kubernetes_service_account.this.metadata[0].name}**

    | Property | Value |
    |----------|-------|
    | **Service Account** | `${var.namespace}/${kubernetes_service_account.this.metadata[0].name}` |
    | **Role** | `${var.cluster_role}`, ${var.bind_cluster_wide ? "in every namespace" : "in `${var.namespace}`"} |
    | **Cluster** | `${var.cluster_name}` at `${local.kubeconfig_cluster.server}` |
    | **Kubeconfig** | ${local.write_to_vault ? "key `kubeconfig` of the Vault secret `${local.vault_secret_path}` on mount `${local.vault_mount}`" : "the **Kubeconfig** output of this building block"} |

    Save the kubeconfig to a file and use it with `kubectl --kubeconfig kubeconfig get pods`.
  EOT
}
