locals {
  name = "mesh-metering-stackit"

  # The audience the STACKIT SDKs request by default, so the token works with their defaults too.
  token_audience  = "sts.accounts.stackit.cloud"
  token_directory = "/var/run/secrets/stackit.cloud/serviceaccount"
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }
}

# Lets the pods of this namespace, and only those, act as the metering service account.
resource "stackit_service_account_federated_identity_provider" "this" {
  project_id            = var.stackit_project_id
  service_account_email = var.stackit_metering_service_account_email
  # Federation names are unique per service account and every building block adds one.
  name   = "k8s-${substr(sha256("${var.kubernetes_oidc_issuer} ${var.namespace}"), 0, 16)}"
  issuer = var.kubernetes_oidc_issuer

  assertions = [
    {
      item     = "aud"
      operator = "equals"
      value    = local.token_audience
    },
    {
      item     = "sub"
      operator = "equals"
      value    = "system:serviceaccount:${var.namespace}:${kubernetes_service_account_v1.this.metadata[0].name}"
    }
  ]
}

resource "kubernetes_secret_v1" "this" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  data_wo_revision = var.credentials_revision
  data_wo = {
    MESHSTACK_API_SECRET = var.meshstack_api_secret
  }
}

resource "kubernetes_cron_job_v1" "this" {
  # A run before the federation exists fails its token exchange.
  depends_on = [stackit_service_account_federated_identity_provider.this]

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
            service_account_name = kubernetes_service_account_v1.this.metadata[0].name
            restart_policy       = "OnFailure"

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
              env {
                name  = "CONTAINER_PARENT_IDS"
                value = var.stackit_organization_id
              }
              env {
                name  = "STACKIT_SERVICE_ACCOUNT_EMAIL"
                value = var.stackit_metering_service_account_email
              }
              env {
                name  = "STACKIT_FEDERATED_TOKEN_FILE"
                value = "${local.token_directory}/token"
              }

              volume_mount {
                name       = "stackit-token"
                mount_path = local.token_directory
                read_only  = true
              }

              resources {
                requests = { cpu = "100m", memory = "256Mi" }
                limits   = { cpu = "500m", memory = "512Mi" }
              }
            }

            volume {
              name = "stackit-token"
              projected {
                sources {
                  service_account_token {
                    path               = "token"
                    audience           = local.token_audience
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
