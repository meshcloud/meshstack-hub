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

resource "meshstack_building_block" "azure_vm" {
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
        value = jsonencode(local.identifier)
      }
      location = {
        value = jsonencode(var.vm_location)
      }
      vm_size = {
        value = jsonencode(var.vm_size)
      }
      admin_username = {
        value = jsonencode(var.vm_admin_username)
      }
      enable_public_ip = {
        value = jsonencode(var.vm_enable_public_ip)
      }
      ssh_public_key = {
        value = jsonencode(var.vm_ssh_public_key)
      }
    }
  }
}

# Migrate the child building block from the deprecated meshstack_building_block_v2
# resource to meshstack_building_block in place.
moved {
  from = meshstack_building_block_v2.azure_vm
  to   = meshstack_building_block.azure_vm
}
