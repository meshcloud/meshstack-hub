# Adapt these variables to your meshStack and STACKIT setup.

variable "hub" {
  type = object({
    git_ref = string
  })
  default = {
    git_ref = "main"
  }
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = "Shared meshStack context passed down from the IaC runtime."
}

variable "ske" {
  description = "SKE platform identifiers."
  type = object({
    full_platform_identifier     = string
    landing_zone_dev_identifier  = string
    landing_zone_prod_identifier = string
    cluster_server               = string
    cluster_ca_certificate       = string
  })
}

variable "gitea" {
  type = object({
    base_url     = string
    token        = string
    organization = string
  })
  sensitive   = true
  description = "STACKIT Git (Forgejo) credentials and organization."
}

variable "harbor" {
  type = object({
    url            = string
    robot_username = string
    robot_token    = string
  })
  sensitive   = true
  default     = null
  description = "Harbor registry credentials. When provided, stores push credentials as Forgejo Actions secrets and creates an image pull secret in each namespace."
}

variable "project_tags_yaml" {
  description = "YAML string defining tags for created projects."
  type        = string
  default     = <<-YAML
dev:
  environment:
    - "dev"
prod:
  environment:
    - "prod"
YAML
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
  }
}

module "backplane" {
  source = "./backplane"

  hub       = var.hub
  meshstack = var.meshstack
  gitea     = var.gitea
  harbor    = var.harbor
  ske = {
    cluster_server         = var.ske.cluster_server
    cluster_ca_certificate = var.ske.cluster_ca_certificate
  }
}

resource "meshstack_building_block_definition" "stackit_starterkit" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "The STACKIT Starterkit provides application teams with a pre-configured Kubernetes environment on STACKIT Kubernetes Engine (SKE). It includes a Git repository on STACKIT Git, dedicated dev/prod SKE namespaces, and Forgejo Actions CI/CD integration."
    display_name = "STACKIT Starterkit"
    symbol       = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")
    readme = chomp(<<EOT
## What is it?

The **STACKIT Starterkit** provides application teams with a pre-configured Kubernetes environment
on STACKIT Kubernetes Engine (SKE). It automates the creation of a Git repository, dedicated
Kubernetes namespaces for development and production, and CI/CD pipelines using Forgejo Actions.

## When to use it?

This building block is ideal for teams that:

- Want to deploy applications on a sovereign European Kubernetes platform
- Need separate dev/prod environments with proper access controls
- Want a Git repository set up and ready to go on STACKIT Git
- Want CI/CD pipelines automatically configured via Forgejo Actions

## Resources Created

- **STACKIT Git Repository**: A new repository on STACKIT Git (Forgejo/Gitea)
- **Development Project**: With a dedicated SKE namespace
  - **Forgejo Actions Connector**: Connects the Git repository to the dev SKE namespace
- **Production Project**: With a dedicated SKE namespace
  - **Forgejo Actions Connector**: Connects the Git repository to the prod SKE namespace
- **Project Admin Access**: The creator gets admin access to both projects

## Shared Responsibilities

| Responsibility                          | Platform Team | Application Team |
| --------------------------------------- | ------------- | ---------------- |
| Provision and manage SKE cluster        | ✅           | ❌              |
| Create and manage Git repository        | ✅           | ❌              |
| Set up Forgejo Actions CI/CD pipeline   | ✅           | ❌              |
| Manage Kubernetes namespaces (dev/prod) | ✅           | ❌              |
| Manage resources inside namespaces      | ❌           | ✅              |
| Develop and maintain application code   | ❌           | ✅              |

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
        repository_path                = "modules/stackit/ske/starterkit/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }
    inputs = {
      "creator" = {
        assignment_type = "AUTHOR"
        description     = "Information about the creator who will be assigned Project Admin role"
        display_name    = "Creator"
        type            = "CODE"
      }
      "workspace_identifier" = {
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_name    = "Workspace Identifier"
        type            = "STRING"
      }
      "name" = {
        assignment_type = "USER_INPUT"
        description     = "This name will be used for the created projects, SKE namespaces, and Git repository"
        display_name    = "Name of the Project"
        type            = "STRING"
      }
      "full_platform_identifier" = {
        argument        = jsonencode(var.ske.full_platform_identifier)
        assignment_type = "STATIC"
        display_name    = "Full Platform Identifier"
        type            = "STRING"
      }
      "landing_zone_dev_identifier" = {
        argument        = jsonencode(var.ske.landing_zone_dev_identifier)
        assignment_type = "STATIC"
        display_name    = "Landing Zone Dev Identifier"
        type            = "STRING"
      }
      "landing_zone_prod_identifier" = {
        argument        = jsonencode(var.ske.landing_zone_prod_identifier)
        assignment_type = "STATIC"
        display_name    = "Landing Zone Prod Identifier"
        type            = "STRING"
      }
      "git_repo_definition_uuid" = {
        argument        = jsonencode(module.backplane.git_repo_bbd_uuid)
        assignment_type = "STATIC"
        display_name    = "Git Repo Definition UUID"
        type            = "STRING"
      }
      "git_repo_definition_version_uuid" = {
        argument        = jsonencode(module.backplane.git_repo_bbd_version_uuid)
        assignment_type = "STATIC"
        display_name    = "Git Repo Definition Version UUID"
        type            = "STRING"
      }
      "forgejo_connector_definition_version_uuid" = {
        argument        = jsonencode(module.backplane.forgejo_connector_bbd_version_uuid)
        assignment_type = "STATIC"
        display_name    = "Forgejo Actions Connector Definition Version UUID"
        type            = "STRING"
      }
      "project_tags_yaml" = {
        argument        = jsonencode(trimspace(var.project_tags_yaml))
        assignment_type = "STATIC"
        display_name    = "Project Tags"
        type            = "CODE"
      }
    }
    outputs = {
      "git_repo_url" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "STACKIT Git"
        type            = "STRING"
      }
      "summary" = {
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        type            = "STRING"
      }
    }
    permissions = [
      "BUILDINGBLOCK_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "PROJECTPRINCIPALROLE_DELETE",
      "PROJECTPRINCIPALROLE_LIST",
      "PROJECTPRINCIPALROLE_SAVE",
      "PROJECT_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "TENANT_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
    ]
  }
}

output "bbd_uuid" {
  description = "UUID of the STACKIT Starterkit building block definition."
  value       = meshstack_building_block_definition.stackit_starterkit.ref.uuid
}

output "bbd_version_uuid" {
  description = "UUID of the latest version of the STACKIT Starterkit building block definition."
  value       = meshstack_building_block_definition.stackit_starterkit.version_latest.uuid
}
