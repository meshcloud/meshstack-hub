variable "openshift_api_server_url" {
  type        = string
  description = "URL of the OpenShift API server (example: `https://api.ocp.example.com:6443`)."
}

variable "openshift_api_server_ca_certificate" {
  type        = string
  default     = null
  description = "PEM CA bundle that verifies the API server, when it presents a certificate from another CA than the cluster's own."
}

variable "openshift_registry_host" {
  type        = string
  description = "Host of the internal image registry's default route (example: `default-route-openshift-image-registry.apps.ocp.example.com`)."
}

variable "github_org" {
  type        = string
  description = "GitHub organization the GitHub App is installed in and the repositories live in."
}

variable "github_app_id" {
  type        = string
  description = "ID of the GitHub App the building block authenticates as."
}

variable "github_app_installation_id" {
  type        = string
  description = "Installation ID of the GitHub App in `github_org`."
}

variable "github_app_pem_file" {
  type        = string
  sensitive   = true
  description = "PEM private key of the GitHub App."
}

variable "github_repo_definition_uuid" {
  type        = string
  description = "UUID of the `github/repository` building block definition whose repositories this connector connects to."
}

variable "github_workflow_filename" {
  type        = string
  default     = ""
  description = "Workflow the connector dispatches once a namespace is connected (example: `openshift-deploy.yml`). Empty skips the dispatch."
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
  source = "github.com/meshcloud/meshstack-hub//modules/openshift/github-connector/backplane?ref=${var.hub.git_ref}"

  api_server_url            = var.openshift_api_server_url
  api_server_ca_certificate = var.openshift_api_server_ca_certificate
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "GitHub Actions OpenShift Connector")
    description              = coalesce(var.bbd_description, "Connects a GitHub repository to an OpenShift project, so GitHub Actions builds images into the cluster's registry and deploys them into the project.")
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/openshift/github-connector/buildingblock/logo.png"
    notification_subscribers = var.notification_subscribers
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "OPENSHIFT" }]
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **GitHub Actions OpenShift Connector** connects a GitHub repository to your OpenShift project. GitHub Actions can then build container images, push them to the cluster's internal registry and deploy them into the project — without anyone handling cluster credentials by hand.

    ## 🎯 When to use it

    Use this building block when you:
    - Keep your application in GitHub and want every push to deploy to OpenShift.
    - Want one GitHub environment per stage, each allowed to deploy into its own project only.

    ## 💡 Usage examples

    **Example 1: Deploy on every push**
    A developer pushes to `main`. The workflow in the `development` environment builds the image, pushes it to the internal registry and rolls out the new version in the dev project.

    **Example 2: Gate production behind a release branch**
    The team connects the prod project to the `production` environment with `release` as deploy branch, and adds a required reviewer to that environment in GitHub.

    ## 📦 What you get

    - A `github-actions` service account in the project, allowed to edit resources and push images there.
    - A GitHub environment with the secrets `KUBECONFIG` and `OPENSHIFT_REGISTRY_TOKEN` and the variables `OPENSHIFT_NAMESPACE` and `OPENSHIFT_REGISTRY`.

    Images must run as an arbitrary non-root user, as OpenShift's `restricted-v2` security context constraint requires.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the OpenShift cluster and its internal registry | ✅ | ❌ |
    | Provide the GitHub App and the deployment credentials | ✅ | ❌ |
    | Restrict the pipeline's access to its own project | ✅ | ❌ |
    | Write the workflow, Dockerfile and manifests | ❌ | ✅ |
    | Protect environments and branches in GitHub | ❌ | ✅ |
    | Monitor deployments and troubleshoot failures | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft = var.hub.bbd_draft

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/openshift/github-connector/buildingblock"
        ref_name                       = var.hub.git_ref
        terraform_version              = "1.12.5"
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    dependency_refs = [{ uuid = var.github_repo_definition_uuid }]

    inputs = {
      GITHUB_OWNER = {
        display_name    = "GitHub Owner"
        description     = "GitHub organization the repositories live in."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.github_org)
      }
      GITHUB_APP_ID = {
        display_name    = "GitHub App ID"
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.github_app_id)
      }
      GITHUB_APP_INSTALLATION_ID = {
        display_name    = "GitHub App Installation ID"
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.github_app_installation_id)
      }
      GITHUB_APP_PEM_FILE = {
        display_name    = "GitHub App PEM File"
        type            = "CODE"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.github_app_pem_file
            secret_version = nonsensitive(sha256(var.github_app_pem_file))
          }
        }
      }
      namespace = {
        display_name    = "OpenShift Project"
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }
      kubernetes_api = {
        display_name    = "Kubernetes API"
        description     = "API server URL, CA bundle and token of the connector's backplane service account."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = jsonencode(module.backplane.kubernetes_api)
            secret_version = nonsensitive(sha256(jsonencode(module.backplane.kubernetes_api)))
          }
        }
      }
      registry_host = {
        display_name    = "Registry Host"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.openshift_registry_host)
      }
      workflow_filename = {
        display_name    = "Workflow Filename"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.github_workflow_filename)
      }
      github_repo = {
        display_name    = "GitHub Repository"
        description     = "Repository to connect, from the parent repository building block."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.github_repo_definition_uuid}.repo_name")
      }
      github_environment_name = {
        display_name    = "GitHub Environment"
        description     = "GitHub environment that receives the credentials of this project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("development")
      }
      deploy_branch = {
        display_name    = "Deploy Branch"
        description     = "Branch whose workflow deploys into this project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("main")
      }
      additional_environment_variables = {
        display_name    = "Additional Environment Variables"
        description     = "Further GitHub Actions variables to set on the environment, as a map of name to value."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode({})
      }
    }

    outputs = {
      github_environment_name = {
        display_name    = "GitHub Environment"
        type            = "STRING"
        assignment_type = "NONE"
      }
    }
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
