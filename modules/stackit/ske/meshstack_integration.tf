# Adapt these variables to your STACKIT and meshStack setup.

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

variable "ske" {
  type = object({
    platform_identifier = string
    location_identifier = string

    # Cluster connection
    base_url               = string
    disable_ssl_validation = optional(bool, true)

    # Replication
    namespace_name_pattern = optional(string, "#{workspaceIdentifier}-#{projectIdentifier}")
  })
  description = "STACKIT Kubernetes Engine platform configuration."
}

module "backplane" {
  source = "./backplane"

  stackit_project_id = var.stackit_project_id
  cluster_name       = var.cluster_name
  region             = var.region
}

variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the SKE cluster will be created."
}

variable "cluster_name" {
  type        = string
  description = "Name of the SKE cluster."
  default     = "ske-cluster"
}

variable "region" {
  type        = string
  description = "STACKIT region for the SKE cluster."
  default     = "eu01"
}

resource "meshstack_platform" "ske" {
  metadata = {
    name               = var.ske.platform_identifier
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "STACKIT Kubernetes Engine (SKE). Create a k8s namespace in our SKE cluster."
    display_name = "SKE Namespace"
    endpoint     = var.ske.base_url

    location_ref = {
      name = var.ske.location_identifier
    }

    availability = {
      restriction       = "PUBLIC"
      publication_state = "PUBLISHED"
    }

    config = {
      kubernetes = {
        base_url               = var.ske.base_url
        disable_ssl_validation = var.ske.disable_ssl_validation

        replication = {
          client_config = {
            access_token = {
              secret_value   = module.backplane.replicator_token
              secret_version = sha256(module.backplane.replicator_token)
            }
          }
          namespace_name_pattern = var.ske.namespace_name_pattern
        }

        metering = {
          client_config = {
            access_token = {
              secret_value   = module.backplane.metering_token
              secret_version = sha256(module.backplane.metering_token)
            }
          }
          processing = {}
        }
      }
    }
  }
}

resource "meshstack_landingzone" "ske_default" {
  metadata = {
    name               = "${var.ske.platform_identifier}-default"
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "Default SKE landing zone"
    display_name = "SKE Default"

    platform_ref = meshstack_platform.ske.metadata

    automate_deletion_approval    = true
    automate_deletion_replication = true

    platform_properties = {
      kubernetes = {
        kubernetes_role_mappings = [
          {
            platform_roles = ["admin"]
            project_role_ref = {
              name = "admin"
            }
          },
          {
            platform_roles = ["edit"]
            project_role_ref = {
              name = "user"
            }
          },
          {
            platform_roles = ["view"]
            project_role_ref = {
              name = "reader"
            }
          }
        ]
      }
    }
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.1"
    }
  }
}
