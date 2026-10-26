output "expires_at" {
  description = "Access expiry timestamp in RFC 3339 format (UTC)."
  value       = local.expires_at
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value = local.is_active ? (<<-EOT
    # Access to `${var.namespace}` until ${local.expires_at}

    `${local.developer_email}` can use the `${var.cluster_role}` role in namespace `${var.namespace}`
    of cluster `${var.cluster_name}`. Sign in to `gcloud` with that account, then run:

    ```sh
    gcloud container clusters get-credentials ${var.cluster_name} --location ${var.cluster_location} --project ${var.project_id}
    kubectl get pods --namespace ${var.namespace}
    ```

    The temporary IAM grant expires at the time shown above. A cleanup job removes this namespace
    grant on its next successful run (scheduled every five minutes). Other access you already have
    is unaffected. Delete this building block when you are done.
    EOT
    ) : (<<-EOT
    # Access to `${var.namespace}` expired at ${local.expires_at}

    Delete this building block and order a new one to request access again.
    EOT
  )
}
