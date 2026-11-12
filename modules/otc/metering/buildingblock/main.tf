locals {
  name = "mesh-metering-tcloud"
}

resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  data_wo_revision = var.credentials_revision
  data_wo = {
    MESHSTACK_API_SECRET = var.meshstack_api_secret
    TCLOUD_API_TOKEN     = var.tcloud_api_token
  }
}

resource "kubernetes_cron_job_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = { app = local.name }
  }

  spec {
    schedule                      = var.schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = { app = local.name }
      }

      spec {
        template {
          metadata {
            labels = { app = local.name }
          }

          spec {
            restart_policy = "OnFailure"

            container {
              name = local.name
              # Pulled on every run, so a moving tag like `latest` picks up fixes without a building block run.
              image             = "ghcr.io/meshcloud/mesh-custom-metering/${local.name}:${var.image_tag}"
              image_pull_policy = "Always"

              env_from {
                secret_ref {
                  name = kubernetes_secret_v1.this.metadata[0].name
                }
              }

              env {
                name  = "MESHSTACK_MESHFED_URL"
                value = var.meshstack_meshfed_url
              }
              env {
                name  = "MESHSTACK_KRAKEN_URL"
                value = var.meshstack_kraken_url
              }
              env {
                name  = "MESHSTACK_API_USER"
                value = var.meshstack_api_user
              }
              env {
                name  = "PLATFORM_ID"
                value = var.platform_identifier
              }

              # Unset, the job reads every contract the API key sees in one request.
              dynamic "env" {
                for_each = length(var.tcloud_contract_ids) > 0 ? [join(",", var.tcloud_contract_ids)] : []
                content {
                  name  = "TCLOUD_CONTRACT_IDS"
                  value = env.value
                }
              }

              resources {
                requests = { cpu = "100m", memory = "256Mi" }
                limits   = { cpu = "500m", memory = "512Mi" }
              }
            }
          }
        }
      }
    }
  }
}
