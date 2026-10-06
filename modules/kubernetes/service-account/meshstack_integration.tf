variable "kubeconfig" {
  type        = string
  nullable    = false
  ephemeral   = true
  description = "Kubeconfig (YAML) of an identity allowed to create service accounts, secrets and role bindings on the cluster the building block definition this registers serves."
}

variable "kubeconfig_version" {
  type        = string
  nullable    = false
  default     = "1"
  description = "Version of `kubeconfig`. It is ephemeral, so no version can be derived from it: increase this to send it to meshStack again."
}

variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the cluster in the kubeconfig each building block returns."
}

variable "namespace" {
  type        = string
  default     = null
  description = "Namespace every service account is created in. Null creates each one in the namespace of the Kubernetes tenant it is ordered for."
}

variable "cluster_roles" {
  type        = list(string)
  nullable    = false
  default     = ["view", "edit", "admin"]
  description = "ClusterRoles a consumer may bind the service account to. The first one is preselected."

  validation {
    condition     = length(var.cluster_roles) > 0
    error_message = "cluster_roles must name at least one ClusterRole."
  }
}

variable "bind_cluster_wide" {
  type        = bool
  nullable    = false
  default     = false
  description = "Bind the role in every namespace through a ClusterRoleBinding, instead of in the service account's namespace only."
}

variable "supported_platforms" {
  type        = list(string)
  nullable    = false
  default     = ["KUBERNETES"]
  description = "Platform types whose tenants the building block can be ordered for. A definition with a fixed `namespace` is usually ordered for the tenant that hosts the cluster instead."
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
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "Kubernetes Service Account")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/service-account/buildingblock/logo.png"
    description         = coalesce(var.bbd_description, "Creates a Kubernetes service account bound to a ClusterRole and returns a kubeconfig for it.")
    support_url         = "https://kubernetes.io/docs/concepts/security/service-accounts/"
    target_type         = "TENANT_LEVEL"
    run_transparency    = true
    approval_policies   = var.approval_policies
    supported_platforms = [for name in var.supported_platforms : { name = name }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
      Creates a Kubernetes service account bound to a ClusterRole, and a kubeconfig that
      authenticates as it with a long-lived token.

      ## 🎯 When to use it

      Use this building block when you:
      - Deploy to your namespace from a CI/CD pipeline or an external tool such as Argo CD or Flux.
      - Need a machine identity for monitoring or automation instead of a personal login.

      ## 💡 Usage examples

      **Example 1: Deploy from a pipeline**
      A team orders a service account with the `edit` role and stores the kubeconfig as a pipeline
      secret, so every push deploys to their namespace.

      **Example 2: Read-only monitoring**
      A team orders a service account with the `view` role for a dashboard that watches the pods in
      their namespace.

      ## ⚠️ Treat the kubeconfig as a secret

      Anyone who has the kubeconfig acts with the service account's role until the service account
      is deleted. Store it in a secret store, never in version control.

      ## 📊 Shared Responsibility

      | Responsibility | Platform Team | Application Team |
      |---|:---:|:---:|
      | Provide the cluster and decide which ClusterRoles can be bound | ✅ | ❌ |
      | Create the service account, its token and its role binding | ✅ | ❌ |
      | Choose the least privileged role that works | ❌ | ✅ |
      | Store the kubeconfig securely and delete unused service accounts | ❌ | ✅ |
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
        repository_path                = "modules/kubernetes/service-account/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      "kubeconfig.yaml" = {
        display_name    = "kubeconfig.yaml"
        description     = "Kubeconfig of the cluster to create the service accounts in."
        type            = "FILE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = "data:application/yaml;base64,${base64encode(var.kubeconfig)}"
            secret_version = var.kubeconfig_version
          }
        }
      }

      name = {
        display_name                   = "Name"
        description                    = "Name of the service account."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "Name must be at most 63 lowercase letters, digits and dashes, and not start or end with a dash."
      }

      namespace = {
        display_name    = "Namespace"
        description     = "Namespace the service account is created in."
        type            = "STRING"
        assignment_type = var.namespace == null ? "PLATFORM_TENANT_ID" : "STATIC"
        argument        = var.namespace == null ? null : jsonencode(var.namespace)
      }

      cluster_role = {
        display_name      = "Cluster Role"
        description       = "ClusterRole the service account is bound to."
        type              = "SINGLE_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = var.cluster_roles
        default_value     = jsonencode(var.cluster_roles[0])
      }

      bind_cluster_wide = {
        display_name    = "Bind Cluster-Wide"
        description     = "Bind the role in every namespace, not only in the service account's own."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.bind_cluster_wide)
      }

      cluster_name = {
        display_name    = "Cluster Name"
        description     = "Name of the cluster in the returned kubeconfig."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.cluster_name)
      }

      context = {
        display_name    = "Context"
        description     = "Name of the context in the returned kubeconfig."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.cluster_name)
      }

      output_to_vault = {
        display_name           = "Output to Vault"
        description            = "HCL object `{address, mount, username, password, path}` of the Vault KV v2 secret the kubeconfig is written to, under the key `kubeconfig`. Leave empty to return it as an output instead."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        sensitive              = {}
        is_optional            = true
        updateable_by_consumer = true
      }
    }

    outputs = {
      vault_secret = {
        display_name    = "Vault Secret"
        description     = "JSON object `{path, secret_hash}` of the secret in Vault, or `{}` when `output_to_vault` is not set. `secret_hash` changes with the secret's content."
        type            = "CODE"
        assignment_type = "NONE"
      }

      kubeconfig = {
        display_name    = "Kubeconfig"
        type            = "STRING"
        assignment_type = "NONE"
      }

      instructions = {
        display_name    = "Instructions"
        type            = "STRING"
        assignment_type = "NONE"
      }
    }

    permissions = []
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
