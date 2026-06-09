variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where Object Storage buckets will be created."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const       = true
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/storage-bucket/backplane?ref=${var.hub.git_ref}"

  project_id = var.stackit_project_id

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = "STACKIT Storage Bucket"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/storage-bucket/buildingblock/logo.png"
    description      = "Provisions an S3-compatible Object Storage bucket on STACKIT with access credentials."
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true
    readme = chomp(<<-EOT
      This building block provisions an **S3-compatible Object Storage bucket on STACKIT** with
      dedicated access credentials, so your team can store and retrieve files without managing
      the underlying infrastructure.

      ## 🎯 When to use it

      Use this building block when your application team needs:
      - A dedicated S3-compatible bucket on STACKIT for application data, backups, or static assets.
      - Isolated object storage per workspace with separate access credentials.

      ## 💡 Usage examples

      **Example 1: Storing application data**
      A backend service stores user-uploaded files in a STACKIT Object Storage bucket.
      The building block provisions the bucket and outputs S3 credentials for the application.

      **Example 2: Build artifact cache**
      A CI pipeline caches build dependencies in a STACKIT bucket, reducing build times
      while keeping artifacts isolated per project.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provision the Object Storage bucket | ✅ | ❌ |
      | Provide S3-compatible access credentials | ✅ | ❌ |
      | Choose bucket name and STACKIT project | ❌ | ✅ |
      | Manage objects and data lifecycle | ❌ | ✅ |
      | Secure and rotate application credentials | ❌ | ✅ |
      EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.11.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/storage-bucket/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project ID where the bucket will be created."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.project_id)
      }

      service_account_email = {
        display_name    = "Service Account Email"
        description     = "Email of the STACKIT service account for WIF-based authentication."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.service_account_email)
      }

      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        description     = "Enables OIDC-based WIF for the STACKIT provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }

      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        description     = "Path to the WIF token file injected by meshStack."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/stackit/token")
      }

      admin_s3_access_key = {
        display_name    = "Admin S3 Access Key"
        description     = "S3 access key for the admin credentials group used to manage bucket policies."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = module.backplane.admin_s3_access_key
          }
        }
      }

      admin_s3_secret_access_key = {
        display_name    = "Admin S3 Secret Access Key"
        description     = "S3 secret access key for the admin credentials group used to manage bucket policies."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = module.backplane.admin_s3_secret_access_key
          }
        }
      }

      admin_credentials_group_urn = {
        display_name    = "Admin Credentials Group URN"
        description     = "URN of the admin credentials group used to manage bucket policies."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.admin_credentials_group_urn)
      }

      bucket_name = {
        display_name                   = "Bucket Name"
        description                    = "Name of the Object Storage bucket. Must be DNS-conformant (lowercase, 3-63 chars)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$"
        validation_regex_error_message = "Bucket name must be 3-63 characters, start and end with a lowercase letter or digit, and contain only lowercase letters, digits, hyphens, and dots."
      }
    }

    outputs = {
      bucket_url_path_style = {
        display_name    = "Open Bucket"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      bucket_name = {
        display_name    = "Bucket Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      bucket_url_virtual_hosted_style = {
        display_name    = "Virtual-Hosted URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      s3_access_key = {
        display_name    = "S3 Access Key"
        type            = "STRING"
        assignment_type = "NONE"
      }

      s3_secret_access_key = {
        display_name    = "S3 Secret Access Key"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.21.0"
    }
  }
}
