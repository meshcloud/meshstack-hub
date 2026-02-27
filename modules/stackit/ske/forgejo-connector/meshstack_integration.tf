# This file is an example showing how to register the Forgejo Actions connector
# building block in a meshStack instance. Adapt variables to your setup.

variable "hub" {
  type = object({
    git_ref = string
  })
  default = {
    git_ref = "main"
  }
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = "Shared meshStack context passed down from the IaC runtime."
}

variable "gitea" {
  type = object({
    base_url     = string
    token        = string
    organization = string
  })
  sensitive   = true
  description = "STACKIT Git (Forgejo) credentials and organization."
}

variable "ske" {
  type = object({
    cluster_server         = string
    cluster_ca_certificate = string
  })
  description = "SKE cluster connection details for kubeconfig generation."
}

variable "git_repo_bbd" {
  type = object({
    uuid = string
  })
  description = "Reference to the STACKIT Git Repository building block definition (dependency)."
}

variable "harbor" {
  type = object({
    url            = string
    robot_username = string
    robot_token    = string
  })
  sensitive   = true
  default     = null
  description = "Harbor registry credentials. When provided, stores push credentials as Forgejo Actions secrets and creates an image pull secret in the namespace."
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
  }
}

resource "meshstack_building_block_definition" "forgejo_connector" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description         = "CI/CD pipeline using Forgejo Actions for deploying to STACKIT Kubernetes Engine (SKE)."
    display_name        = "Forgejo Actions Integration with SKE"
    symbol              = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "STACKIT_KUBERNETES_ENGINE" }]
    run_transparency    = true
    readme              = file("${path.module}/buildingblock/README.md")
  }

  version_spec = {
    draft = true
    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.9.0"
        async                          = false
        ref_name                       = var.hub.git_ref
        repository_path                = "modules/stackit/ske/forgejo-connector/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }
    dependency_refs = [
      { uuid = var.git_repo_bbd.uuid }
    ]
    inputs = merge({
      "gitea_base_url" = {
        display_name    = "STACKIT Git Base URL"
        description     = "Base URL of the STACKIT Git (Forgejo) instance."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.gitea.base_url)
      }
      "gitea_token" = {
        display_name    = "STACKIT Git API Token"
        description     = "API token for managing Forgejo repository secrets."
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = var.gitea.token
          }
        }
      }
      "gitea_organization" = {
        display_name    = "STACKIT Git Organization"
        description     = "Organization that owns the repository."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.gitea.organization)
      }
      "repository_name" = {
        display_name    = "Repository Name"
        description     = "Name of the Forgejo repository (wired from Git Repository BBD output)."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.git_repo_bbd.uuid}.repository_name")
      }
      "namespace" = {
        display_name    = "SKE Namespace"
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }
      "cluster_server" = {
        display_name    = "SKE Cluster Server"
        description     = "API server URL of the SKE cluster."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.ske.cluster_server)
      }
      "cluster_ca_certificate" = {
        display_name    = "SKE Cluster CA Certificate"
        description     = "Base64-encoded CA certificate of the SKE cluster."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.ske.cluster_ca_certificate)
      }
    }, var.harbor != null ? {
      "harbor" = {
        display_name    = "Harbor Registry Credentials"
        description     = "Harbor registry URL and robot account credentials for container image push/pull."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = jsonencode({
              url            = var.harbor.url
              robot_username = var.harbor.robot_username
              robot_token    = var.harbor.robot_token
            })
          }
        }
      }
    } : {})
    outputs = {
      "summary" = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

output "bbd_uuid" {
  description = "UUID of the Forgejo Actions connector building block definition."
  value       = meshstack_building_block_definition.forgejo_connector.ref.uuid
}

output "bbd_version_uuid" {
  description = "UUID of the latest version of the Forgejo Actions connector building block definition."
  value       = meshstack_building_block_definition.forgejo_connector.version_latest.uuid
}
