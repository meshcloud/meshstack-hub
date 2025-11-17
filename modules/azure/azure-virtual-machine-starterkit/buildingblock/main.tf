locals {
  # Create a purely alphanumeric identifier from the display name
  # Remove special characters, convert to lowercase, and replace spaces/hyphens with nothing
  identifier = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))

  # Decode project tags YAML configuration
  project_tags_config = yamldecode(var.project_tags_yaml)
}

resource "meshstack_project" "vm_project" {
  metadata = {
    name               = local.identifier
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = var.name
    tags         = local.project_tags_config
  }
}

resource "meshstack_project_user_binding" "creator_admin" {
  count = var.creator.type == "User" && var.creator.username != null ? 1 : 0

  metadata = {
    name = uuid()
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace_identifier
    name               = meshstack_project.vm_project.metadata.name
  }

  subject = {
    name = var.creator.username
  }
}

resource "meshstack_tenant_v4" "vm_tenant" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.vm_project.metadata.name
  }

  spec = {
    platform_identifier     = var.full_platform_identifier
    landing_zone_identifier = var.landing_zone_identifier
  }
}

resource "meshstack_building_block_v2" "azure_vm" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.azure_vm_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.vm_tenant.metadata.uuid
    }
    display_name = "Azure Virtual Machine"
    inputs = {
      vm_name = {
        value_string = local.identifier
      }
      location = {
        value_string = var.vm_location
      }
      os_type = {
        value_string = var.vm_os_type
      }
      vm_size = {
        value_string = var.vm_size
      }
      admin_username = {
        value_string = var.vm_admin_username
      }
      enable_public_ip = {
        value_bool = var.vm_enable_public_ip
      }
      ssh_public_key = {
        value_string = var.vm_os_type == "Linux" ? var.vm_ssh_public_key : null
      }
      admin_password = {
        value_string = var.vm_os_type == "Windows" ? var.vm_admin_password : null
      }
    }
  }
}
