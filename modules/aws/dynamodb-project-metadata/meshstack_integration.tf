variable "workspace_identifier" {
  type        = string
  description = "meshStack workspace identifier."
}

variable "aws_region" {
  type        = string
  description = "AWS region where the DynamoDB table will be created (e.g. 'eu-central-1')."
}

variable "notification_subscribers" {
  type        = list(string)
  default     = []
  description = "List of email addresses to notify on building block lifecycle events."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
  default = {
    owning_workspace_identifier = var.workspace_identifier
  }
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const       = true
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

data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/dynamodb-project-metadata/backplane?ref=${var.hub.git_ref}"

  workload_identity_federation = {
    issuer   = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    audience = data.meshstack_integrations.integrations.workload_identity_federation.replicator.aws.audience
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
    display_name             = "AWS DynamoDB Project Metadata"
    description              = "Pushes meshStack project metadata (tags, team members) into a central DynamoDB table."
    support_url              = "mailto:support@example.com"
    notification_subscribers = var.notification_subscribers
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AWS" }]

    readme = chomp(<<-EOT
      Automatically syncs meshStack project metadata into a central AWS DynamoDB table whenever this
      building block is assigned to a tenant. This eliminates the need for long-lived meshStack API
      credentials in your AWS organization — metadata is pushed from meshStack using workload identity
      federation (no static API keys).

      Each tenant gets one DynamoDB item keyed by `workspace_identifier` + `project_identifier`. The
      item contains the workspace, project, platform identifier, all project tags, and current team
      members with their roles.

      ## When to use it

      Use this building block when you need meshStack project data available inside your AWS
      organization without polling the meshStack API with static credentials:

      - Feed project ownership and cost-centre tags into AWS Cost Explorer via DynamoDB.
      - Drive IAM permission boundaries or SCPs with project-level metadata.
      - Provide a CMDB-like inventory of all meshStack tenants in your AWS org.

      ## Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Deploy backplane (DynamoDB table + IAM role) | ✅ | ❌ |
      | Assign building block to tenants | ✅ | ❌ |
      | Consume DynamoDB data in tooling/pipelines | ✅ | ❌ |
      | Keep meshStack project tags up to date | ❌ | ✅ |
      | Manage team membership in meshStack | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/aws/dynamodb-project-metadata/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      AWS_ROLE_ARN = {
        type            = "STRING"
        display_name    = "AWS Role ARN"
        description     = "ARN of the IAM role assumed by the building block runtime via workload identity federation."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.workload_identity_federation_role_arn)
      }
      AWS_WEB_IDENTITY_TOKEN_FILE = {
        type            = "STRING"
        display_name    = "AWS Web Identity Token File"
        description     = "Path to the OIDC token file used for workload identity federation."
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/aws/token")
      }
      aws_region = {
        type            = "STRING"
        display_name    = "AWS Region"
        description     = "AWS region where the DynamoDB table is located."
        assignment_type = "STATIC"
        argument        = jsonencode(var.aws_region)
      }
      aws_dynamodb_table_name = {
        type            = "STRING"
        display_name    = "DynamoDB Table Name"
        description     = "Name of the DynamoDB table to write project metadata to."
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.table_name)
      }
      workspace_identifier = {
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "meshStack workspace identifier. Used as the DynamoDB partition key."
        assignment_type = "WORKSPACE_IDENTIFIER"
      }
      project_identifier = {
        type            = "STRING"
        display_name    = "Project Identifier"
        description     = "meshStack project identifier. Used as the DynamoDB sort key."
        assignment_type = "PROJECT_IDENTIFIER"
      }
      platform_identifier = {
        type            = "STRING"
        display_name    = "Platform Identifier"
        description     = "meshStack platform identifier (AWS account ID for AWS tenants)."
        assignment_type = "PLATFORM_TENANT_ID"
      }
      users = {
        type            = "CODE"
        display_name    = "Team Members"
        description     = "Project team members with their roles, injected by meshStack."
        assignment_type = "USER_PERMISSIONS"
      }
    }

    outputs = {
      dynamodb_item_key = {
        type            = "STRING"
        display_name    = "DynamoDB Item Key"
        description     = "Composite key of the written DynamoDB item (workspace/project)."
        assignment_type = "SUMMARY"
      }
      dynamodb_table_name = {
        type            = "STRING"
        display_name    = "DynamoDB Table Name"
        description     = "Name of the DynamoDB table the metadata was written to."
        assignment_type = "NONE"
      }
      dynamodb_item_url = {
        type            = "STRING"
        display_name    = "Open in AWS Console"
        description     = "Direct link to the DynamoDB item in the AWS Console."
        assignment_type = "RESOURCE_URL"
      }
    }

    permissions = [
      "PROJECT_LIST",
    ]
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0"
    }
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.22.0"
    }
  }
}
