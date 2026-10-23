# Seeded from plantimestamp() so the expiry is known while planning the first run, which
# lifecycle.enabled requires. ignore_changes keeps later runs from moving it, so a re-run never
# extends access.
resource "time_static" "requested_at" {
  rfc3339 = plantimestamp()

  lifecycle {
    ignore_changes = [rfc3339]
  }
}

locals {
  # UTC RFC 3339, the format the cleanup CronJob compares as a string.
  expires_at = timeadd(time_static.requested_at.rfc3339, "${var.duration_hours}h")

  # A run after expiry removes both grants, instead of recreating a RoleBinding the cleanup CronJob
  # already deleted. It also keeps expired grants from piling up in the project's IAM policy.
  is_active = timecmp(plantimestamp(), local.expires_at) < 0

  # One grant per building block. Two building blocks of the same developer must not share a
  # condition, or deleting one would revoke the other.
  grant_id = substr(sha1("${var.author.email}/${var.namespace}/${time_static.requested_at.rfc3339}"), 0, 10)
}

# GKE refuses authentication without container.clusters.get, so this grant expiring is what ends
# the access. It authorizes nothing inside the cluster.
resource "google_project_iam_member" "cluster_viewer" {
  lifecycle {
    enabled = local.is_active
  }

  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "user:${var.author.email}"

  condition {
    title       = "gke-temporary-access-${local.grant_id}"
    description = "Access to namespace ${var.namespace} until ${local.expires_at}"
    expression  = "request.time < timestamp(\"${local.expires_at}\")"
  }
}

resource "kubernetes_role_binding_v1" "this" {
  lifecycle {
    enabled = local.is_active
  }

  metadata {
    name      = "gke-temporary-access-${local.grant_id}"
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
    name      = var.author.email
  }
}
