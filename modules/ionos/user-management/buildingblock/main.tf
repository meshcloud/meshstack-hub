# Check if users exist using external data source
data "external" "user_exists" {
  for_each = { for i, user in var.users : i => user.email }

  program = [
    "${path.module}/scripts/check_user_exists.sh",
    each.value
  ]
}

# Separate existing and non-existing users
locals {
  # Users that already exist in IONOS
  existing_users = {
    for i, result in data.external.user_exists : i => {
      index     = i
      user_data = var.users[i]
      user_id   = result.result.user_id
    }
    if result.result.exists == "true"
  }

  # Users that need to be created
  users_to_create = {
    for i, result in data.external.user_exists : i => var.users[i]
    if result.result.exists == "false"
  }
}

# Get existing users via data sources
data "ionoscloud_user" "existing" {
  for_each = local.existing_users
  email    = each.value.user_data.email
}

# Create only users that don't exist
resource "ionoscloud_user" "new_users" {
  for_each = local.users_to_create

  first_name     = each.value.firstName
  last_name      = each.value.lastName
  email          = each.value.email
  password       = var.default_user_password
  administrator  = contains(each.value.roles, "Workspace Owner")
  force_sec_auth = var.force_sec_auth

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [password]
  }
}

# Combine existing and newly created users
locals {
  all_users = merge(
    # Convert existing users data to same format
    {
      for k, v in data.ionoscloud_user.existing : k => v
    },
    # New users are already in the right format
    ionoscloud_user.new_users
  )

  # Create a list format for outputs (maintaining backward compatibility)
  all_users_list = concat(
    values(data.ionoscloud_user.existing),
    values(ionoscloud_user.new_users)
  )
}