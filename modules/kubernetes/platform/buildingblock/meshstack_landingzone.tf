resource "meshstack_landingzone" "this" {
  for_each = var.landing_zones

  metadata = {
    name               = "${var.platform_name}-${each.key}"
    owned_by_workspace = var.owning_workspace_identifier
    tags               = each.value.tags
  }

  spec = {
    display_name                  = each.value.display_name
    description                   = each.value.description
    automate_deletion_approval    = true
    automate_deletion_replication = true
    info_link                     = each.value.info_link

    platform_ref = {
      uuid = meshstack_platform.this.metadata.uuid
    }

    platform_properties = {
      kubernetes = {
        kubernetes_role_mappings = [
          {
            project_role_ref = { name = "admin" }
            platform_roles   = ["admin"]
          },
          {
            project_role_ref = { name = "user" }
            platform_roles   = ["edit"]
          },
          {
            project_role_ref = { name = "reader" }
            platform_roles   = ["view"]
          },
        ]
      }
    }

    quotas = each.value.quotas
  }
}
