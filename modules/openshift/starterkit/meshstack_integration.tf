variable "platform_ref" {
  type = object({
    uuid = string
    kind = string
  })
  description = "The `.ref` of the OpenShift meshPlatform the tenants are created on."
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

variable "building_block_definition_version_refs" {
  type = map(object({
    uuid = string
  }))
  description = "Building block definition versions the starter kit creates its child building blocks from, keyed by definition name: `git-repository` (`github/repository`) and `github-actions-connector` (`openshift/github-connector`)."
}

variable "github_org" {
  type        = string
  description = "GitHub organization the repositories are created in (example: `acme-platform`)."
}

variable "github_template_repo_path" {
  type        = string
  description = "Template repository new application repositories are created from, as `owner/repo` (example: `acme-platform/openshift-starterkit-template`)."
}

variable "openshift_apps_domain" {
  type        = string
  description = "Wildcard domain of the cluster's default router (example: `apps.ocp.example.com`)."
}

variable "add_random_name_suffix" {
  type        = bool
  default     = true
  description = "Whether to append a random suffix to the ordered name, so teams can reuse a name on a shared cluster."
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
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
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
  })
  description = "Shared meshStack context, see docs."
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
  description = "BBD can be consumed as-code for a subsequent BB run."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  # No underscores or dots, as the name ends up in namespaces and hostnames. 25 characters at most,
  # leaving room in the project name for the stage and the random suffix.
  name_regex = "^[a-zA-Z0-9-]{0,24}$"

  stages = sort(keys(var.landing_zone_refs))
  # The readme renders markdown, the description is plain text.
  stage_list       = join(", ", [for stage in local.stages : "`${stage}`"])
  stage_list_plain = join(", ", local.stages)
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "OpenShift Starterkit")
    description              = coalesce(var.bbd_description, "A ready-to-deploy OpenShift environment: one project per stage (${local.stage_list_plain}), a GitHub repository from a template and a GitHub Actions pipeline that deploys into every stage.")
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/openshift/starterkit/buildingblock/logo.png"
    notification_subscribers = var.notification_subscribers
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **OpenShift Starterkit** gets your application running on OpenShift in minutes. It creates one project per stage this platform offers (${local.stage_list}), each with its own OpenShift namespace, plus a GitHub repository from a template whose GitHub Actions workflow builds your image and deploys it to every stage.

    ## 🎯 When to use it

    Use this building block when you:
    - Start a new application and want to deploy to OpenShift without setting up namespaces, registry access and pipelines yourself.
    - Want separate, isolated namespaces per stage with a promotion path from `main` to `release`.

    ## 💡 Usage examples

    **Example 1: A new microservice**
    A developer orders the starterkit with the name `payments`, clones the new repository and pushes a change. The pipeline builds the image into the cluster's registry and the app answers at its dev hostname a few minutes later.

    **Example 2: Promote to production**
    Once dev looks good, the team merges `main` into `release`. The production environment of the workflow deploys the same code into the prod namespace.

    ## 📦 What you get

    - A **GitHub repository** from the platform team's template, with Dockerfile, manifests and workflow.
    - **One project per stage**, each with:
      - An **OpenShift namespace** you are Project Admin of.
      - A **GitHub Actions connector** that lets the stage's GitHub environment deploy into it.

    Your images must run as an arbitrary non-root user, as OpenShift's `restricted-v2` security context constraint requires.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the OpenShift cluster, router and internal registry | ✅ | ❌ |
    | Create one namespace per stage and wire it to GitHub Actions | ✅ | ❌ |
    | Maintain the template repository | ✅ | ❌ |
    | Develop and maintain the application source code | ❌ | ✅ |
    | Manage Kubernetes resources inside the namespaces | ❌ | ✅ |
    | Promote releases and monitor the application | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft      = var.hub.bbd_draft
    runner_ref = var.meshstack.runner_ref

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/openshift/starterkit/buildingblock"
        ref_name                       = var.hub.git_ref
        terraform_version              = "1.12.5"
        use_mesh_http_backend_fallback = true
        pre_run_script                 = file("${path.module}/buildingblock/prerun.sh")
      }
    }

    inputs = {
      creator = {
        display_name    = "Creator"
        description     = "Information about the creator of the resources who will be assigned Project Admin role."
        type            = "CODE"
        assignment_type = "AUTHOR"
      }
      name = {
        display_name                   = "Project Name"
        description                    = "Used for the meshProjects, the OpenShift namespaces, the GitHub repository and the app hostnames."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = local.name_regex
        validation_regex_error_message = "Does not match ${local.name_regex} (no underscore/dots allowed). A maximum length of 25 characters is allowed."
      }
      repo_admin = {
        display_name    = "Repository Admin"
        description     = "GitHub handle that becomes admin of the repository. Leave it blank to add no one."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
      }
      workspace_identifier = {
        display_name    = "Workspace Identifier"
        description     = "Workspace where the starter kit will be provisioned."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }
      platform_ref = {
        display_name    = "Platform Reference"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.platform_ref))
      }
      landing_zone_refs = {
        display_name    = "Landing Zone References per Stage"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.landing_zone_refs))
      }
      project_tags = {
        display_name    = "Project Tags"
        description     = "Tags for the created projects, per stage."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.project_tags))
      }
      building_block_definition_version_refs = {
        display_name    = "BBD Version References"
        description     = "Definition versions the starter kit creates its child building blocks from."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.building_block_definition_version_refs))
      }
      github_org = {
        display_name    = "GitHub Organization"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.github_org)
      }
      github_template_repo_path = {
        display_name    = "GitHub Template Repository"
        description     = "Template repository new application repositories are created from, as `owner/repo`."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.github_template_repo_path)
      }
      apps_domain = {
        display_name    = "Apps Domain"
        description     = "Wildcard domain of the cluster's default router."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.openshift_apps_domain)
      }
      add_random_name_suffix = {
        display_name    = "Add Random Name Suffix"
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.add_random_name_suffix)
      }
    }

    outputs = merge(
      {
        for stage in local.stages : "app_link_${stage}" => {
          display_name    = "Open App ${title(stage)}"
          type            = "STRING"
          assignment_type = "RESOURCE_URL"
        }
      },
      {
        github_repo_url = {
          display_name    = "GitHub"
          type            = "STRING"
          assignment_type = "RESOURCE_URL"
        }
        summary = {
          display_name    = "Summary"
          type            = "STRING"
          assignment_type = "SUMMARY"
        }
      }
    )

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
      version = ">= 0.27.0"
    }
  }
}
