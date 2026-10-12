locals {
  group_bindings = merge([
    for cluster_role, object_ids in {
      admin = var.admin_group_object_ids
      edit  = var.edit_group_object_ids
      view  = var.view_group_object_ids
    } : { for id in object_ids : "${cluster_role}-${id}" => { cluster_role = cluster_role, object_id = id } }
  ]...)
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace_name

    labels = {
      "app.kubernetes.io/managed-by" = "meshstack"
      "meshcloud.io/workspace"       = var.workspace_identifier
    }
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  metadata {
    name      = "meshstack-quota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quota.requests_cpu
      "requests.memory" = var.resource_quota.requests_memory
      "limits.cpu"      = var.resource_quota.limits_cpu
      "limits.memory"   = var.resource_quota.limits_memory
      "pods"            = var.resource_quota.pods
    }
  }
}

# Without defaults, a pod that declares no requests or limits is rejected once a quota on those
# resources exists.
resource "kubernetes_limit_range_v1" "this" {
  metadata {
    name      = "meshstack-defaults"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default_request = {
        cpu    = var.default_container_limits.cpu_request
        memory = var.default_container_limits.memory_request
      }
      default = {
        cpu    = var.default_container_limits.cpu_limit
        memory = var.default_container_limits.memory_limit
      }
    }
  }
}

resource "kubernetes_role_binding_v1" "group" {
  for_each = local.group_bindings

  metadata {
    name      = "meshstack-${each.value.cluster_role}-${substr(each.value.object_id, 0, 8)}"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value.cluster_role
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = each.value.object_id
  }
}
