output "action_secret_name" {
  value = forgejo_repository_action_secret.push_robot_name.name
}

output "action_secret_secret" {
  value = forgejo_repository_action_secret.push_robot_secret.name
}