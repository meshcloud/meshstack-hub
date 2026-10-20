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

variable "otc_domain_name" {
  type        = string
  description = "T Cloud Public domain (account) name, e.g. `OTC-EU-DE-00000000001000000000`."
}

variable "otc_region" {
  type        = string
  default     = "eu-de"
  description = "T Cloud Public region buckets are created in."
}

variable "otc_auth_url" {
  type        = string
  default     = "https://iam.eu-de.otc.t-systems.com/v3"
  description = "IAM endpoint the building block authenticates against."
}

variable "workload_identity_name" {
  type        = string
  default     = "meshstack-obs-bucket"
  description = "Name of the identity provider and IAM group the building block signs in through. Unique across the domain."
}

variable "otc_platform_type" {
  type        = string
  default     = "OTC"
  description = "Name of the custom meshStack platform type whose tenants this building block is ordered on."
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

# Runs sign in through workload identity federation, so the definition carries no access key. This
# module's own provider credentials only set up the identity provider and its group.
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/otc/obs-bucket/backplane?ref=${var.hub.git_ref}"

  name = var.workload_identity_name
  workload_identity_federation = {
    issuer   = meshstack_building_block_definition.this.version_latest.workload_identity_federation.issuer
    subject  = meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject
    audience = meshstack_building_block_definition.this.version_latest.workload_identity_federation.gcp.audience
  }
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "T Cloud Public OBS Bucket")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/otc/obs-bucket/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Creates a private, KMS-encrypted OBS bucket with an access key that works only for that bucket.")
    support_url         = "https://console.otc.t-systems.com"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    supported_platforms = [{ name = var.otc_platform_type }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    This building block creates a private T Cloud Public OBS bucket, encrypted with its own KMS key,
    and an access key that works for this bucket only. Your application talks to it through the
    S3-compatible OBS endpoint.

    ## 🎯 When to use it

    Use this building block when you:
    - need object storage for files, backups or build artifacts;
    - want credentials for one application that cannot reach any other bucket.

    ## 💡 Usage examples

    **Example 1: Storing user uploads**
    A web application stores uploaded documents in the bucket. It reads the endpoint and the access
    and secret key from the building block outputs and uses any S3 client library.

    **Example 2: Backups with history**
    A nightly job writes database dumps to the bucket. With versioning on, an overwritten or deleted
    dump can still be restored.

    ## 📝 Good to know

    - Leave the bucket name empty to get one derived from your project name. A chosen name must be
      unique across all of T Cloud Public.
    - Deleting the building block keeps a bucket that still holds objects, unless you allowed it to
      delete them.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Create the bucket, its KMS key and the scoped access user | ✅ | ❌ |
    | Keep the bucket private and encrypted | ✅ | ❌ |
    | Store the access and secret key safely in the application | ❌ | ✅ |
    | Manage the objects and their lifecycle | ❌ | ✅ |
    EOT
    ))
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
        repository_path                = "modules/otc/obs-bucket/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
        pre_run_script                 = file("${path.module}/buildingblock/prerun.sh")
      }
    }

    inputs = {
      project_id = {
        display_name    = "Project ID"
        description     = "Application project the bucket is named after."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      region = {
        display_name    = "Region"
        description     = "Region the bucket and its KMS key are created in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.otc_region)
      }

      bucket_name = {
        display_name                   = "Bucket Name"
        description                    = "Leave empty to derive a name from the project. A chosen name must be unique across all of T Cloud Public."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        is_optional                    = true
        value_validation_regex         = "^[a-z0-9][a-z0-9-]{1,25}[a-z0-9]$"
        validation_regex_error_message = "3-27 lowercase letters, digits and hyphens, starting and ending with a letter or digit."
      }

      enable_versioning = {
        display_name           = "Keep Object Versions"
        description            = "Keep previous versions of overwritten and deleted objects."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(true)
        updateable_by_consumer = true
      }

      force_destroy = {
        display_name           = "Delete Objects With the Bucket"
        description            = "Delete all objects when the building block is deleted. Otherwise a bucket with objects in it is kept."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(false)
        updateable_by_consumer = true
      }

      OS_AUTH_URL = {
        display_name    = "OTC Auth URL"
        description     = "IAM endpoint the provider authenticates against."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_auth_url)
      }

      OS_DOMAIN_NAME = {
        display_name    = "OTC Domain Name"
        description     = "T Cloud Public domain the building block acts in."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.otc_domain_name)
      }

      OTC_IDENTITY_PROVIDER = {
        display_name    = "OTC Identity Provider"
        description     = "Identity provider the pre-run script exchanges the run token at."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.workload_identity_name)
      }
    }

    outputs = {
      bucket_name = {
        display_name    = "Bucket Name"
        type            = "STRING"
        assignment_type = "NONE"
      }

      obs_endpoint = {
        display_name    = "OBS Endpoint"
        type            = "STRING"
        assignment_type = "NONE"
      }

      access_key = {
        display_name    = "Access Key"
        type            = "STRING"
        assignment_type = "NONE"
      }

      secret_key = {
        display_name    = "Secret Key"
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
      version = ">= 0.26.2"
    }
    opentelekomcloud = {
      source  = "opentelekomcloud/opentelekomcloud"
      version = ">= 1.37.0, < 2.0.0"
    }
  }
}
