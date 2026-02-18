locals {
  env                  = "demo"
  workspace_identifier = "m25-platform"
  region               = "eu-central-1"
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "0.18.0"
    }
  }
}

# fill in your meshStack API endpoint and credentials here
provider "meshstack" {
  endpoint  = ""
  apikey    = ""
  apisecret = ""
}

provider "aws" {
  region = local.region
}

# Import the backplane module
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/s3_bucket/backplane?ref=main"

  # bucket is provided with WIF setup, fill in your WIF configuration here
  workload_identity_federation = {
    issuer   = ""
    audience = ""
    subjects = [
      "",
    ]
  }
}

# Import the building block definition into meshStack
resource "meshstack_building_block_definition" "awsS3Bucket" {
  metadata = {
    owned_by_workspace = local.workspace_identifier
    tags = {
      "BBEnvironment" = [local.env]
    }
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
    draft = true

    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/aws/s3_bucket/buildingblock"
        ref_name                       = "main"
        use_mesh_http_backend_fallback = false
      }
    }

    inputs = {
      AWS_ROLE_ARN = {
        type            = "STRING",
        display_name    = "AWS Role ARN",
        description     = "The ARN of the AWS role to assume for provisioning the S3 bucket",
        assignment_type = "STATIC",
        is_environment  = true
        argument        = jsonencode(module.backplane.workload_identity_federation_role)
      },
      AWS_WEB_IDENTITY_TOKEN_FILE = {
        type            = "STRING",
        assignment_type = "STATIC",
        display_name    = "AWS Web Identity Token File Path",
        description     = "The file path to the AWS web identity token for authentication",
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/aws/token")
      },
      region = {
        type            = "STRING",
        assignment_type = "STATIC",
        display_name    = "AWS Region"
        description     = "The AWS region where the S3 bucket will be created"
        argument        = jsonencode(local.region)
      },
      bucket_name = {
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_name    = "S3 Bucket Name"
        description     = "The name of the S3 bucket"
      },
    }

    outputs = {
      bucket_name = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket Name"
        description     = "The name of the created S3 bucket"
      },
      bucket_arn = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket ARN"
        description     = "The ARN of the created S3 bucket"
      },
      bucket_uri = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket URI"
        description     = "The URI of the created S3 bucket"
      },
      bucket_domain_name = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket Domain Name"
        description     = "The domain name of the created S3 bucket"
      },
      bucket_regional_domain_name = {
        type            = "STRING"
        assignment_type = "NONE"
        display_name    = "S3 Bucket Regional Domain Name"
        description     = "The regional domain name of the created S3 bucket"
      }
    }
  }
}
