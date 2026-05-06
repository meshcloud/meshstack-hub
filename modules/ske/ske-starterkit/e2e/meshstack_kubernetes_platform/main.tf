# namespace for replication service account
resource "kubernetes_namespace" "meshcloud" {
  metadata {
    name = "smoke-test-${var.test_suffix}"
  }
}

# meshfed_service service account
resource "kubernetes_service_account" "meshfed_service" {
  metadata {
    name      = "meshfed-service-${var.test_suffix}"
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }
}

# meshfed_service secret
resource "kubernetes_secret" "meshfed_service_secret" {
  metadata {
    name      = "meshfed-service-${var.test_suffix}"
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.meshfed_service.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role" "meshfed-service" {

  metadata {
    name = "meshfed-service-${var.test_suffix}"
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch", "create", "delete", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["resourcequotas", "resourcequotas/status"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
  }
  rule {
    api_groups = [""]
    resources  = ["appliedclusterresourcequotas", "clusterresourcequotas", "clusterresourcequotas/status"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
  }
  rule {
    api_groups = ["", "rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["", "rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["create", "delete", "update"]
  }
  rule {
    api_groups     = ["", "rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = ["admin", "edit", "view"]
  }
}

# meshfed_service role binding (unique per instance)
resource "kubernetes_cluster_role_binding" "meshfed-service" {
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.meshfed_service.metadata[0].name
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.meshfed-service.metadata[0].name
  }
  metadata {
    name = "meshfed-service-${var.test_suffix}"
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }
}

# meshPlatform

resource "meshstack_platform" "this" {
  metadata = {
    name               = "smoke-test-ske-platform-${var.test_suffix}"
    owned_by_workspace = var.workspace
  }

  spec = {
    display_name      = "Smoke Test ${var.test_suffix}"
    description       = "Platform for Smoke Test ${var.test_suffix}"
    endpoint          = var.kube_host
    documentation_url = "https://kubernetes.io"

    location_ref = { name = "global" }

    availability = {
      restriction              = "PUBLIC"
      publication_state        = "PUBLISHED"
      restricted_to_workspaces = []
    }

    quota_definitions = []

    config = {
      kubernetes = {
        base_url               = var.kube_host
        disable_ssl_validation = true

        replication = {
          client_config = {
            access_token = {
              secret_value = kubernetes_secret.meshfed_service_secret.data["token"]
            }
          }

          namespace_name_pattern = "#{workspaceIdentifier}-#{projectIdentifier}"
        }

        metering = {
          client_config = {
            access_token = {
              secret_value = "dont-care"
            }
          }

          processing = {
            enabled = false
          }
        }
      }
    }

    contributing_workspaces = []
  }
}

# dev meshLandingZone

resource "meshstack_landingzone" "dev" {
  metadata = {
    name               = "smoketest-ske-dev-${var.test_suffix}"
    owned_by_workspace = var.workspace
    tags = {
      "confidentiality" = ["Internal"],
      "environment"     = ["dev"],
    }
  }
  spec = {
    display_name                  = "Smoke Test Landing Zone ${var.test_suffix}"
    description                   = "Landing Zone for Smoke Test ${var.test_suffix}"
    automate_deletion_approval    = true
    automate_deletion_replication = true
    info_link                     = "https://dontcare.com"
    platform_ref = {
      uuid = meshstack_platform.this.metadata.uuid
    }
    platform_properties = {
      kubernetes = {
        kubernetes_role_mappings = [
          {
            project_role_ref = { name = "admin" }
            platform_roles   = ["admin"]
          },
          {
            project_role_ref = { name = "user" }
            platform_roles   = ["edit"]
          },
          {
            project_role_ref = { name = "reader" }
            platform_roles   = ["view"]
          },
        ]
      }
    }
  }
}

# prod meshLandingZone

resource "meshstack_landingzone" "prod" {
  metadata = {
    name               = "smoketest-ske-prod-${var.test_suffix}"
    owned_by_workspace = var.workspace
    tags = {
      "confidentiality" = ["Internal"],
      "environment"     = ["prod"],
    }
  }
  spec = {
    display_name                  = "Smoke Test Landing Zone ${var.test_suffix}"
    description                   = "Landing Zone for Smoke Test ${var.test_suffix}"
    automate_deletion_approval    = true
    automate_deletion_replication = true
    info_link                     = "https://dontcare.com"
    platform_ref = {
      uuid = meshstack_platform.this.metadata.uuid
    }
    platform_properties = {
      kubernetes = {
        kubernetes_role_mappings = [
          {
            project_role_ref = { name = "admin" }
            platform_roles   = ["admin"]
          },
          {
            project_role_ref = { name = "user" }
            platform_roles   = ["edit"]
          },
          {
            project_role_ref = { name = "reader" }
            platform_roles   = ["view"]
          },
        ]
      }
    }
  }
}
