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

variable "github" {
  type = object({
    org                        = string
    app_id                     = string
    app_installation_id        = string
    app_pem_file               = string
    connector_config_tf_base64 = string
  })
  sensitive   = true
  description = "GitHub App credentials and connector configuration for AKS integration."
}

variable "github_repo_bbd" {
  type = object({
    uuid = string
  })
  description = "Reference to the GitHub Repository building block definition (dependency)."
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
  }
}

locals {
  config_tf_secret_value = "data:application/octet-stream;base64,${var.github.connector_config_tf_base64}"

  github_auth_inputs = {
    "GITHUB_OWNER" = {
      argument               = jsonencode(var.github.org)
      assignment_type        = "STATIC"
      description            = "GitHub organization or user that owns the repositories managed by this building block."
      display_name           = "GitHub Owner"
      is_environment         = true
      type                   = "STRING"
      updateable_by_consumer = false
    }
    "GITHUB_APP_ID" = {
      argument               = jsonencode(var.github.app_id)
      assignment_type        = "STATIC"
      description            = "GitHub App ID used to authenticate the GitHub Terraform provider."
      display_name           = "GitHub App ID"
      is_environment         = true
      type                   = "STRING"
      updateable_by_consumer = false
    }
    "GITHUB_APP_INSTALLATION_ID" = {
      argument               = jsonencode(var.github.app_installation_id)
      assignment_type        = "STATIC"
      description            = "GitHub App Installation ID used to authenticate the GitHub Terraform provider."
      display_name           = "GitHub App Installation ID"
      is_environment         = true
      type                   = "STRING"
      updateable_by_consumer = false
    }
    "GITHUB_APP_PEM_FILE" = {
      assignment_type        = "STATIC"
      description            = "GitHub App PEM private key used to authenticate the GitHub Terraform provider."
      display_name           = "GitHub App PEM File"
      is_environment         = true
      type                   = "CODE"
      updateable_by_consumer = false
      sensitive = {
        argument = {
          secret_value   = var.github.app_pem_file
          secret_version = sha256(var.github.app_pem_file)
        }
      }
    }
  }
}

resource "meshstack_building_block_definition" "github_actions_connector" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description         = "CI/CD pipeline using GitHub Actions for secure, scalable AKS deployment."
    display_name        = "GitHub Actions Integration with AKS"
    symbol              = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "AZURE_KUBERNETES_SERVICE" }]
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
        repository_path                = "modules/aks/github-connector/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }
    dependency_refs = [
      { uuid = var.github_repo_bbd.uuid }
    ]
    inputs = merge(local.github_auth_inputs, {
      "github_repo" = {
        argument               = jsonencode("${var.github_repo_bbd.uuid}.repo_name")
        assignment_type        = "BUILDING_BLOCK_OUTPUT"
        description            = "Full name (owner/repo) of the GitHub repository to connect."
        display_name           = "GitHub Repository"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "namespace" = {
        assignment_type = "PLATFORM_TENANT_ID"
        display_name    = "AKS Namespace"
        is_environment  = false
        type            = "STRING"
      }
      "github_environment_name" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the GitHub environment to use for deployments."
        display_name           = "GitHub Environment Name"
        default_value          = jsonencode("production")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "additional_environment_variables" = {
        assignment_type        = "USER_INPUT"
        description            = "Map of additional environment variable key/value pairs to set as GitHub Actions environment variables."
        display_name           = "Additional Environment Variables"
        default_value          = jsonencode({})
        is_environment         = false
        type                   = "CODE"
        updateable_by_consumer = false
      }
      "config.tf" = {
        assignment_type        = "STATIC"
        description            = "Content of the config.tf file provided to the building block run."
        display_name           = "config.tf"
        is_environment         = false
        type                   = "FILE"
        updateable_by_consumer = false
        sensitive = {
          argument = {
            secret_value   = local.config_tf_secret_value
            secret_version = sha256(local.config_tf_secret_value)
          }
        }
      }
    })
    outputs = {}
  }
}

output "bbd_uuid" {
  description = "UUID of the GitHub Actions Connector building block definition."
  value       = meshstack_building_block_definition.github_actions_connector.ref.uuid
}

output "bbd_version_uuid" {
  description = "UUID of the latest version of the GitHub Actions Connector building block definition."
  value       = meshstack_building_block_definition.github_actions_connector.version_latest.uuid
}
