variable "gcp_project_id" {
  type        = string
  description = "GCP project ID that contains the GKE cluster."
}

variable "gke_cluster_name" {
  type        = string
  description = "Name of the GKE cluster."
}

variable "gke_cluster_location" {
  type        = string
  description = "Region or zone of the GKE cluster."
}

variable "gke_forbidden_namespaces" {
  type        = list(string)
  default     = null
  description = "Namespace denylist. Defaults to system namespaces. An explicit list replaces these defaults. The cleanup namespace is always blocked, even with `[]`. A trailing `*` matches a prefix."
}

variable "gke_cluster_role" {
  type        = string
  default     = null
  description = "Existing ClusterRole assigned to users by the building block. Defaults to the backplane's default."
}

variable "gke_cleanup_namespace" {
  type        = string
  default     = null
  description = "Namespace created for the CronJob that removes expired RoleBindings. Defaults to the backplane's default."
}

variable "gke_cleanup_image" {
  type        = string
  default     = null
  description = "Container image used by the cleanup CronJob. It must include `bash`, `date` and `kubectl`. Defaults to the backplane's default."
}

variable "workload_identity" {
  type = object({
    pool_identifier         = optional(string, "meshstack-building-block-pool")
    subject_token_file_path = optional(string, "/var/run/secrets/workload-identity/gcp/token")
  })
  default     = {}
  description = "Workload identity federation settings for GCP authentication. GCP retains soft-deleted pools for about 30 days, during which their identifiers cannot be reused. Use a fresh `pool_identifier` when recreating the backplane."
}

variable "backplane_service_account_id" {
  type        = string
  default     = "buildingblock-gke-access-sa"
  description = "Account ID of the building block's Google service account. It also prefixes the in-cluster ClusterRoles and admission policy, so it must be unique per project and per cluster."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "building_block_runner_uuid" {
  type        = string
  default     = null
  description = "Runs this building block on the given meshStack building block runner instead of the shared one meshStack hosts."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

# The caller supplies Google and Kubernetes providers; Kubernetes must point at the target cluster.
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/gcp/gke-temporary-access/backplane?ref=${var.hub.git_ref}"

  project_id           = var.gcp_project_id
  forbidden_namespaces = var.gke_forbidden_namespaces
  cluster_role         = var.gke_cluster_role
  cleanup_namespace    = var.gke_cleanup_namespace
  cleanup_image        = var.gke_cleanup_image
  service_account_id   = var.backplane_service_account_id

  workload_identity_federation = {
    workload_identity_pool_identifier = var.workload_identity.pool_identifier
    subject_token_file_path           = var.workload_identity.subject_token_file_path
  }

  workload_identity_federation_trust = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    audience = meshstack_building_block_definition.this.version_latest.workload_identity_federation.gcp.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

data "google_container_cluster" "this" {
  project  = var.gcp_project_id
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = coalesce(var.bbd_display_name, "GKE Temporary Namespace Access")
    description  = coalesce(var.bbd_description, "Grants you access to one namespace of a GKE cluster for 1 to 8 hours.")
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block grants you access to one namespace of the `${var.gke_cluster_name}` GKE
      cluster using your Google account. Choose an existing namespace and a duration from 1 to 8
      hours. Your Google account's email address must match your meshStack email.

      The duration is measured from the first run; reruns do not reset the start time. The temporary
      IAM grant expires at the requested time, and a cleanup job removes the namespace grant on its
      next successful run (scheduled every five minutes). A daily run also removes the expired grants
      from the project, so they don't accumulate in GCP. Other access you already have is unaffected.

      ## 🎯 When to use it

      Use this building block when you:
      - need to debug a workload in a namespace you can't normally see.
      - want to inspect pods, logs, or configuration without asking for permanent cluster access.

      ## 💡 Usage examples

      **Example 1: Debugging a failing deployment**
      Your service in `payments` keeps restarting. You request 2 hours of access, run
      `gcloud container clusters get-credentials` as shown in the summary, and read the pod logs
      and events with `kubectl`.

      **Example 2: Checking configuration after a release**
      After a release you want to confirm which ConfigMaps and image versions are running. You
      request 1 hour of access and inspect the namespace's resources.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Decide which namespaces can't be requested and which role is granted | ✅ | ❌ |
      | Remove access when it expires | ✅ | ❌ |
      | Request only the namespace and time you need | ❌ | ✅ |
      | Sign in to `gcloud` with the Google account matching your meshStack email | ❌ | ✅ |
      EOT
    ))
    support_url       = ""
    documentation_url = ""
    target_type       = "WORKSPACE_LEVEL"

    # A run after expiry destroys the expired grants. This is only for cleanup, the timely
    # revocation comes from the CronJob and the IAM condition.
    schedule = {
      mode               = "DRIFT_RECONCILIATION"
      frequency          = "DAILY"
      automatic_approval = true
    }
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"
    runner_ref = var.building_block_runner_uuid == null ? null : {
      kind = "meshBuildingBlockRunner"
      uuid = var.building_block_runner_uuid
    }

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/gcp/gke-temporary-access/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      GOOGLE_APPLICATION_CREDENTIALS = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Google Application Credentials"
        description     = "The path to the Google application credentials JSON file for authentication."
        is_environment  = true
        argument        = jsonencode("./CREDENTIALS_FILE")
      }
      CREDENTIALS_FILE = {
        type            = "FILE"
        assignment_type = "STATIC"
        display_name    = "Credentials File"
        description     = "External account credentials that let the runner impersonate the building block's Google service account through workload identity federation."

        sensitive = {
          argument = {
            secret_value   = "data:application/json;base64,${base64encode(module.backplane.credentials_json)}"
            secret_version = nonsensitive(sha256("data:application/json;base64,${base64encode(module.backplane.credentials_json)}"))
          }
        }
      }
      project_id = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "GCP Project ID"
        description     = "GCP project ID that contains the GKE cluster."
        argument        = jsonencode(var.gcp_project_id)
      }
      cluster_name = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "GKE Cluster Name"
        description     = "Name of the GKE cluster."
        argument        = jsonencode(var.gke_cluster_name)
      }
      cluster_location = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "GKE Cluster Location"
        description     = "Region or zone of the GKE cluster."
        argument        = jsonencode(var.gke_cluster_location)
      }
      cluster_endpoint = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "GKE Cluster Endpoint"
        description     = "IP address or hostname of the cluster's control plane."
        argument        = jsonencode(data.google_container_cluster.this.endpoint)
      }
      cluster_ca_certificate = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "GKE Cluster CA Certificate"
        description     = "Base64-encoded CA certificate of the cluster's control plane."
        argument        = jsonencode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)
      }
      cluster_role = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Cluster Role"
        description     = "ClusterRole to bind the developer to."
        argument        = jsonencode(module.backplane.cluster_role)
      }
      binding_label = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Binding Label"
        description     = "Label key used to identify managed RoleBindings. The building block sets its value to `true`."
        argument        = jsonencode(module.backplane.binding_label)
      }
      expiry_annotation = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Expiry Annotation"
        description     = "Annotation key used to store the RoleBinding's expiry timestamp in RFC 3339 format (UTC)."
        argument        = jsonencode(module.backplane.expiry_annotation)
      }
      author = {
        type            = "CODE"
        assignment_type = "AUTHOR"
        display_name    = "Requester"
        description     = "The meshStack user who requested access. Access is granted to their Google account, whose email address must match their meshStack email."
      }
      forbidden_namespaces = {
        type            = "CODE"
        assignment_type = "STATIC"
        display_name    = "Forbidden Namespaces"
        description     = "Namespaces developers can't request access to. A trailing `*` matches a prefix."
        argument        = jsonencode(jsonencode(sort(tolist(module.backplane.forbidden_namespaces))))
      }
      namespace = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Namespace"
        description     = "Existing namespace you need access to. Namespaces restricted by the platform team are unavailable."
      }
      duration_hours = {
        type              = "SINGLE_SELECT"
        assignment_type   = "USER_INPUT"
        display_name      = "Duration (hours)"
        description       = "Access duration in whole hours, from 1 to 8, measured from the first run."
        selectable_values = [for hours in range(1, 9) : tostring(hours)]
        default_value     = jsonencode("2")
      }
    }

    outputs = {
      expires_at = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "Expires At"
        description     = "Access expiry timestamp in RFC 3339 format (UTC)."
      }
      summary = {
        type            = "STRING"
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        description     = "Markdown summary shown in meshPanel after the run."
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.26.2"
    }
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}
