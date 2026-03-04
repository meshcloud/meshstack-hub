locals {
  workspace_identifier = "<WORKSPACE_IDENTIFIER>"
  gcp_project          = "<GCP_PROJECT_ID>"
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "0.19.1"
    }
  }
}

# fill in your meshStack API endpoint and credentials here
# Create an API key in your workspace with permissions:
# - "Integrations":Read (to allow the building block to read part of the workload identity federation configuration)
# - "Building Blocks Definitions": Read, Write, Delete (to manage the building block definition lifecycle)
# and generated
provider "meshstack" {
  # endpoint  = ""
  # apikey    = ""
  # apisecret = ""
}

# Retrieve the workload identity federation configuration from meshStack.
# The building block runners share the same OIDC issuer and audience as meshStack integrations,
# so we reuse this data source to avoid hardcoding those values.
data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "./backplane"

  project_id = local.gcp_project
  workload_identity_federation = {
    workload_identity_pool_identifier = "meshstack-building-block-pool"
    audience                          = data.meshstack_integrations.integrations.workload_identity_federation.replicator.gcp.audience
    issuer                            = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      # Grants access to all building block definitions in this workspace.
      # To restrict access to a specific BBD, append its UUID after the first apply:
      # ":workspace.<WORKSPACE_IDENTIFIER>.buildingblockdefinition.<BBD_UUID>"
      # (The BBD UUID is only available after resources are created)
      # The subject prefix is derived from the replicator subject, which shares the same
      # "system:serviceaccount:<meshstack_identifier>" namespace prefix as building block runners.
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${local.workspace_identifier}.buildingblockdefinition"
    ]
    subject_token_file_path = "/var/run/secrets/workload-identity/gcp/token"
  }
}

resource "meshstack_building_block_definition" "gcp_storage_bucket" {
  metadata = {
    owned_by_workspace = local.workspace_identifier
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
    draft = true

    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/gcp/storage-bucket/buildingblock"
        ref_name                       = "main"
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      GOOGLE_APPLICATION_CREDENTIALS = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "Google Application Credentials",
        description     = "The path to the Google application credentials JSON file for authentication."
        is_environment  = true
        argument        = jsonencode("./CREDENTIALS_FILE")
      }
      CREDENTIALS_FILE = {
        type            = "FILE"
        assignment_type = "STATIC"
        display_name    = "Credentials File",
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
        display_name    = "GCP Project ID",
        description     = "The ID of the GCP project where the storage bucket will be created."
        argument        = jsonencode(local.gcp_project)
      }
      location = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Bucket Location",
        description     = "The location/region where the GCP storage bucket will be created."
        default_value   = jsonencode("europe-west1")
      }
      bucket_name = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "Bucket Name",
        description     = "The name of the GCP storage bucket to be created."
      }
      labels = {
        type            = "CODE"
        assignment_type = "USER_INPUT"
        display_name    = "Labels",
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
      },
      bucket_url = {
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
        display_name    = "GCP Bucket URL"
        description     = "The URL of the created GCP bucket"
      },
      bucket_self_link = {
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
        display_name    = "GCP Bucket Self Link"
        description     = "The self link of the created GCP bucket"
      },
      summary = {
        type            = "STRING"
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        description     = "A markdown summary of the created GCP bucket with details"
      }
    }
  }
}
