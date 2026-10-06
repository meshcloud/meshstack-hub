# The technical user is restricted in Forgejo and cannot look up other users, so usernames come from
# the STACKIT Git API. Only users who signed in to the instance once are listed there. The lookup
# goes by instance name, so the usernames, which decide the memberships, are known while planning the
# run that creates the instance.
data "external" "instance_users" {
  lifecycle {
    enabled = local.create_forgejo_organization
  }

  program = ["bash", "${path.module}/list-instance-users.sh"]

  query = {
    access_token  = local.stackit_access_token
    project_id    = var.stackit_project_id
    instance_name = var.instance_name
  }
}

locals {
  forgejo_usernames = local.create_forgejo_organization ? data.external.instance_users.result : {}

  # The highest Forgejo role any of a user's meshStack roles maps to. Keyed by email, which is known
  # at plan time, unlike the usernames of an instance created in the same run.
  member_roles = local.create_forgejo_organization ? {
    for user in var.users : lower(user.email) => [
      for role in ["owner", "writer", "reader"] : role
      if contains(flatten([for meshstack_role in user.roles : lookup(var.role_mapping, meshstack_role, [])]), role)
    ][0]
    if length(flatten([for meshstack_role in user.roles : lookup(var.role_mapping, meshstack_role, [])])) > 0
  } : {}

  team_permissions = { owner = "owner", writer = "write", reader = "read" }
}

module "organization_teams" {
  source = "./forgejo-teams"
  providers = {
    restapi                         = restapi
    restapi.without_returned_object = restapi.without_returned_object
  }

  depends_on = [restapi_object.forgejo_organization]

  organization = coalesce(var.forgejo_organization, "unused")

  teams = {
    for role, permission in local.team_permissions : role => {
      name                      = role == "owner" ? "Owners" : "${role}s"
      description               = "meshStack project members with ${permission} access to all repositories"
      permission                = permission
      includes_all_repositories = true
      members                   = { for email, member_role in local.member_roles : email => lookup(local.forgejo_usernames, email, "") if member_role == role }
    }
    if contains(values(local.member_roles), role)
  }
}
