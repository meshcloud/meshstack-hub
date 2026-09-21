variable "azuredevops_base_url" {
  type        = string
  default     = "https://dev.azure.com"
  description = "Base URL of the Azure DevOps instance. Override for Azure DevOps Server."
}

variable "azuredevops_organization" {
  type        = string
  description = "Azure DevOps organization name, as it appears in the URL after the base URL."
}

variable "azuredevops_personal_access_token" {
  type        = string
  sensitive   = true
  description = "Personal access token meshStack authenticates to Azure DevOps with. Needs Build (Read & execute) to queue pipeline runs, and Code (Read & write) for the backplane's commit — see backplane/README.md on splitting the two."
}

variable "azuredevops_project" {
  type        = string
  description = "Azure DevOps project holding the pipeline."
}

variable "azuredevops_pipeline_id" {
  type        = string
  description = "Numeric id of the Azure DevOps pipeline definition meshStack queues, as shown in the pipeline URL's `definitionId` query parameter. The definition must already exist — the backplane commits its YAML but cannot create it."
}

variable "azuredevops_repository_id" {
  type        = string
  description = "UUID of the Azure DevOps Git repository the pipeline definition reads its YAML from. Found under Project settings → Repositories → the repository, as the `repo` query parameter."
}

variable "azuredevops_ref_name" {
  type        = string
  default     = "refs/heads/main"
  description = "Full git ref the pipeline file is committed to and the pipeline runs on, for example 'refs/heads/main'. The branch must already exist."
}

variable "azuredevops_pipeline_yaml_path" {
  type        = string
  default     = "azure-pipelines.yml"
  description = "Repository path the pipeline file is committed to. Must match the YAML path the pipeline definition was created with."
}

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

variable "integration_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the meshStack integration this module registers."
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

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/azure-devops-pipeline/backplane?ref=${var.hub.git_ref}"

  azuredevops_base_url              = var.azuredevops_base_url
  azuredevops_organization          = var.azuredevops_organization
  azuredevops_personal_access_token = var.azuredevops_personal_access_token
  azuredevops_repository_id         = var.azuredevops_repository_id
  azuredevops_ref_name              = var.azuredevops_ref_name
  azuredevops_pipeline_yaml_path    = var.azuredevops_pipeline_yaml_path
}

resource "meshstack_integration" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name = coalesce(var.integration_display_name, "Azure DevOps Integration")
    config = {
      azuredevops = {
        base_url     = var.azuredevops_base_url
        organization = var.azuredevops_organization
        personal_access_token = {
          secret_value   = var.azuredevops_personal_access_token
          secret_version = nonsensitive(sha256(var.azuredevops_personal_access_token))
        }
      }
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = coalesce(var.bbd_display_name, "Azure DevOps Pipeline Building Block")
    description  = coalesce(var.bbd_description, "Reference building block demonstrating the AZURE_DEVOPS_PIPELINE implementation type: queues an Azure DevOps pipeline and reports each of its stages as a step.")
    target_type  = "WORKSPACE_LEVEL"
    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      This building block demonstrates meshStack's Azure DevOps pipeline implementation type, which
      queues a run of an Azure DevOps pipeline when a building block is applied. It provisions
      nothing: the pipeline checks that everything meshStack sent arrived and fails the run if it
      did not.

      ## 🎯 When to use it

      Use this building block when you want to:
      - Provision infrastructure or services from an Azure DevOps pipeline, ordered from the meshStack catalog.
      - Check that an Azure DevOps project, its agent pools and its pipeline are wired up correctly before writing automation of your own.
      - See how meshStack's inputs reach a pipeline, and what a pipeline can report back.
      EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft
    # A delete run queues the same pipeline once more with MESHSTACK_BEHAVIOR=DESTROY, so the ref
    # below must still carry the pipeline file when a building block is destroyed.
    deletion_mode = "DELETE"

    implementation = {
      azure_devops_pipeline = {
        project         = var.azuredevops_project
        pipeline_id     = var.azuredevops_pipeline_id
        ref_name        = module.backplane.ref_name
        integration_ref = meshstack_integration.this.ref
        async           = false
      }
    }

    inputs = {
      environment = {
        assignment_type = "USER_INPUT"
        display_name    = "Environment"
        type            = "STRING"
        description     = "Target deployment environment passed to the pipeline as a template parameter (e.g. dev, staging, prod)."
      }
    }

    outputs = {}
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.21.0"
    }
  }
}
