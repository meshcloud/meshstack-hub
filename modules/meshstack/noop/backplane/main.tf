data "google_project" "this" {
  project_id = var.gcp_project_id
}

locals {
  resource_prefix           = var.gcp_resource_name_prefix
  cloud_run_service_account = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}

resource "time_static" "runner_key_expiry" {}

resource "tls_private_key" "runner" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "meshstack_api_key" "runner" {
  metadata = {
    owned_by_workspace = var.meshstack_workspace_identifier
  }
  spec = {
    display_name = var.runner_display_name
    permissions = [
      "MANAGED_BUILDINGBLOCKRUNSOURCE_SAVE",
      "MANAGED_BUILDINGBLOCKRUN_LIST",
      "MANAGED_BUILDINGBLOCKRUN_SAVE"
    ]
    expires_at = formatdate("YYYY-MM-DD", timeadd(time_static.runner_key_expiry.rfc3339, "168h"))
  }
}

resource "google_secret_manager_secret" "runner_private_key" {
  project   = var.gcp_project_id
  secret_id = "${local.resource_prefix}-private-key"

  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "runner_private_key" {
  secret         = google_secret_manager_secret.runner_private_key.id
  secret_data_wo = resource.tls_private_key.runner.private_key_pem_pkcs8
}

resource "google_secret_manager_secret" "runner_config" {
  project   = var.gcp_project_id
  secret_id = "${local.resource_prefix}-config"
  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "runner_config" {
  secret = google_secret_manager_secret.runner_config.id
  secret_data = templatefile("${path.module}/runner-config.yml", {
    RUNNER_UUID              = meshstack_building_block_runner.this.metadata.uuid
    RUNNER_API_URL           = var.meshstack_endpoint
    RUNNER_API_KEY_CLIENT_ID = meshstack_api_key.runner.status.client_id
  })
}

resource "google_secret_manager_secret" "client_secret" {
  project   = var.gcp_project_id
  secret_id = "${local.resource_prefix}-client-secret"
  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "client_secret" {
  secret      = google_secret_manager_secret.client_secret.id
  secret_data = meshstack_api_key.runner.status.client_secret
}

resource "google_secret_manager_secret_iam_member" "runner_private_key_accessor" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.runner_private_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_service_account}"
}

resource "google_secret_manager_secret_iam_member" "runner_config_accessor" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.runner_config.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_service_account}"
}

resource "google_secret_manager_secret_iam_member" "client_secret_accessor" {
  project   = var.gcp_project_id
  secret_id = google_secret_manager_secret.client_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.cloud_run_service_account}"
}

resource "google_cloud_run_v2_service" "runner" {
  project             = var.gcp_project_id
  name                = local.resource_prefix
  location            = var.gcp_region
  deletion_protection = false

  template {
    service_account = local.cloud_run_service_account

    containers {
      image = var.gcp_runner_image

      resources {
        limits = {
          cpu = "2"
          # 512MiB did crash for the noop BB at pre-run script level, so did 1024:
          # GCP Error message: Memory limit of 1024 MiB exceeded with 1074 MiB used. Consider increasing the memory limit,
          # 2048 seems to work fine so far.
          memory = "2048Mi"
        }
      }

      env {
        name  = "RUNNER_CONFIG_FILE"
        value = "/config/runner-config.yml"
      }

      env {
        name  = "RUNNER_PRIVATE_KEY_FILE"
        value = "/keys/runner-private.pem"
      }

      env {
        name = "RUNNER_API_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.client_secret.secret_id
            version = "latest"
          }
        }
      }

      volume_mounts {
        name       = "runner-config"
        mount_path = "/config"
      }

      volume_mounts {
        name       = "runner-private-key"
        mount_path = "/keys"
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 3
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        period_seconds    = 30
        failure_threshold = 3
      }
    }

    volumes {
      name = "runner-config"
      secret {
        secret = google_secret_manager_secret.runner_config.secret_id
        items {
          version = "latest"
          path    = "runner-config.yml"
        }
      }
    }

    volumes {
      name = "runner-private-key"
      secret {
        secret = google_secret_manager_secret.runner_private_key.secret_id
        items {
          version = "latest"
          path    = "runner-private.pem"
        }
      }
    }
  }

  depends_on = [
    google_secret_manager_secret_iam_member.runner_private_key_accessor,
    google_secret_manager_secret_iam_member.runner_config_accessor,
    google_secret_manager_secret_iam_member.client_secret_accessor,
    google_secret_manager_secret_version.runner_private_key,
    google_secret_manager_secret_version.runner_config,
    google_secret_manager_secret_version.client_secret,
  ]
}

resource "meshstack_building_block_runner" "this" {
  metadata = {
    owned_by_workspace = var.meshstack_workspace_identifier
  }
  spec = {
    display_name        = var.runner_display_name
    implementation_type = "TERRAFORM"
    public_key          = resource.tls_private_key.runner.public_key_pem
    restriction         = "PRIVATE"
  }
}
