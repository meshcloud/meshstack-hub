locals {
  # Group users by their roles
  admin_users  = { for user in var.users : user.euid => user if contains(user.roles, "admin") }
  user_users   = { for user in var.users : user.euid => user if contains(user.roles, "user") && !contains(user.roles, "admin") }
  reader_users = { for user in var.users : user.euid => user if contains(user.roles, "reader") && !contains(user.roles, "admin") && !contains(user.roles, "user") }
}

# Create the Tencent Cloud project (billing boundary)
resource "tencentcloud_project" "project" {
  project_name = var.project_name
}

# CAM group for admins - full access to the project
resource "tencentcloud_cam_group" "admins" {
  name   = "${var.project_name}-admins"
  remark = "Admin group for project ${var.project_name}"
}

# CAM group for users - read/write access to the project
resource "tencentcloud_cam_group" "users" {
  name   = "${var.project_name}-users"
  remark = "User group for project ${var.project_name}"
}

# CAM group for readers - read-only access to the project
resource "tencentcloud_cam_group" "readers" {
  name   = "${var.project_name}-readers"
  remark = "Reader group for project ${var.project_name}"
}

# Admin policy: full access scoped to the project
resource "tencentcloud_cam_policy" "admin_policy" {
  name = "${var.project_name}-admin-policy"
  document = jsonencode({
    version = "2.0"
    statement = [
      {
        effect   = "allow"
        action   = ["*"]
        resource = ["*"]
        condition = {
          string_equal = {
            "qcs:project_id" = [tostring(tencentcloud_project.project.id)]
          }
        }
      }
    ]
  })
  description = "Full access policy for project ${var.project_name}"
}

# User policy: common operational access scoped to the project
resource "tencentcloud_cam_policy" "user_policy" {
  name = "${var.project_name}-user-policy"
  document = jsonencode({
    version = "2.0"
    statement = [
      {
        effect = "allow"
        action = [
          "cvm:*",
          "vpc:*",
          "clb:*",
          "cos:*",
          "cdb:*",
          "redis:*",
          "tke:*",
          "scf:*",
          "monitor:*",
          "tag:*"
        ]
        resource = ["*"]
        condition = {
          string_equal = {
            "qcs:project_id" = [tostring(tencentcloud_project.project.id)]
          }
        }
      }
    ]
  })
  description = "Operational access policy for project ${var.project_name}"
}

# Reader policy: read-only access scoped to the project
resource "tencentcloud_cam_policy" "reader_policy" {
  name = "${var.project_name}-reader-policy"
  document = jsonencode({
    version = "2.0"
    statement = [
      {
        effect = "allow"
        action = [
          "cvm:Describe*",
          "vpc:Describe*",
          "clb:Describe*",
          "cos:Get*",
          "cos:List*",
          "cdb:Describe*",
          "redis:Describe*",
          "tke:Describe*",
          "scf:Get*",
          "scf:List*",
          "monitor:*",
          "tag:Describe*"
        ]
        resource = ["*"]
        condition = {
          string_equal = {
            "qcs:project_id" = [tostring(tencentcloud_project.project.id)]
          }
        }
      }
    ]
  })
  description = "Read-only access policy for project ${var.project_name}"
}

# Attach policies to groups
resource "tencentcloud_cam_group_policy_attachment" "admin_policy" {
  group_id  = tencentcloud_cam_group.admins.id
  policy_id = tencentcloud_cam_policy.admin_policy.id
}

resource "tencentcloud_cam_group_policy_attachment" "user_policy" {
  group_id  = tencentcloud_cam_group.users.id
  policy_id = tencentcloud_cam_policy.user_policy.id
}

resource "tencentcloud_cam_group_policy_attachment" "reader_policy" {
  group_id  = tencentcloud_cam_group.readers.id
  policy_id = tencentcloud_cam_policy.reader_policy.id
}

# Add admin users to admin group
resource "tencentcloud_cam_group_membership" "admins" {
  count = length(local.admin_users) > 0 ? 1 : 0

  group_id   = tencentcloud_cam_group.admins.id
  user_names = [for user in local.admin_users : user.euid]
}

# Add users to user group
resource "tencentcloud_cam_group_membership" "users" {
  count = length(local.user_users) > 0 ? 1 : 0

  group_id   = tencentcloud_cam_group.users.id
  user_names = [for user in local.user_users : user.euid]
}

# Add readers to reader group
resource "tencentcloud_cam_group_membership" "readers" {
  count = length(local.reader_users) > 0 ? 1 : 0

  group_id   = tencentcloud_cam_group.readers.id
  user_names = [for user in local.reader_users : user.euid]
}
