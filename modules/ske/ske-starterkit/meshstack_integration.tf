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
  })
  default     = { dev : {}, prod : {} }
  description = "Configure project tags of starter kit, for dev and prod."
}

variable "git_repository_template_path" {
  type        = bool
  default     = true
  description = "Path to Forgejo template repo for initial app repo setup"
}

variable "building_block_definition_version_refs" {
  type = map(object({
    kind = string
    uuid = string
  }))
}

variable "tags" {
  type    = map(list(string))
  default = {}
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "draft" {
  type        = bool
  default     = false
  description = "If true, allows changing the building block definition for upgrading dependent building blocks."
}

variable "hub" {
  type = object({
    git_ref = string
  })
  default = {
    git_ref = "main"
  }
  description = "Hub reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo."
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.tags
  }

  spec = {
    description              = "The SKE Starterkit provides application teams with a pre-configured Kubernetes environment on STACKIT SKE following best practices. It automates the creation of dev and prod projects with dedicated SKE tenants."
    display_name             = "SKE Starterkit"
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/ske-starterkit/buildingblock/logo.png"
    notification_subscribers = var.notification_subscribers

    readme = chomp(<<EOT
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
- **Production Project**: You, as the creator, will have access to this project and SKE tenant.
  - **SKE Tenant**: A dedicated Kubernetes namespace for production.

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
    draft = var.draft

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.9.0"
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
        assignment_type        = "USER_INPUT"
        type                   = "STRING"
        display_name           = "Project Name"
        description            = "This name will be used for the created meshProjects and Kubernetes namespaces (SKE meshTenants) and Git repository."
        value_validation_regex = "^[a-zA-Z0-9-]+$" # underscore and dots not allowed because of K8s namespace
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
      "git_repository_template_repo_path" = {
        assignment_type = "STATIC"
        type            = "STRING"
        display_name    = "Git Repository Template Path"
        argument        = jsonencode(var.git_repository_template_path)
      }
      "building_block_definition_version_refs" = {
        assignment_type = "STATIC"
        type            = "CODE"
        description     = "Refs used to create auxiliary building blocks (composition)."
        display_name    = "BBD Version Refs"
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument = jsonencode(jsonencode(var.building_block_definition_version_refs))
      }
    }

    outputs = {}

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
