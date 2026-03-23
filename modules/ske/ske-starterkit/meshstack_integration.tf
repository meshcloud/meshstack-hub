variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
}

variable "full_platform_identifier" {
  type = string
}

variable "landing_zone_identifiers" {
  type = object({
    dev  = string
    prod = string
  })
  description = "Identifiers of meshLandingZones for dev and prod."
}

variable "project_tags" {
  type = object({
    dev : map(list(string))
    prod : map(list(string))

    owner_tag_key = optional(string, null)
  })
  default     = { dev : {}, prod : {} }
  description = "Configure project tags of starter kit, for dev and prod."
}

variable "repo_clone_addr" {
  type        = string
  description = "URL to clone into the starterkit git repository."
}

variable "dns_zone_name" {
  type        = string
  description = "DNS zone name used for application ingress hostnames."
}

variable "add_random_name_suffix" {
  type        = bool
  default     = true
  description = "Whether to append a random suffix to starterkit names for shared environments."
}


variable "tags" {
  type    = map(list(string))
  default = {}
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "building_block_definitions" {
  type = map(object({
    uuid = string
    version_ref = object({
      content_hash = string # adding the content nicely tracks changes in dependent BBDs (draft mode)
      uuid         = string
    })
  }))
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  default     = {}
  description = <<-EOT
  `git_ref`: Hub reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br>
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

locals {
  name_regex = "^[a-zA-Z0-9-]{0,24}$" # underscore and dots not allowed because of K8s namespace, max length of 25 because of project character limit and suffixes added by the building block
}

output "building_block_definition" {
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
  description = "BBD can be consumed as-code for a subsequent BB run."
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.tags
  }

  spec = {
    description = chomp(<<-EOT
      The SKE Starterkit provides application teams with a pre-configured
      Kubernetes environment on STACKIT SKE following best practices. It
      automates the creation of dev and prod projects with dedicated SKE
      tenants.
    EOT
    )
    display_name             = "SKE Starterkit"
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/ske-starterkit/buildingblock/logo.png"
    notification_subscribers = var.notification_subscribers

    readme = chomp(<<-EOT
    ## What is it?

    The **SKE Starterkit** provides application teams with a pre-configured Kubernetes environment on STACKIT Kubernetes Engine (SKE) following best practices. It automates the creation of dev and prod projects with dedicated SKE tenants.

    ## When to use it?

    This building block is ideal for teams that:

    -   Want to deploy applications on Kubernetes without worrying about setting up infrastructure from scratch.
    -   Need a secure, best-practice-aligned environment for developing and deploying workloads on STACKIT.
    -   Prefer a streamlined setup with separate dev and prod environments.

    ## Resources Created

    This building block automates the creation of the following resources:

    - **STACKIT Git Forgejo Repository**: Code repository for application development and deployment.
    - **Development Project**
      - **SKE Tenant**: A dedicated Kubernetes namespace for development.
      - **SKE Forgejo Connector**: Provisions stage-specific namespace/repository wiring and outputs stage user permissions.
    - **Production Project**: You, as the creator, will have access to this project and SKE tenant.
      - **SKE Tenant**: A dedicated Kubernetes namespace for production.
      - **SKE Forgejo Connector**: Provisions stage-specific namespace/repository wiring and outputs stage user permissions.

    You, as the creator, will have access to the the Git repository, the projects and associated Kubernetes namespaces.

    ## Shared Responsibilities

    | Responsibility                               | Platform Team | Application Team |
    | -------------------------------------------- | ------------- | ---------------- |
    | Provision and manage SKE cluster             | ✅            | ❌                |
    | Create Kubernetes namespaces (dev/prod)      | ✅            | ❌                |
    | Create Forgejo Git repository                | ✅            | ❌                |
    | Manage K8s resources inside namespace        | ❌             | ✅               |
    | Develop and maintain application source code | ❌             | ✅               |
    | Maintain application configurations          | ❌             | ✅               |

    ---
    EOT
    )
    run_transparency = true
  }

  version_spec = {
    draft = var.hub.bbd_draft

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.11.5"
        async                          = false
        ref_name                       = var.hub.git_ref
        repository_path                = "modules/ske/ske-starterkit/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      "creator" = {
        assignment_type = "AUTHOR"
        type            = "CODE"
        display_name    = "Creator"
        description     = "Information about the creator of the resources who will be assigned Project Admin role."
      }
      "name" = {
        assignment_type                = "USER_INPUT"
        type                           = "STRING"
        display_name                   = "Project Name"
        description                    = "This name will be used for the created meshProjects and Kubernetes namespaces (SKE meshTenants) and Git repository."
        value_validation_regex         = local.name_regex
        validation_regex_error_message = "Does not match ${local.name_regex} (no underscore/dots allowed). A maximum length of 25 characters is allowed."
      }
      "workspace_identifier" = {
        assignment_type = "WORKSPACE_IDENTIFIER"
        type            = "STRING"
        display_name    = "Workspace Identifier"
        description     = "Workspace where the starter kit will be provisioned."
      }
      "full_platform_identifier" = {
        assignment_type = "STATIC"
        type            = "STRING"
        display_name    = "Full Platform Identifier"
        argument        = jsonencode(var.full_platform_identifier)
      }
      "landing_zone_identifiers" = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Landing Zone Identifiers for Dev/Prod."
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.landing_zone_identifiers))
      }
      "project_tags" = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Project Tags"
        description     = "Tags for the created Dev/Prod projects."
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.project_tags))
      }
      "repo_clone_addr" = {
        assignment_type = "STATIC"
        type            = "STRING"
        display_name    = "Clone from URL"
        argument        = jsonencode(var.repo_clone_addr)
      }
      "dns_zone_name" = {
        assignment_type = "STATIC"
        type            = "STRING"
        display_name    = "DNS Zone Name"
        argument        = jsonencode(var.dns_zone_name)
      }
      "add_random_name_suffix" = {
        assignment_type = "STATIC"
        type            = "BOOLEAN"
        display_name    = "Add Random Name Suffix"
        argument        = jsonencode(var.add_random_name_suffix)
      }
      "building_block_definitions" = {
        assignment_type = "STATIC"
        type            = "CODE"
        description     = "Definitions used to create auxiliary building blocks (composition)."
        display_name    = "BBDs"
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.building_block_definitions))
      },

    }

    outputs = {
      "app_link_dev" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Open App Dev"
        type            = "STRING"
      }
      "app_link_prod" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Open App Prod"
        type            = "STRING"
      }
    }

    permissions = [
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "PROJECTPRINCIPALROLE_LIST",
      "PROJECTPRINCIPALROLE_SAVE",
      "PROJECTPRINCIPALROLE_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "PROJECT_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
      "TENANT_DELETE",
    ]
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
    }
  }
}
