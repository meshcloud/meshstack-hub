variable "platform_ref" {
  type = object({
    uuid = string
    kind = string
  })
  description = "The `.ref` of the meshPlatform the tenants are created on."
}

variable "landing_zone_refs" {
  type        = map(object({ name = string, kind = string }))
  description = "Landing zone references keyed by stage. The keys decide which stages the starter kit creates, and the definition declares one app link output per key."
}

variable "project_tags" {
  type = object({
    stages        = map(map(list(string)))
    owner_tag_key = optional(string, null)
  })
  default     = { stages = {}, owner_tag_key = null }
  description = "Tags for the meshProjects the starter kit creates. `stages` is keyed as `landing_zone_refs`; `owner_tag_key` names the tag that receives the creator's display name."
}

variable "app_name" {
  type        = string
  nullable    = false
  description = "Image name every application from this platform builds under, passed to its pipeline as APP_NAME."
}

variable "repo_clone_addr" {
  type        = string
  description = "Repository URL used to initialize the project repository (example: `https://git.example.com/org/sample-app.git`)."
}

variable "dns_zone_name" {
  type        = string
  description = "DNS zone used for generated app endpoints (example: `apps.example.com`)."
}

variable "add_random_name_suffix" {
  type    = bool
  default = true
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "building_block_definition_version_refs" {
  type = map(object({
    uuid = string
  }))
  description = "Building block definition versions the starter kit creates its child building blocks from, keyed by definition name (`git-repository` and `forgejo-connector`)."
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

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string

    tags = optional(map(list(string)), {})
  })
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
  `git_ref`: Hub reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br>
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
  description = "BBD can be consumed as-code for a subsequent BB run."
}

locals {
  name_regex = "^[a-zA-Z0-9-]{0,24}$" # underscore and dots not allowed because of K8s namespace, max length of 25 because of project character limit and suffixes added by the building block

  stages     = sort(keys(var.landing_zone_refs))
  stage_list = join(", ", [for stage in local.stages : "`${stage}`"])
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    description = coalesce(var.bbd_description, chomp(<<-EOT
      The SKE Starterkit provides application teams with a pre-configured
      Kubernetes environment on STACKIT SKE following best practices. It
      creates one project with a dedicated SKE tenant per stage: ${local.stage_list}.
    EOT
    ))
    display_name             = coalesce(var.bbd_display_name, "SKE Starterkit")
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/ske-starterkit/buildingblock/logo.png"
    notification_subscribers = var.notification_subscribers

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **SKE Starterkit** provides application teams with a pre-configured Kubernetes environment on STACKIT Kubernetes Engine (SKE) following best practices. It creates one project with a dedicated SKE tenant per stage this platform offers: ${local.stage_list}.

    ## 🎯 When to use it

    This building block is ideal for teams that:

    -   Want to deploy applications on Kubernetes without worrying about setting up infrastructure from scratch.
    -   Need a secure, best-practice-aligned environment for developing and deploying workloads on STACKIT.
    -   Prefer a streamlined setup with one environment per stage.

    ## Resources Created

    This building block automates the creation of the following resources:

    - **STACKIT Git Forgejo Repository**: Code repository for application development and deployment.
    - **One project per stage** (${local.stage_list}), each with:
      - **SKE Tenant**: A dedicated Kubernetes namespace for that stage.
      - **SKE Forgejo Connector**: Provisions stage-specific namespace/repository wiring and outputs stage user permissions.

    You, as the creator, will have access to the Git repository, the projects and associated Kubernetes namespaces.

    ## Shared Responsibilities

    | Responsibility                               | Platform Team | Application Team |
    | -------------------------------------------- | ------------- | ---------------- |
    | Provision and manage SKE cluster             | ✅            | ❌                |
    | Create one Kubernetes namespace per stage    | ✅            | ❌                |
    | Create Forgejo Git repository                | ✅            | ❌                |
    | Manage K8s resources inside namespace        | ❌             | ✅               |
    | Develop and maintain application source code | ❌             | ✅               |
    | Maintain application configurations          | ❌             | ✅               |

    ---
    EOT
    ))
    run_transparency = true
  }

  version_spec = {
    draft = var.hub.bbd_draft

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.12.5"
        async                          = false
        ref_name                       = var.hub.git_ref
        repository_path                = "modules/ske/ske-starterkit/buildingblock"
        use_mesh_http_backend_fallback = true
        pre_run_script                 = file("${path.module}/buildingblock/prerun.sh")
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
      "platform_ref" = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Platform Reference"
        argument        = jsonencode(jsonencode(var.platform_ref))
      }
      "landing_zone_refs" = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Landing Zone References per Stage"
        argument        = jsonencode(jsonencode(var.landing_zone_refs))
      }
      "project_tags" = {
        assignment_type = "STATIC"
        type            = "CODE"
        display_name    = "Project Tags"
        description     = "Tags for the created projects, per stage."
        argument        = jsonencode(jsonencode(var.project_tags))
      }
      "app_name" = {
        assignment_type = "STATIC"
        type            = "STRING"
        display_name    = "Application Image Name"
        description     = "Image name the pipeline builds under."
        argument        = jsonencode(var.app_name)
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
      "building_block_definition_version_refs" = {
        assignment_type = "STATIC"
        type            = "CODE"
        description     = "Definition versions the starter kit creates its child building blocks from."
        display_name    = "BBD Version References"
        argument        = jsonencode(jsonencode(var.building_block_definition_version_refs))
      }
    }

    outputs = {
      for stage in keys(var.landing_zone_refs) : "app_link_${stage}" => {
        assignment_type = "RESOURCE_URL"
        display_name    = "Open App ${title(stage)}"
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
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
  }
}
