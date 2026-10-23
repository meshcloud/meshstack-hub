locals {
  # The contract with the building block: it labels each RoleBinding it creates and annotates when
  # the binding expires, in UTC RFC 3339, so the cleanup script can compare it as a string.
  binding_label     = "meshcloud.io/gke-temporary-access"
  expiry_annotation = "meshcloud.io/expires-at"
}

resource "kubernetes_namespace_v1" "cleanup" {
  metadata {
    name = var.cleanup_namespace
  }
}

resource "kubernetes_service_account_v1" "cleanup" {
  metadata {
    name      = "cleanup"
    namespace = kubernetes_namespace_v1.cleanup.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "cleanup" {
  metadata {
    name = "${var.service_account_id}-cleanup"
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["list", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "cleanup" {
  for_each = var.namespaces

  metadata {
    name      = kubernetes_cluster_role_v1.cleanup.metadata[0].name
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.cleanup.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cleanup.metadata[0].name
    namespace = kubernetes_service_account_v1.cleanup.metadata[0].namespace
  }
}

# Removes expired RoleBindings even while developers still hold a permanent container.clusters.get,
# which makes the IAM expiry alone ineffective.
resource "kubernetes_cron_job_v1" "cleanup" {
  metadata {
    name      = "cleanup-expired-access"
    namespace = kubernetes_namespace_v1.cleanup.metadata[0].name
  }

  spec {
    schedule                      = "*/5 * * * *"
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}

      spec {
        backoff_limit = 2

        template {
          metadata {}

          spec {
            service_account_name = kubernetes_service_account_v1.cleanup.metadata[0].name
            restart_policy       = "Never"

            security_context {
              run_as_non_root = true
              run_as_user     = 65534
              seccomp_profile {
                type = "RuntimeDefault"
              }
            }

            container {
              name    = "cleanup"
              image   = var.cleanup_image
              command = ["bash", "-euo", "pipefail", "-c"]
              args = [<<-EOT
                now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                for namespace in $NAMESPACES; do
                  kubectl get rolebindings -n "$namespace" -l "$BINDING_LABEL" -o "jsonpath=$EXPIRY_JSONPATH" |
                    while read -r name expires_at; do
                      if [[ "$expires_at" < "$now" ]]; then
                        kubectl delete rolebinding -n "$namespace" "$name"
                      fi
                    done
                done
              EOT
              ]

              env {
                name  = "NAMESPACES"
                value = join(" ", var.namespaces)
              }
              env {
                name  = "BINDING_LABEL"
                value = local.binding_label
              }
              env {
                name  = "EXPIRY_JSONPATH"
                value = "{range .items[*]}{.metadata.name}{\" \"}{.metadata.annotations.${replace(local.expiry_annotation, ".", "\\.")}}{\"\\n\"}{end}"
              }
              # kubectl writes its discovery cache below $HOME.
              env {
                name  = "HOME"
                value = "/tmp"
              }

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = true
                capabilities {
                  drop = ["ALL"]
                }
              }

              resources {
                requests = {
                  cpu    = "10m"
                  memory = "64Mi"
                }
                limits = {
                  memory = "128Mi"
                }
              }

              volume_mount {
                name       = "tmp"
                mount_path = "/tmp"
              }
            }

            volume {
              name = "tmp"
              empty_dir {}
            }
          }
        }
      }
    }
  }
}
