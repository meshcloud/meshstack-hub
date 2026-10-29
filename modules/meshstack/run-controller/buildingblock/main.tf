data "meshstack_instance" "this" {}

locals {
  name         = "run-controller"
  display_name = "${var.project_identifier} run-controller"
  labels       = { app = local.name }

  runner_config = yamlencode({
    uuid = meshstack_building_block_runner.this.metadata.uuid
    api = {
      url  = data.meshstack_instance.this.endpoint
      auth = { key = { clientId = var.runner_api_key_client_id } }
    }
    dispatcher = { forTypes = ["ALL"] }
    k8s = {
      namespace = var.namespace
      jobSpecTemplates = {
        ALL = {
          spec = {
            template = {
              spec = {
                containers = [{ name = "runner", image = var.job_image }]
              }
            }
          }
        }
      }
    }
  })

  secret_data = {
    "runner-config.yml"        = local.runner_config
    "runner-private.pem"       = tls_private_key.this.private_key_pem_pkcs8
    "RUNNER_API_CLIENT_SECRET" = var.runner_api_key_client_secret
  }
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "meshstack_building_block_runner" "this" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name        = local.display_name
    implementation_type = "ALL"
    public_key          = tls_private_key.this.public_key_pem
    restriction         = "PRIVATE"
  }
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }
}

resource "kubernetes_role_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "create", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["create", "patch"]
  }
}

resource "kubernetes_role_binding_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.this.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.this.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  data = local.secret_data
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
        annotations = {
          # subPath mounts never see a changed Secret, so a change has to restart the pod.
          "checksum/secret" = nonsensitive(sha256(jsonencode(local.secret_data)))
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.this.metadata[0].name

        security_context {
          fs_group = 2000
        }

        container {
          name  = local.name
          image = var.image

          env {
            name = "RUNNER_API_CLIENT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.this.metadata[0].name
                key  = "RUNNER_API_CLIENT_SECRET"
              }
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/app/runner-config.yml"
            sub_path   = "runner-config.yml"
            read_only  = true
          }

          volume_mount {
            name       = "config"
            mount_path = "/app/runner-private.pem"
            sub_path   = "runner-private.pem"
            read_only  = true
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 2112
            }
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 2112
            }
          }
        }

        volume {
          name = "config"
          secret {
            secret_name  = kubernetes_secret_v1.this.metadata[0].name
            default_mode = "0440"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_role_binding_v1.this]
}
