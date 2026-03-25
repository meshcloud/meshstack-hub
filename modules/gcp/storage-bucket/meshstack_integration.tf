variable "gcp_project_id" {
  type        = string
  description = "GCP project ID where the storage bucket will be created."
}

variable "workload_identity" {
  type = object({
    pool_identifier         = optional(string, "meshstack-building-block-pool")
    subject_token_file_path = optional(string, "/var/run/secrets/workload-identity/gcp/token")
  })
  default     = {}
  description = "Workload identity federation settings for GCP authentication."
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
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.gcp_storage_bucket.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.gcp_storage_bucket.version_latest : meshstack_building_block_definition.gcp_storage_bucket.version_latest_release
  }
}

# Retrieve the workload identity federation configuration from meshStack.
# The building block runners share the same OIDC issuer and audience as meshStack integrations,
# so we reuse this data source to avoid hardcoding those values.
data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/gcp/storage-bucket/backplane?ref=b9c1f3f2201e7e22b04dbf71a3ceab7a0246a7b3"

  project_id = var.gcp_project_id
  workload_identity_federation = {
    workload_identity_pool_identifier = var.workload_identity.pool_identifier
    audience                          = data.meshstack_integrations.integrations.workload_identity_federation.replicator.gcp.audience
    issuer                            = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition"
    ]
    subject_token_file_path = var.workload_identity.subject_token_file_path
  }
}

resource "meshstack_building_block_definition" "gcp_storage_bucket" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name      = "GCP Storage Bucket"
    description       = "Provides a GCP Cloud Storage bucket for object storage."
    readme            = <<EOT
# GCP Storage Bucket

## Description

Provides a GCP Cloud Storage bucket for object storage.
EOT
    support_url       = ""
    documentation_url = ""
    target_type       = "WORKSPACE_LEVEL"
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/gcp/storage-bucket/buildingblock"
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
        description     = "The credentials file containing the Google application credentials JSON content. This input is used to securely pass the credentials content to the building block."

        sensitive = {
          argument = {
            secret_value   = "data:application/json;base64,${base64encode(module.backplane.credentials_json)}"
            secret_version = null
          }
        }
      }
      project_id = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "GCP Project ID"
        description     = "The ID of the GCP project where the storage bucket will be created."
        argument        = jsonencode(var.gcp_project_id)
      }
      location = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Bucket Location"
        description     = "The location/region where the GCP storage bucket will be created."
        default_value   = jsonencode("europe-west1")
      }
      bucket_name = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Bucket Name"
        description     = "The name of the GCP storage bucket to be created."
      }
      labels = {
        type            = "CODE"
        assignment_type = "USER_INPUT"
        display_name    = "Labels"
        description     = "A list of labels to apply to the resource."
        default_value   = jsonencode("[\"env:dev\",\"team:backend\",\"project:myapp\"]")
      }
    }

    outputs = {
      bucket_name = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "GCP Bucket Name"
        description     = "The name of the created GCP bucket"
      }
      bucket_url = {
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
        display_name    = "GCP Bucket URL"
        description     = "The URL of the created GCP bucket"
      }
      bucket_self_link = {
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
        display_name    = "GCP Bucket Self Link"
        description     = "The self link of the created GCP bucket"
      }
      summary = {
        type            = "STRING"
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        description     = "A markdown summary of the created GCP bucket with details"
      }
    }
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.3"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
