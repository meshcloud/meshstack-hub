output "app_link" {
  description = "Public URL for this stage application."
  value       = "https://${var.app_hostname}"
}

locals {
  repository_url = "${trimsuffix(data.external.env.result["FORGEJO_HOST"], "/")}/${var.repository_owner}/${var.repository_name}"
}

output "summary" {
  description = "Markdown summary shown on the building block."
  value       = <<-EOT
    # Forgejo Connector: **${var.stage}**

    The `${var.stage}` branch of <a href="${local.repository_url}" target="_blank" rel="noopener">${var.repository_owner}/${var.repository_name}</a> deploys
    to the namespace `${var.namespace}`.

    | Property | Value |
    |----------|-------|
    | **App** | <a href="https://${var.app_hostname}" target="_blank" rel="noopener">https://${var.app_hostname}</a> |
    | **Pipeline** | <a href="${local.repository_url}/actions?workflow=pipeline.yaml" target="_blank" rel="noopener"><code>pipeline.yaml</code> in Forgejo Actions</a> |
    | **Service Account** | `${kubernetes_service_account.forgejo_actions.metadata[0].name}`, `edit` on the namespace |

    ## Forgejo Actions secrets and variables

    Set in the <a href="${local.repository_url}/settings/actions/secrets" target="_blank" rel="noopener">repository settings</a>:

    | Name | Kind | Holds |
    |------|------|-------|
    | `KUBECONFIG_${upper(var.stage)}` | secret | kubeconfig of the service account |
    | `K8S_NAMESPACE_${upper(var.stage)}` | variable | `${var.namespace}` |
    | `APP_HOSTNAME_${upper(var.stage)}` | variable | `${var.app_hostname}` |

    ## Kubernetes secrets in the namespace

    | Secret | Filled from the Vault secret |
    |--------|------------------------------|
    | `${kubernetes_secret.image_pull.metadata[0].name}`, the image pull secret of `default` | `${var.registry_secret_path}` |${join("", [for name, path in var.additional_kubernetes_secrets : "\n| `${name}` | `${path}` |"])}

    A changed Vault value reaches these secrets with the next increase of **Secrets Revision**.
  EOT
}
