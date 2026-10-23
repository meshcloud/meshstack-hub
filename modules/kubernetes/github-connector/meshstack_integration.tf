variable "kubernetes_api_server_url" {
  type        = string
  description = "URL of the Kubernetes API server (example: `https://api.k8s.example.com:6443`)."
}

variable "kubernetes_api_server_ca_certificate" {
  type        = string
  default     = null
  description = "PEM CA bundle used by the API server. Only set if it uses a certificate from another CA than the cluster's own."
}

variable "github_actions_cluster_role" {
  type        = string
  default     = "edit"
  description = "Cluster role GitHub Actions gets in the namespace."
}

variable "github_org" {
  type        = string
  description = "GitHub organization the connector's GitHub App is installed in and the repositories live in."
}

variable "github_app_id" {
  type        = string
  description = "ID of the GitHub App the building block authenticates as."
}

variable "github_app_installation_id" {
  type        = string
  description = "Installation ID of the connector's GitHub App in `github_org`."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "PEM private key of the connector's GitHub App."
}

variable "github_repo_definition_uuid" {
  type        = string
  description = "UUID of the `github/repository` building block definition which supplies the repositories this connector connects to."
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown in the marketplace."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace."
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
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/github-connector/backplane?ref=${var.hub.git_ref}"

  api_server_url              = var.kubernetes_api_server_url
  api_server_ca_certificate   = var.kubernetes_api_server_ca_certificate
  github_actions_cluster_role = var.github_actions_cluster_role
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name             = coalesce(var.bbd_display_name, "GitHub Actions Kubernetes Connector")
    description              = coalesce(var.bbd_description, "Connects a GitHub repository to a Kubernetes namespace, so GitHub Actions deploys into the namespace.")
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/github-connector/buildingblock/logo.png"
    notification_subscribers = var.notification_subscribers
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "KUBERNETES" }]
    run_transparency         = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **GitHub Actions Kubernetes Connector** connects a GitHub repository to your Kubernetes namespace. GitHub Actions can then deploy into the namespace — without anyone handling cluster credentials by hand.

    ## 🎯 When to use it

    Use this building block when you:
    - Keep your application in GitHub and want every push to deploy to Kubernetes.
    - Want one GitHub environment per stage, each allowed to deploy into its own namespace only.
    - Deploy several repositories, such as frontend and backend, into one shared namespace.

    ## 💡 Usage examples

    **Example 1: Deploy on every push**
    A developer pushes to `main`. The workflow in the `development` environment applies the manifests with `kubectl` and rolls out the new version in the dev namespace.

    **Example 2: Gate production behind a release branch**
    The team connects the prod namespace to the `production` environment, and restricts that environment in GitHub to the `release` branch with a required reviewer.

    ## 📦 What you get

    - A `github-actions-<repo>-<hash>` service account in the namespace with the `${var.github_actions_cluster_role}` cluster role. Connect several repositories to the same namespace by ordering one connector each.
    - A new GitHub environment with the secret `KUBECONFIG` and the variable `K8S_NAMESPACE`.

    ⚠️ The connector creates the GitHub environment and deletes it again with the building block. Choose an environment that does not exist yet, otherwise the building block fails with a conflict.

    The connector provides no image registry. Your deployments reference images the cluster can already pull.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the Kubernetes cluster | ✅ | ❌ |
    | Provide the GitHub App and the deployment credentials | ✅ | ❌ |
    | Restrict the pipeline's access to its own namespace | ✅ | ❌ |
    | Build and publish container images | ❌ | ✅ |
    | Write the workflow and manifests | ❌ | ✅ |
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
        repository_path                = "modules/kubernetes/github-connector/buildingblock"
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
        display_name    = "GitHub App Private Key"
        type            = "CODE"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.github_app_private_key
            secret_version = nonsensitive(sha256(var.github_app_private_key))
          }
        }
      }
      namespace = {
        display_name    = "Kubernetes Namespace"
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
      cluster_role = {
        display_name    = "Kubernetes Cluster Role"
        description     = "Cluster role GitHub Actions gets in the namespace."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.github_actions_cluster_role)
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
        description     = "GitHub environment that receives the credentials of this namespace. The connector creates it, so it must not exist yet."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("development")
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
