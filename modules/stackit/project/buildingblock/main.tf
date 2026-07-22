# TODO: migrate to the meshstack_tenant_v4 data source once meshStack supports a tenant UUID
# as a building block input (currently under development). That will let us look up the
# tenant from a single identifier instead of the three separate identity inputs below
# (project_name/workspace_identifier/platform_identifier).
data "meshstack_tenant" "this" {
  lifecycle {
    enabled = var.network_area_tag_name != null
  }

  metadata = {
    owned_by_project    = var.project_name
    owned_by_workspace  = var.workspace_identifier
    platform_identifier = var.platform_identifier
  }
}

data "meshstack_landingzone" "this" {
  lifecycle {
    enabled = var.network_area_tag_name != null
  }

  metadata = {
    name = data.meshstack_tenant.this.spec.landing_zone_ref.name
  }
}

locals {
  # Determine the parent container ID based on environment
  selected_parent_container_id = var.environment != null ? lookup(var.parent_container_ids, var.environment, var.parent_container_id) : var.parent_container_id

  network_area_id = var.network_area_tag_name != null ? data.meshstack_landingzone.this.metadata.tags[var.network_area_tag_name][0] : null
  project_labels  = merge(var.labels, local.network_area_id != null ? { networkArea = local.network_area_id } : {})

  users_with_stackit_roles = [
    for user in var.users : {
      email = user.email
      roles = distinct(flatten([
        for meshstack_role in user.roles : lookup(var.role_mapping, meshstack_role, [])
      ]))
    }
  ]

  user_role_assignments = {
    for assignment in flatten([
      for user in local.users_with_stackit_roles : [
        for stackit_role in user.roles : {
          key          = "${user.email}:${stackit_role}"
          subject      = user.email
          stackit_role = stackit_role
        }
      ]
    ]) : assignment.key => assignment
  }
}

resource "stackit_resourcemanager_project" "project" {
  parent_container_id = local.selected_parent_container_id
  name                = var.project_name
  owner_email         = var.service_account_email

  # Only set labels if there are actually labels to set
  labels = length(local.project_labels) > 0 ? local.project_labels : null
}

# User role assignments (experimental IAM feature)
resource "stackit_authorization_project_role_assignment" "role_assignments" {
  for_each = local.user_role_assignments

  resource_id = stackit_resourcemanager_project.project.project_id
  role        = each.value.stackit_role
  subject     = each.value.subject
}

