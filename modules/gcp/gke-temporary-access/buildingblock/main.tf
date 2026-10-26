# Seed the start time during planning for `lifecycle.enabled`; preserve it across reruns.
resource "time_static" "requested_at" {
  rfc3339 = plantimestamp()

  lifecycle {
    ignore_changes = [rfc3339]
  }
}

# One grant per building block. Two building blocks of the same developer must not share a
# condition, or deleting one would revoke the other.
resource "random_uuid" "grant_id" {}

locals {
  # UTC RFC 3339, the format the cleanup CronJob compares as a string.
  expires_at = timeadd(time_static.requested_at.rfc3339, "${var.duration_hours}h")

  # A run after expiry removes both grants, instead of recreating a RoleBinding the cleanup CronJob
  # already deleted. It also keeps expired grants from piling up in the project.
  is_active = timecmp(plantimestamp(), local.expires_at) < 0

  # IAM matches emails case-insensitively, RBAC matches usernames exactly. GKE takes the username
  # from the Google token, which carries the email in lowercase.
  developer_email = lower(var.author.email)
}

# This grant enables cluster authentication; namespace permissions come from the RoleBinding.
resource "google_project_iam_member" "cluster_viewer" {
  lifecycle {
    enabled = local.is_active
  }

  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "user:${local.developer_email}"

  condition {
    title       = "gke-temporary-access-${random_uuid.grant_id.result}"
    description = "Temporary cluster authentication until ${local.expires_at} (namespace request: ${var.namespace})"
    expression  = "request.time < timestamp(\"${local.expires_at}\")"
  }
}

resource "kubernetes_role_binding_v1" "this" {
  lifecycle {
    enabled = local.is_active
  }

  metadata {
    name      = "gke-temporary-access-${random_uuid.grant_id.result}"
    namespace = var.namespace
    labels = {
      (var.binding_label) = "true"
    }
    annotations = {
      (var.expiry_annotation) = local.expires_at
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = var.cluster_role
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = local.developer_email
  }
}
