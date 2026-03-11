### forgejo ###

# pre-created repository which will have the action secrets added
data "forgejo_repository" "this" {
  name  = var.forgejo_repository_name
  owner = var.forgejo_repository_owner
}

# action secret holding push robot name
resource "forgejo_repository_action_secret" "push_robot_name" {
  repository_id = data.forgejo_repository.this.id
  name          = "push_robot_name"
  data          = var.action_secret_name
}

# action secret holding push robot secret
resource "forgejo_repository_action_secret" "push_robot_secret" {
  repository_id = data.forgejo_repository.this.id
  name          = "push_robot_secret"
  data          = var.action_secret_secret
}