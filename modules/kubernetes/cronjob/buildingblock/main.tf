resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }
}

# Always created, also empty, because a secret that comes and goes with `secret_env` would need a
# count, and an ephemeral value cannot decide one.
resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  data_wo_revision = var.secret_env_revision
  data_wo          = var.secret_env == null ? {} : var.secret_env
}

resource "kubernetes_cron_job_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = { app = var.name }
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = { app = var.name }
      }

      spec {
        template {
          metadata {
            labels = { app = var.name }
          }

          spec {
            service_account_name = kubernetes_service_account_v1.this.metadata[0].name
            restart_policy       = "OnFailure"

            container {
              name = var.name
              # Pulled on every run, so a moving tag like `latest` picks up fixes without a building block run.
              image             = var.image
              image_pull_policy = "Always"

              env_from {
                secret_ref {
                  name = kubernetes_secret_v1.this.metadata[0].name
                }
              }

              dynamic "env" {
                for_each = var.env
                content {
                  name  = env.key
                  value = env.value
                }
              }

              dynamic "volume_mount" {
                for_each = var.service_account_token == null ? [] : [var.service_account_token]
                content {
                  name       = "service-account-token"
                  mount_path = volume_mount.value.mount_path
                  read_only  = true
                }
              }

              resources {
                requests = { cpu = var.resources.cpu_request, memory = var.resources.memory_request }
                limits   = { cpu = var.resources.cpu_limit, memory = var.resources.memory_limit }
              }
            }

            dynamic "volume" {
              for_each = var.service_account_token == null ? [] : [var.service_account_token]
              content {
                name = "service-account-token"
                projected {
                  sources {
                    service_account_token {
                      path               = "token"
                      audience           = volume.value.audience
                      expiration_seconds = 3600
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
