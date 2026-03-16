# This file registers the SKE Forgejo connector building block definition.

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.20.0"
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

variable "forgejo_repo_definition_uuid" {
  type        = string
  description = "UUID of the Forgejo repository building block definition used as parent dependency."
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
  description = "Version of BBD is consumed in building block compositions."
}

module "backplane" {
  source                 = "./backplane"
  cluster_host           = var.cluster_host
  cluster_ca_certificate = var.cluster_ca_certificate
  client_key             = var.client_key
  client_certificate     = var.client_certificate
  cluster_kubeconfig     = var.cluster_kubeconfig
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name        = "SKE Forgejo Connector"
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/forgejo-connector/buildingblock/logo.png"
    description         = "Connects a Forgejo repository with a tenant namespace on STACKIT SKE."
    support_url         = "https://portal.stackit.cloud/git"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "STACKIT_KUBERNETES_ENGINE" }]
    run_transparency    = true
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/ske/forgejo-connector/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    dependency_refs = [{ uuid = var.forgejo_repo_definition_uuid }]

    inputs = {
      "config.tf" = {
        display_name    = "config.tf"
        description     = "Static Kubernetes provider config and kubeconfig stub."
        type            = "FILE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = module.backplane.config_tf
            secret_version = sha256(module.backplane.config_tf)
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
            secret_value   = jsonencode(var.forgejo_host)
            secret_version = sha256(jsonencode(var.forgejo_host))
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
            secret_value   = jsonencode(var.forgejo_api_token)
            secret_version = sha256(jsonencode(var.forgejo_api_token))
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
        sensitive = {
          argument = {
            secret_value   = jsonencode(var.harbor_username)
            secret_version = sha256(jsonencode(var.harbor_username))
          }
        }
      }

      harbor_password = {
        display_name    = "harbor_password"
        description     = "The password for the Harbor registry."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = jsonencode(var.harbor_password)
            secret_version = sha256(jsonencode(var.harbor_password))
          }
        }
      }

      repository_id = {
        display_name    = "repository_id"
        description     = "ID of the parent Forgejo repository where action secrets are created."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = "${var.forgejo_repo_definition_uuid}.repository_id"
      }

      namespace = {
        display_name    = "namespace"
        description     = "Associated namespace in kubernetes cluster."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      stage = {
        display_name                   = "stage"
        description                    = "Deployment stage used for secret suffixing (`dev` or `prod`)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^(dev|prod)$"
        validation_regex_error_message = "Stage must be either 'dev' or 'prod'."
      }

      additional_environment_variables = {
        display_name    = "additional_environment_variables"
        description     = "Map of additional key/value pairs to create as repository action secrets."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode({})
      }
    }

    outputs = {}

    permissions = ["TENANT_LIST", "TENANT_SAVE", "TENANT_DELETE"]
  }
}
