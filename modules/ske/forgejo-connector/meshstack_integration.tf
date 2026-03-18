variable "kubeconfig" {
  description = "Kubeconfig content containing the configuration required to access and authenticate to the Kubernetes cluster."
  type        = any
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
  description = "UUID of the Forgejo repository building block definition used as parent dependency for tenant building blocks (connector)."
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

variable "additional_kubernetes_secrets" {
  type        = map(map(string))
  description = "Additional Kubernetes secrets provisioned in tenant namespaces by the connector."
  sensitive   = true
  default = {
    "stackit-ai" = {
      STACKIT_AI_BASE_URL = "https://example.invalid/v1"
      STACKIT_AI_API_KEY  = "dummy-api-key"
      STACKIT_AI_MODEL    = "dummy-model"
    }
  }
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

output "building_block_definition" {
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
  description = "BBD is consumed in building block compositions."
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
    supported_platforms = [{ name = "KUBERNETES" }]
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
      namespace = {
        display_name    = "K8S Namespace"
        description     = "Provided namespace in Kubernetes cluster."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      "kubeconfig.yaml" = {
        display_name    = "kubeconfig.yaml"
        description     = "kubeconfig.yaml file providing admin credentials to cluster."
        type            = "FILE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = "data:application/yaml;base64,${base64encode(yamlencode(var.kubeconfig))}" # data type application/yaml is ignored anyway
            secret_version = nonsensitive(sha256(yamlencode(var.kubeconfig)))
          }
        }
      }

      repository_id = {
        display_name    = "repository_id"
        description     = "ID of the parent Forgejo repository where action secrets are created."
        type            = "INTEGER"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.forgejo_repo_definition_uuid}.repository_id")
      }

      stage = {
        display_name    = "stage"
        description     = "Deployment stage for this connector instance (dev or prod)."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("dev")
      }

      additional_kubernetes_secrets = {
        display_name    = "additional_kubernetes_secrets"
        description     = "Static sensitive map of additional Kubernetes Opaque secrets to create in the tenant namespace."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = jsonencode(var.additional_kubernetes_secrets)
            secret_version = nonsensitive(sha256(jsonencode(var.additional_kubernetes_secrets)))
          }
        }
      }

      FORGEJO_HOST = {
        display_name    = "FORGEJO_HOST"
        description     = "The Host of the Forgejo instance to connect to."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.forgejo_host)
      }

      FORGEJO_API_TOKEN = {
        display_name    = "FORGEJO_API_TOKEN"
        description     = "The API token for authenticating with the Forgejo instance."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        sensitive = {
          argument = {
            secret_value   = var.forgejo_api_token
            secret_version = nonsensitive(sha256(var.forgejo_api_token))
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
            secret_value   = var.harbor_username
            secret_version = nonsensitive(sha256(var.harbor_username))
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
            secret_value   = var.harbor_password
            secret_version = nonsensitive(sha256(var.harbor_password))
          }
        }
      }
    }
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
