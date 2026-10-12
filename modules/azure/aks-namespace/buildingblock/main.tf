locals {
  namespace_roles = toset(["admin", "edit", "view"])

  unique_user_euids = toset([for user in var.users : user.euid])

  user_group_assignments = {
    for pair in flatten([
      for user in var.users : [
        for role in user.roles : {
          key  = "${user.euid}-${var.role_mapping[role]}"
          euid = user.euid
          role = var.role_mapping[role]
        }
        if contains(keys(var.role_mapping), role)
      ]
    ]) : pair.key => pair
  }
}

# One bulk lookup with ignore_missing, rather than a data source per member: a workspace member
# with no object in the directory (external collaborator, service account, a guest that was never
# invited) must not fail the whole run. Unresolved members are reported through the
# unresolved_users output instead.
data "azuread_users" "members" {
  lifecycle {
    enabled = length(local.unique_user_euids) > 0
  }

  ignore_missing = true

  mails                = var.user_lookup_attribute == "email" ? sort(tolist(local.unique_user_euids)) : null
  user_principal_names = var.user_lookup_attribute == "upn" ? sort(tolist(local.unique_user_euids)) : null
}

locals {
  # Directory lookups are case-insensitive, so match on a lowercased key to avoid treating a member
  # whose meshStack euid differs only in case from the directory value as unresolved.
  #
  # `try` because the lookup is disabled when there is no member to resolve, and reading an
  # attribute of a disabled data source is an error rather than an empty list.
  lookup_values = {
    for u in try(data.azuread_users.members.users, []) :
    lower(coalesce(var.user_lookup_attribute == "email" ? u.mail : u.user_principal_name, "")) => u.object_id
    if coalesce(var.user_lookup_attribute == "email" ? u.mail : u.user_principal_name, "") != ""
  }

  unresolved_user_euids = sort([
    for euid in local.unique_user_euids : euid
    if !contains(keys(local.lookup_values), lower(euid))
  ])

  created_group_object_ids = { for role, g in azuread_group.namespace : role => g.object_id }

  extra_group_object_ids = {
    admin = var.admin_group_object_ids
    edit  = var.edit_group_object_ids
    view  = var.view_group_object_ids
  }

  # The created group's object ID is unknown until apply, so it cannot be part of a for_each key:
  # that binding is keyed by its role alone.
  group_bindings = merge(
    { for role in local.namespace_roles : "${role}-created" => { cluster_role = role, object_id = local.created_group_object_ids[role] } },
    merge([
      for role, ids in local.extra_group_object_ids : {
        for id in ids : "${role}-${id}" => { cluster_role = role, object_id = id }
      }
    ]...)
  )
}

resource "azuread_group" "namespace" {
  for_each = local.namespace_roles

  display_name     = join(".", compact([var.group_name_prefix, var.workspace_identifier, var.namespace_name, each.value]))
  security_enabled = true
  mail_enabled     = false
}

resource "azuread_group_member" "namespace" {
  for_each = {
    for key, assignment in local.user_group_assignments : key => assignment
    if contains(keys(local.lookup_values), lower(assignment.euid))
  }

  group_object_id  = azuread_group.namespace[each.value.role].object_id
  member_object_id = local.lookup_values[lower(each.value.euid)]
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace_name

    labels = {
      "app.kubernetes.io/managed-by" = "meshstack"
      "meshcloud.io/workspace"       = var.workspace_identifier
    }
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  metadata {
    name      = "meshstack-quota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    hard = {
      "requests.cpu"    = var.resource_quota.requests_cpu
      "requests.memory" = var.resource_quota.requests_memory
      "limits.cpu"      = var.resource_quota.limits_cpu
      "limits.memory"   = var.resource_quota.limits_memory
      "pods"            = var.resource_quota.pods
    }
  }
}

# Without defaults, a pod that declares no requests or limits is rejected once a quota on those
# resources exists.
resource "kubernetes_limit_range_v1" "this" {
  metadata {
    name      = "meshstack-defaults"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default_request = {
        cpu    = var.default_container_limits.cpu_request
        memory = var.default_container_limits.memory_request
      }
      default = {
        cpu    = var.default_container_limits.cpu_limit
        memory = var.default_container_limits.memory_limit
      }
    }
  }
}

resource "kubernetes_role_binding_v1" "group" {
  for_each = local.group_bindings

  metadata {
    name      = "meshstack-${each.key}"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = each.value.cluster_role
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = each.value.object_id
  }
}
