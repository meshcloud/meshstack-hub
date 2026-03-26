variable "kubernetes_kubeconfig" {
  description = "Admin kubeconfig object for the target cluster. Used to provision the backplane service account; the BBD receives a scoped kubeconfig."
  type        = any
  sensitive   = true
}

variable "kubernetes_namespace" {
  description = "Namespace in which the backplane service account is created (e.g. a dedicated platform namespace)."
  type        = string
  default     = "kube-system"
}

variable "kubernetes_service_account_name" {
  description = "Name of the service account created by the backplane for building block deployments."
  type        = string
  default     = "meshstack-manifest-bb"
}

variable "helm_release_name" {
  description = "Helm release name used for every deployed instance of this building block (example: `my-app`)."
  type        = string
}

variable "helm_template_files" {
  description = <<-EOT
    Map of Helm chart template files to inject as static FILE inputs into the building block definition.
    Keys are the template file names (e.g. `deployment.yaml`); values are the file contents.
    Each file will be placed under `templates/<key>` inside the building block's Helm chart directory.
  EOT
  type        = map(string)
  default     = {}
}

variable "helm_default_values_yaml" {
  description = <<-EOT
    Default Helm values provided to application teams as a required USER_INPUT CODE field.
    Set this to a sensible starting-point values object; tenants can override it when creating the building block.
    Example: `{ replicaCount = 1, image = { repository = "nginx", tag = "latest" } }`
  EOT
  type        = any
  default     = {}
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
  default     = {}
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
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/manifest/backplane?ref=50756692c3b74dde5a2ec0b080e43108e0d0c9d9"

  kubeconfig_admin     = var.kubernetes_kubeconfig
  namespace            = var.kubernetes_namespace
  service_account_name = var.kubernetes_service_account_name
}

locals {
  cluster_display_names = nonsensitive([for cluster in(var.kubernetes_kubeconfig["clusters"]) : cluster["name"]])
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "K8s Manifest for ${join(", ", local.cluster_display_names)}"
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/manifest/buildingblock/logo.svg"
    description  = "Deploys arbitrary Kubernetes manifests into a tenant namespace via a local Helm chart, with operator-supplied templates and user-provided values."
    target_type  = "TENANT_LEVEL"
    # TODO Correct would be to depend on the specific SKE cluster deployed (not just platform type),
    # as the kubeconfig.yaml input only works for one specific cluster (representing the meshPlatform here)
    supported_platforms = [{ name = "KUBERNETES" }]
    run_transparency    = true

    readme = chomp(<<-EOT
    Deploy arbitrary Kubernetes resources into your tenant namespace using a Helm chart assembled from operator-supplied template files and your own `values.yaml`.

    ## 🚀 When to use it

    This building block is for application teams that need to deploy custom Kubernetes workloads (Deployments, Services, Ingresses, ConfigMaps, …) into their namespace without maintaining a full Helm chart themselves. The platform team provides the chart templates; the application team supplies a `values.yaml` to customise behaviour.

    ## 🤝 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|---|---|
    | Provision and manage Kubernetes cluster | ✅ | ❌ |
    | Provide Helm chart templates (`templates/`) | ✅ | ❌ |
    | Configure `release_name` and `kubeconfig` | ✅ | ❌ |
    | Supply `values.yaml` to customise the deployment | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.11.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/kubernetes/manifest/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = merge({
      namespace = {
        display_name    = "Namespace"
        description     = "Kubernetes namespace to deploy the Helm release into."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      release_name = {
        display_name    = "Release"
        description     = "Name of the Helm release."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.helm_release_name)
      }

      "kubeconfig.yaml" = {
        display_name    = "kubeconfig.yaml"
        description     = "kubeconfig.yaml file providing scoped service account credentials to the Kubernetes cluster."
        type            = "FILE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = "data:application/yaml;base64,${base64encode(module.backplane.kubeconfig)}"
            secret_version = nonsensitive(sha256(module.backplane.kubeconfig))
          }
        }
      }

      values_yaml = {
        display_name           = "values.yaml"
        description            = "Helm values to customise the deployment. Edit the YAML/JSON to override chart defaults."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(yamlencode(var.helm_default_values_yaml))
      }
      },
      { for filename, content in var.helm_template_files : "templates/${filename}" => {
        display_name    = "templates/${filename}"
        description     = "Helm chart template file: templates/${filename}"
        type            = "FILE"
        assignment_type = "STATIC"
        argument        = jsonencode("data:text/plain;base64,${base64encode(content)}")
      } }
    )

    outputs = {
      release_name = {
        display_name    = "Release Name"
        description     = "Name of the deployed Helm release."
        type            = "STRING"
        assignment_type = "NONE"
      }
      release_status = {
        display_name    = "Release Status"
        description     = "Status of the Helm release."
        type            = "STRING"
        assignment_type = "NONE"
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
