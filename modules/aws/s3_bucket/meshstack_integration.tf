variable "aws_region" {
  type        = string
  description = "AWS region where the S3 bucket will be created (e.g. 'eu-central-1')."
}

variable "workload_identity" {
  type = object({
    issuer                   = string
    audience                 = string
    subject_namespace_prefix = string
  })
  description = "Workload identity federation configuration for AWS authentication."
}

variable "bb_environment" {
  type        = string
  description = "Value used for the BBEnvironment metadata tag (example: `prod`)."
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
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/s3_bucket/backplane?ref=b9c1f3f2201e7e22b04dbf71a3ceab7a0246a7b3"

  workload_identity_federation = {
    issuer   = var.workload_identity.issuer
    audience = var.workload_identity.audience
    subjects = ["system:serviceaccount:${var.workload_identity.subject_namespace_prefix}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = merge(var.meshstack.tags, { BBEnvironment = [var.bb_environment] })
  }

  spec = {
    display_name      = "AWS S3 Bucket"
    description       = "AWS S3 Bucket"
    readme            = "# Example Building Block\n"
    support_url       = "https://support.example.com/building-blocks"
    documentation_url = "https://docs.example.com/building-blocks"
    target_type       = "WORKSPACE_LEVEL"
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/aws/s3_bucket/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = false
      }
    }

    inputs = {
      AWS_ROLE_ARN = {
        type            = "STRING"
        display_name    = "AWS Role ARN"
        description     = "The ARN of the AWS role to assume for provisioning the S3 bucket"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.workload_identity_federation_role_arn)
      }
      AWS_WEB_IDENTITY_TOKEN_FILE = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "AWS Web Identity Token File Path"
        description     = "The file path to the AWS web identity token for authentication"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/aws/token")
      }
      region = {
        type            = "STRING"
        assignment_type = "STATIC"
        display_name    = "AWS Region"
        description     = "The AWS region where the S3 bucket will be created"
        argument        = jsonencode(var.aws_region)
      }
      bucket_name = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "S3 Bucket Name"
        description     = "The name of the S3 bucket"
      }
    }

    outputs = {
      bucket_name = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket Name"
        description     = "The name of the created S3 bucket"
      }
      bucket_arn = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket ARN"
        description     = "The ARN of the created S3 bucket"
      }
      bucket_uri = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket URI"
        description     = "The URI of the created S3 bucket"
      }
      bucket_domain_name = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket Domain Name"
        description     = "The domain name of the created S3 bucket"
      }
      bucket_regional_domain_name = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket Regional Domain Name"
        description     = "The regional domain name of the created S3 bucket"
      }
    }
  }
}

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.3"
    }
  }
}
