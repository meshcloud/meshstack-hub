# This file is an example showing how to register the STACKIT connector
# building block in a meshStack instance.

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.0"
    }
  }
}

variable "cluster_host" {
  type        = string
  description = "The endpoint of the Kubernetes cluster."
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority (CA) certificate used to verify the Kubernetes API server's identity."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Base64-encoded client certificate used for authenticating to the Kubernetes API server."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Base64-encoded private key corresponding to the client certificate, used for authentication with the Kubernetes API server."
  type        = string
  sensitive   = true
}

variable "cluster_kubeconfig" {
  description = "Raw kubeconfig content containing the configuration required to access and authenticate to the Kubernetes cluster."
  type        = string
  sensitive   = true
}

variable "forgejo_host" {
  type = string
}

variable "forgejo_api_token" {
  type      = string
  sensitive = true
}

variable "harbor_host" {
  type        = string
  description = "The URL of the Harbor registry."
  default     = "https://registry.onstackit.cloud"
}

variable "harbor_username" {
  type        = string
  description = "The username for the Harbor registry."
  sensitive   = true
}

variable "harbor_password" {
  type        = string
  description = "The password for the Harbor registry."
  sensitive   = true
}

variable "forgejo_repo_definition_uuid" {
  type        = string
  description = "The Building Block definition UUID of the repository parent."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, false)
  })
  default     = {}
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br>
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition_version_ref" {
  value       = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  description = "Version of BBD is consumed in Building Block compositions, for example in the backplane of starter kits."
}

module "backplane" {
  source                 = "./backplane"
  cluster_host           = var.cluster_host
  cluster_ca_certificate = var.client_certificate
  client_key             = var.client_key
  client_certificate     = var.client_certificate
  cluster_kubeconfig     = var.cluster_kubeconfig
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name     = "STACKIT connector"
    symbol           = "data:image/png;base64,${filebase64("${path.module}/buildingblock/logo.png")}"
    description      = "Forgejo Actions Integration with STACKIT Kubernetes"
    support_url      = "https://portal.stackit.cloud/git"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/git-connector/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    dependency_refs = [{ uuid = "${var.forgejo_repo_definition_uuid}" }]

    inputs = {
      # ── Static inputs from backplane ──────────────────────────────────────
      config_tf = {
        display_name    = "config_k8s"
        description     = "Static config for kubernetes"
        type            = "FILE"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value = jsonencode(module.backplane.config_tf)
          }
        }
      }

      FORGEJO_HOST = {
        display_name    = "FORGEJO_HOST"
        description     = "The URL of the Forgejo instance to connect to."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value = jsonencode(var.forgejo_host)
          }
        }
      }

      FORGEJO_API_TOKEN = {
        display_name    = "FORGEJO_API_TOKEN"
        description     = "The API token for authenticating with the Forgejo instance."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value = jsonencode(var.forgejo_api_token)
          }
        }
      }

      harbor_host = {
        display_name    = "harbor_host"
        description     = "The URL of the Harbor registry."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.harbor_host)
      }

      harbor_username = {
        display_name    = "harbor_username"
        description     = "The username for the Harbor registry."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.harbor_username)
      }

      harbor_password = {
        display_name    = "harbor_password"
        description     = "The password for the Harbor registry."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = jsonencode(var.harbor_password)
          }
        }
      }

      forgejo_repository_name = {
        display_name    = "forgejo_repository_name"
        description     = "The name of the Forgejo repository."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = "${var.forgejo_repo_definition_uuid}.repo_name"
      }

      forgejo_repository_owner = {
        display_name    = "forgejo_repository_owner"
        description     = "The owner of the Forgejo repository."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = "${var.forgejo_repo_definition_uuid}.repo_owner"
      }

      # ── User inputs ────────────────────────────────────────────────────────

      namespace = {
        display_name    = "namespace"
        description     = "Associated namespace in kubernetes cluster."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }
    }

    outputs = {
    }
  }
}
