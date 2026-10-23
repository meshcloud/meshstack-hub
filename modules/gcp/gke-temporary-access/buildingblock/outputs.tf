output "expires_at" {
  description = "When the access ends, in UTC RFC 3339."
  value       = local.expires_at
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value = local.is_active ? (<<-EOT
    # Access to `${var.namespace}` until ${local.expires_at}

    `${var.author.email}` can use the `${var.cluster_role}` role in namespace `${var.namespace}`
    of cluster `${var.cluster_name}`. Sign in to `gcloud` with that account, then run:

    ```sh
    gcloud container clusters get-credentials ${var.cluster_name} --location ${var.cluster_location} --project ${var.project_id}
    kubectl get pods --namespace ${var.namespace}
    ```

    Access ends automatically. Delete this building block when you are done.
    EOT
    ) : (<<-EOT
    # Access to `${var.namespace}` expired at ${local.expires_at}

    Delete this building block and order a new one to request access again.
    EOT
  )
}
