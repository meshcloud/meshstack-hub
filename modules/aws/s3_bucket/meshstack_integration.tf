locals {
  env                  = "demo"
  workspace_identifier = "m25-platform"
  region               = "eu-central-1"
  issuer = "https://container.googleapis.com/v1/projects/meshcloud-meshcloud--bc0/locations/europe-west1/clusters/meshstacks-ha"
  audience = "aws-workload-identity-provider:meshcloud-demo"
  role_name = "BuildingBlockS3IdentityFederation-${random_string.name_suffix.result}"
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.12.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "0.18.0"
    }
  }
}

# fill in your meshStack API endpoint and credentials here
provider "meshstack" {
}

provider "aws" {
  region = local.region
}

# backplane

resource "random_string" "name_suffix" {
  length  = 4
  special = false
}

data "aws_iam_policy_document" "s3_full_access" {
  statement {
    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::*",
    ]
  }
}

resource "aws_iam_policy" "buildingblock_s3_policy" {
  name        = "S3BuildingBlockFederatedPolicy-${random_string.name_suffix.result}"
  description = "Policy for the S3 Building Block"
  policy      = data.aws_iam_policy_document.s3_full_access.json
}

# Workload Identity Federation

resource "aws_iam_openid_connect_provider" "buildingblock_oidc_provider" {
  url            = local.issuer
  client_id_list = [local.audience]
}

data "aws_iam_policy_document" "workload_identity_federation" {
  version = "2012-10-17"

  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.buildingblock_oidc_provider.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${trimprefix(local.issuer, "https://")}:aud"

      values = [local.audience]
    }

    condition {
      test     = "StringLike"
      variable = "${trimprefix(local.issuer, "https://")}:sub"

      values = ["system:serviceaccount:meshcloud-demo:workspace.${local.workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.awsS3Bucket.metadata.uuid}"]
    }
  }
}

resource "aws_iam_role" "assume_federated_role" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.workload_identity_federation.json
}

resource "aws_iam_role_policy_attachment" "buildingblock_s3" {
  role       = aws_iam_role.assume_federated_role.name
  policy_arn = aws_iam_policy.buildingblock_s3_policy.arn
}


output "workload_identity_federation_role" {
  value = aws_iam_role.assume_federated_role.arn
}

output "definition_uuid" {
  value = meshstack_building_block_definition.awsS3Bucket.metadata.uuid
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
        argument        = jsonencode("arn:aws:iam::${split(":", aws_iam_openid_connect_provider.buildingblock_oidc_provider.arn)[4]}:role/${local.role_name}")
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
