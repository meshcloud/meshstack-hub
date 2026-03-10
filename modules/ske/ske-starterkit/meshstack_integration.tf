terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.3"
    }
  }
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
}

variable "full_platform_identifier" {
  type    = string
  default = "stackit.ske"
}

variable "landing_zone_dev_identifier" {
  type    = string
  default = "ske-dev"
}

variable "landing_zone_prod_identifier" {
  type    = string
  default = "ske-prod"
}

variable "tags" {
  type    = map(list(string))
  default = {}
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "hub" {
  type = object({
    git_ref = string
  })
  default = {
    git_ref = "main"
  }
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo."
}

variable "project_tags_yaml" {
  type    = string
  default = <<-YAML
    dev:
      environment:
        - "dev"
    prod:
      environment:
        - "prod"
  YAML
}

resource "meshstack_building_block_definition" "ske_starterkit" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.tags
  }

  spec = {
    description              = "The SKE Starterkit provides application teams with a pre-configured Kubernetes environment on STACKIT SKE following best practices. It automates the creation of dev and prod projects with dedicated SKE tenants."
    display_name             = "SKE Starterkit"
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/main/modules/ske/ske-starterkit/buildingblock/logo.png"
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

-   **Development Project**: You, as the creator, will have access to this project and SKE tenant.
    -   **SKE Tenant**: A dedicated Kubernetes tenant for development.
-   **Production Project**: You, as the creator, will have access to this project and SKE tenant.
    -   **SKE Tenant**: A dedicated Kubernetes tenant for production.

## Shared Responsibilities

| Responsibility                               | Platform Team | Application Team |
| -------------------------------------------- | ------------- | ---------------- |
| Provision and manage SKE cluster             | ✅            | ❌               |
| Manage Kubernetes tenants (dev/prod)         | ✅            | ❌               |
| Manage resources inside tenants              | ❌            | ✅               |
| Develop and maintain application source code | ❌            | ✅               |
| Maintain application configurations          | ❌            | ✅               |

---
EOT
    )
    run_transparency = true
  }

  version_spec = {
    draft = true

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
        assignment_type        = "AUTHOR"
        description            = "Information about the creator of the resources who will be assigned Project Admin role"
        display_name           = "Creator"
        is_environment         = false
        type                   = "CODE"
        updateable_by_consumer = false
      }
      "full_platform_identifier" = {
        argument               = jsonencode(var.full_platform_identifier)
        assignment_type        = "STATIC"
        display_name           = "Full Platform Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "landing_zone_dev_identifier" = {
        argument               = jsonencode(var.landing_zone_dev_identifier)
        assignment_type        = "STATIC"
        display_name           = "Landing Zone Dev Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "landing_zone_prod_identifier" = {
        argument               = jsonencode(var.landing_zone_prod_identifier)
        assignment_type        = "STATIC"
        display_name           = "Landing Zone Prod Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "name" = {
        assignment_type        = "USER_INPUT"
        description            = "This name will be used for the created projects and SKE tenants"
        display_name           = "Name of the Project"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "project_tags_yaml" = {
        argument               = jsonencode(chomp(var.project_tags_yaml))
        assignment_type        = "STATIC"
        description            = "These tags will be used for the created projects."
        display_name           = "Project Tags"
        is_environment         = false
        type                   = "CODE"
        updateable_by_consumer = false
      }
      "workspace_identifier" = {
        assignment_type        = "WORKSPACE_IDENTIFIER"
        description            = "Workspace where the starterkit will be provisioned."
        display_name           = "Workspace Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
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
