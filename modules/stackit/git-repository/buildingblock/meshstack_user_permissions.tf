provider "stackit" {
  default_region = "eu01"
  experiments    = ["iam"]
}

resource "random_string" "stackit_custom_role_suffix" {
  length  = 8
  lower   = true
  numeric = false
  upper   = false
  special = false
}

resource "stackit_authorization_project_custom_role" "forgejo_access" {
  resource_id = var.stackit_project_id
  name        = "forgejo-access-${random_string.stackit_custom_role_suffix.result}"
  description = "Minimal custom role for members that should access the shared Forgejo instance."
  permissions = ["git.instance.get"]
}

resource "stackit_authorization_project_role_assignment" "forgejo_access_members" {
  for_each = local.mapped_workspace_members

  resource_id = var.stackit_project_id
  role        = stackit_authorization_project_custom_role.forgejo_access.name
  subject     = each.key
}

resource "terraform_data" "sync_repository_collaborators" {
  depends_on = [
    forgejo_repository.this,
    restapi_object.action_secret,
    restapi_object.action_variable,
  ]

  triggers_replace = [
    sha256(file("${path.module}/reconcile_forgejo_collaborators.py")),
    sha256(file("${path.module}/get_forgejo_collaborators.py")),
    sha256(jsonencode(local.mapped_workspace_members)),
    data.external.current_collaborators.result.current_hash,
  ]

  provisioner "local-exec" {
    command = "./reconcile_forgejo_collaborators.py"
    environment = {
      REPOSITORY_OWNER             = var.forgejo_organization
      REPOSITORY_NAME              = forgejo_repository.this.name
      DESIRED_COLLABORATORS_JSON   = jsonencode(local.mapped_workspace_members)
      CURRENT_COLLABORATORS_JSON   = data.external.current_collaborators.result.collaborators_json
      PROTECTED_COLLABORATORS_JSON = jsonencode([var.forgejo_organization])
    }
  }
}
