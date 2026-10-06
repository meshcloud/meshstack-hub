variable "kubeconfig" {
  type        = string
  nullable    = false
  ephemeral   = true
  description = "Kubeconfig (YAML) of a cluster-admin service account on the cluster the tenant namespaces live on."
}

variable "kubeconfig_version" {
  type        = string
  nullable    = false
  default     = "1"
  description = "Version of `kubeconfig`. It is ephemeral, so no version can be derived from it: increase this to send it to meshStack again."
}

variable "forgejo_host" {
  type = string
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

variable "vault_reader" {
  type = object({
    address  = string
    mount    = string
    username = string
    password = string
  })
  nullable    = false
  sensitive   = true
  description = "Vault KV v2 login the building blocks read their secrets with: the server `address`, the engine `mount` and a userpass `username` and `password`."
}

variable "forgejo_api_token_path" {
  type        = string
  nullable    = false
  description = "Vault KV v2 secret holding the Forgejo API token under the key `forgejo_api_token`."
}

variable "registry_pull_path" {
  type        = string
  nullable    = false
  description = "Vault KV v2 secret holding the registry pull robot under the keys `username` and `password`."
}

variable "additional_kubernetes_secrets" {
  type        = map(string)
  nullable    = false
  default     = {}
  description = "Opaque Kubernetes secrets the connector creates in each tenant namespace, by name, each from the Vault KV v2 secret at the given path. Every key of that secret becomes a key of the Kubernetes secret."
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

variable "approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable    = false
  default     = {}
  description = "Run triggers that need an operator's approval before a run of this definition is applied. A gate switched on in meshPanel is reset on the next apply unless it is set here."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
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
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = coalesce(var.bbd_display_name, "SKE Forgejo Connector")
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/ske/forgejo-connector/buildingblock/logo.png"
    description = coalesce(var.bbd_description, chomp(<<-EOT
      Connects a Forgejo repository with a Kubernetes namespace on STACKIT SKE
      for CI/CD via Forgejo Actions.
    EOT
    ))
    support_url         = "https://portal.stackit.cloud/git"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "KUBERNETES" }]
    run_transparency    = true
    approval_policies   = var.approval_policies

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **SKE Forgejo Connector** wires a Forgejo repository to a Kubernetes namespace on STACKIT SKE so that
    Forgejo Actions workflows can build and deploy applications into the namespace.

    ## 📦 Resources Created

    - **Kubernetes service account & RBAC** – scoped credentials for the Forgejo Actions runner, including
      cluster-issuer read access for cert-manager.
    - **Additional secrets** – Opaque secrets the platform fills from its Secrets Manager, for example
      the AI model serving credentials.
    - **Forgejo Actions secrets** – a per-stage `KUBECONFIG_<STAGE>` secret containing a kubeconfig scoped to
      the tenant namespace.
    - **Forgejo Actions variables** – per-stage `K8S_NAMESPACE_<STAGE>` and `APP_HOSTNAME_<STAGE>`.
    - **Harbor image-pull secret** – a `kubernetes.io/dockerconfigjson` secret attached to the default service
      account so pods can pull images from STACKIT Harbor.
    - **Pipeline trigger** – after provisioning, the connector automatically triggers the Forgejo Actions
      pipeline workflow and waits for it to complete.

    ## Shared Responsibilities

    | Responsibility                                       | Platform Team | Application Team |
    | ---------------------------------------------------- | ------------- | ---------------- |
    | Provision and manage SKE cluster                     | ✅            | ❌                |
    | Create connector (namespace ↔ repository wiring)     | ✅            | ❌                |
    | Manage K8s resources inside namespace                | ❌             | ✅               |
    | Maintain Forgejo Actions pipeline (pipeline.yaml)    | ❌             | ✅               |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
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
        description     = "Kubeconfig of a cluster-admin service account on the cluster."
        type            = "FILE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = "data:application/yaml;base64,${base64encode(var.kubeconfig)}"
            secret_version = var.kubeconfig_version
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

      app_hostname = {
        display_name    = "app_hostname"
        description     = "Public application hostname for this stage."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      additional_kubernetes_secrets = {
        display_name    = "additional_kubernetes_secrets"
        description     = "Map from the name of an Opaque Kubernetes secret created in the tenant namespace to the Vault KV v2 secret it is filled from."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.additional_kubernetes_secrets))
      }

      FORGEJO_HOST = {
        display_name    = "FORGEJO_HOST"
        description     = "The Host of the Forgejo instance to connect to."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(var.forgejo_host)
      }

      vault_reader = {
        display_name    = "Vault Reader"
        description     = "HCL object `{address, mount, username, password}` of the Vault KV v2 login the run reads its secrets with."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = jsonencode(var.vault_reader)
            secret_version = nonsensitive(sha256(jsonencode(var.vault_reader)))
          }
        }
      }

      forgejo_api_token_path = {
        display_name    = "Forgejo API Token Path"
        description     = "Vault KV v2 secret holding the Forgejo API token under the key `forgejo_api_token`."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.forgejo_api_token_path)
      }

      registry_pull_path = {
        display_name    = "Registry Pull Robot Path"
        description     = "Vault KV v2 secret holding the registry pull robot under the keys `username` and `password`."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.registry_pull_path)
      }

      harbor_host = {
        display_name    = "harbor_host"
        description     = "The URL of the Harbor registry."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.harbor_host)
      }

      hub_git_ref = {
        display_name    = "hub_git_ref"
        description     = "Hub git ref this building block runs from."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.hub.git_ref)
      }
    }

    outputs = {
      "app_link" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Open App"
        type            = "STRING"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source = "meshcloud/meshstack"
      # 0.25.2 is the first release that accepts `spec.approval_policies`.
      version = ">= 0.25.2"
    }
  }
}
