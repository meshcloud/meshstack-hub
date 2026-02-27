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

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
  }
}

resource "meshstack_building_block_definition" "azure_postgresql" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description      = "Provides an Azure Database for PostgreSQL instance, offering a fully managed, scalable, and secure relational database service."
    display_name     = "Azure PostgreSQL Deployment"
    symbol           = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")
    run_transparency = true
    readme           = file("${path.module}/bb_description.md")
  }

  version_spec = {
    draft = true
    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.9.0"
        async                          = false
        ref_name                       = var.hub.git_ref
        repository_path                = "modules/azure/postgresql/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }
    inputs = {
      "subscription_id" = {
        assignment_type        = "PLATFORM_TENANT_ID"
        display_name           = "Subscription ID"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "resource_group_name" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the Azure resource group"
        display_name           = "Resource Group Name"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "postgresql_server_name" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the PostgreSQL server"
        display_name           = "PostgreSQL Server Name"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "location" = {
        assignment_type        = "USER_INPUT"
        description            = "Azure region for the PostgreSQL server"
        display_name           = "Location"
        default_value          = jsonencode("West Europe")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "administrator_login" = {
        assignment_type        = "USER_INPUT"
        description            = "Administrator username for PostgreSQL"
        display_name           = "Administrator Login"
        default_value          = jsonencode("psqladmin")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "sku_name" = {
        assignment_type        = "USER_INPUT"
        description            = "The SKU name for the PostgreSQL server"
        display_name           = "SKU Name"
        default_value          = jsonencode("B_Gen5_1")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "postgresql_version" = {
        assignment_type        = "USER_INPUT"
        description            = "PostgreSQL version"
        display_name           = "PostgreSQL Version"
        default_value          = jsonencode("11")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
    }
    outputs = {
      "fqdn" = {
        assignment_type = "NONE"
        display_name    = "Server FQDN"
        type            = "STRING"
      }
      "server_name" = {
        assignment_type = "NONE"
        display_name    = "Server Name"
        type            = "STRING"
      }
      "admin_username" = {
        assignment_type = "NONE"
        display_name    = "Admin Username"
        type            = "STRING"
      }
      "admin_password" = {
        assignment_type = "NONE"
        display_name    = "Admin Password"
        type            = "STRING"
      }
      "resource_group_name" = {
        assignment_type = "NONE"
        display_name    = "Resource Group Name"
        type            = "STRING"
      }
    }
  }
}

output "bbd_uuid" {
  description = "UUID of the Azure PostgreSQL building block definition."
  value       = meshstack_building_block_definition.azure_postgresql.ref.uuid
}

output "bbd_version_uuid" {
  description = "UUID of the latest version of the Azure PostgreSQL building block definition."
  value       = meshstack_building_block_definition.azure_postgresql.version_latest.uuid
}
