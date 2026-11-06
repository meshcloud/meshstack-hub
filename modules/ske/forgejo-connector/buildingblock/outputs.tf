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

    The `${var.stage}` branch of [${var.repository_owner}/${var.repository_name}](${local.repository_url}) deploys
    to the namespace `${var.namespace}`.

    | Property | Value |
    |----------|-------|
    | **App** | [https://${var.app_hostname}](https://${var.app_hostname}) |
    | **Pipeline** | [`pipeline.yaml` in Forgejo Actions](${local.repository_url}/actions?workflow=pipeline.yaml) |
    | **Service Account** | `${kubernetes_service_account.forgejo_actions.metadata[0].name}`, `edit` on the namespace |

    ## Forgejo Actions secrets and variables

    Set in the [repository settings](${local.repository_url}/settings/actions/secrets):

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
